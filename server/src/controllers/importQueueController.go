package controllers

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"sync"
	"time"

	model "server/src/models"

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"

	database "server/src/db"
)

var importJobCollection *mongo.Collection = database.OpenCollection(database.Client, "import_jobs")

// ImportQueue manages a sequential queue of import jobs
type ImportQueue struct {
	mu          sync.Mutex
	queue       chan primitive.ObjectID
	cancelFuncs map[string]context.CancelFunc
	subscribers map[string][]chan model.ImportLog
	subMu       sync.RWMutex
}

var importQueue = &ImportQueue{
	queue:       make(chan primitive.ObjectID, 100),
	cancelFuncs: make(map[string]context.CancelFunc),
	subscribers: make(map[string][]chan model.ImportLog),
}

// StartImportWorker starts the background worker that processes import jobs sequentially
func StartImportWorker() {
	// On startup, reset any "running" jobs back to "queued" (server crash recovery)
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	importJobCollection.UpdateMany(ctx,
		bson.M{"status": "running"},
		bson.M{"$set": bson.M{"status": "queued", "updatedAt": time.Now()}},
	)

	// Re-enqueue any queued jobs
	cursor, err := importJobCollection.Find(ctx,
		bson.M{"status": "queued"},
		options.Find().SetSort(bson.M{"createdAt": 1}),
	)
	if err == nil {
		var jobs []model.ImportJob
		if cursor.All(ctx, &jobs) == nil {
			for _, j := range jobs {
				importQueue.queue <- j.ID
			}
		}
	}

	go importQueue.worker()
}

func (q *ImportQueue) worker() {
	for jobID := range q.queue {
		q.processJob(jobID)
	}
}

func (q *ImportQueue) Enqueue(jobID primitive.ObjectID) {
	q.queue <- jobID
}

func (q *ImportQueue) Cancel(jobID string) {
	q.mu.Lock()
	if cancelFn, ok := q.cancelFuncs[jobID]; ok {
		cancelFn()
		delete(q.cancelFuncs, jobID)
	}
	q.mu.Unlock()

	// If still queued (not running), mark cancelled directly
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	now := time.Now()
	importJobCollection.UpdateOne(ctx,
		bson.M{"_id": mustObjectID(jobID), "status": "queued"},
		bson.M{"$set": bson.M{"status": "cancelled", "updatedAt": now, "finishedAt": now}},
	)
}

func mustObjectID(hex string) primitive.ObjectID {
	id, _ := primitive.ObjectIDFromHex(hex)
	return id
}

// Subscribe returns a channel that receives real-time logs for a job
func (q *ImportQueue) Subscribe(jobID string) chan model.ImportLog {
	ch := make(chan model.ImportLog, 50)
	q.subMu.Lock()
	q.subscribers[jobID] = append(q.subscribers[jobID], ch)
	q.subMu.Unlock()
	return ch
}

// Unsubscribe removes a subscriber channel
func (q *ImportQueue) Unsubscribe(jobID string, ch chan model.ImportLog) {
	q.subMu.Lock()
	defer q.subMu.Unlock()
	subs := q.subscribers[jobID]
	for i, s := range subs {
		if s == ch {
			q.subscribers[jobID] = append(subs[:i], subs[i+1:]...)
			close(ch)
			break
		}
	}
	if len(q.subscribers[jobID]) == 0 {
		delete(q.subscribers, jobID)
	}
}

func (q *ImportQueue) broadcast(jobID string, log model.ImportLog) {
	q.subMu.RLock()
	defer q.subMu.RUnlock()
	for _, ch := range q.subscribers[jobID] {
		select {
		case ch <- log:
		default:
			// skip slow subscribers
		}
	}
}

func (q *ImportQueue) addLog(jobID primitive.ObjectID, logType, message string) {
	entry := model.ImportLog{
		Type:    logType,
		Message: message,
		Time:    time.Now(),
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	importJobCollection.UpdateOne(ctx,
		bson.M{"_id": jobID},
		bson.M{
			"$push": bson.M{"logs": entry},
			"$set":  bson.M{"updatedAt": time.Now()},
		},
	)

	q.broadcast(jobID.Hex(), entry)
}

func (q *ImportQueue) updateProgress(jobID primitive.ObjectID, progress, total int) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	importJobCollection.UpdateOne(ctx,
		bson.M{"_id": jobID},
		bson.M{"$set": bson.M{"progress": progress, "total": total, "updatedAt": time.Now()}},
	)
}

func (q *ImportQueue) setStatus(jobID primitive.ObjectID, status string) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	update := bson.M{"status": status, "updatedAt": time.Now()}
	if status == "completed" || status == "failed" || status == "cancelled" {
		now := time.Now()
		update["finishedAt"] = now
	}
	importJobCollection.UpdateOne(ctx,
		bson.M{"_id": jobID},
		bson.M{"$set": update},
	)
}

func (q *ImportQueue) setResult(jobID primitive.ObjectID, albums, musics, failed int, artistID string) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	importJobCollection.UpdateOne(ctx,
		bson.M{"_id": jobID},
		bson.M{"$set": bson.M{
			"albums":   albums,
			"musics":   musics,
			"failed":   failed,
			"artistId": artistID,
		}},
	)
}

func (q *ImportQueue) addFailedItem(jobID primitive.ObjectID, trackName, reason string) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	importJobCollection.UpdateOne(ctx,
		bson.M{"_id": jobID},
		bson.M{"$push": bson.M{"failedItems": model.ImportFailedItem{
			TrackName: trackName,
			Reason:    reason,
		}}},
	)
}

// ===================== processJob =====================

func (q *ImportQueue) processJob(jobID primitive.ObjectID) {
	ctx, cancel := context.WithCancel(context.Background())
	jobHex := jobID.Hex()

	q.mu.Lock()
	q.cancelFuncs[jobHex] = cancel
	q.mu.Unlock()

	defer func() {
		cancel()
		q.mu.Lock()
		delete(q.cancelFuncs, jobHex)
		q.mu.Unlock()
	}()

	// Load job from DB
	var job model.ImportJob
	dbCtx, dbCancel := context.WithTimeout(context.Background(), 5*time.Second)
	err := importJobCollection.FindOne(dbCtx, bson.M{"_id": jobID}).Decode(&job)
	dbCancel()
	if err != nil {
		q.addLog(jobID, "error", "Erro ao carregar job: "+err.Error())
		q.setStatus(jobID, "failed")
		return
	}

	if job.Status == "cancelled" {
		return
	}

	q.setStatus(jobID, "running")
	q.addLog(jobID, "progress", "Iniciando importação...")

	// Parse Spotify URL
	artistSpotifyId := parseSpotifyArtistId(job.SpotifyUrl)
	if artistSpotifyId == "" {
		q.addLog(jobID, "error", "URL do Spotify inválida. Use o link de um artista.")
		q.setStatus(jobID, "failed")
		return
	}

	// 1. Authenticate with Spotify
	q.addLog(jobID, "progress", "Autenticando no Spotify...")
	token, err := getSpotifyToken()
	if err != nil {
		q.addLog(jobID, "error", "Erro ao autenticar no Spotify: "+err.Error())
		q.setStatus(jobID, "failed")
		return
	}

	if cancelled(ctx) {
		q.addLog(jobID, "progress", "Importação cancelada.")
		q.setStatus(jobID, "cancelled")
		return
	}

	// 2. Fetch artist info
	q.addLog(jobID, "progress", "Buscando dados do artista...")
	spArtist, err := fetchSpotifyArtist(token, artistSpotifyId)
	if err != nil {
		q.addLog(jobID, "error", "Erro ao buscar artista: "+err.Error())
		q.setStatus(jobID, "failed")
		return
	}
	q.addLog(jobID, "progress", fmt.Sprintf("Artista encontrado: %s", spArtist.Name))

	// Update job with artist name
	tCtx, tCancel := context.WithTimeout(context.Background(), 5*time.Second)
	importJobCollection.UpdateOne(tCtx, bson.M{"_id": jobID}, bson.M{"$set": bson.M{"artistName": spArtist.Name}})
	tCancel()

	// 3. Fetch all albums and tracks (metadata only)
	q.addLog(jobID, "progress", "Buscando álbuns e faixas...")
	spAlbums, err := fetchAllSpotifyAlbums(token, artistSpotifyId)
	if err != nil {
		q.addLog(jobID, "error", "Erro ao buscar álbuns: "+err.Error())
		q.setStatus(jobID, "failed")
		return
	}

	var albums []importAlbum
	totalTracks := 0
	for _, spAlbum := range spAlbums {
		tracks, err := fetchAllSpotifyTracks(token, spAlbum.ID)
		if err != nil {
			q.addLog(jobID, "progress", fmt.Sprintf("Aviso: não foi possível buscar faixas de '%s'", spAlbum.Name))
			continue
		}
		albums = append(albums, importAlbum{spotify: spAlbum, tracks: tracks})
		totalTracks += len(tracks)
	}

	q.addLog(jobID, "progress", fmt.Sprintf("Encontrados %d álbuns/singles com %d faixas no total", len(albums), totalTracks))
	q.updateProgress(jobID, 0, totalTracks)

	// 4. Create artist in DB
	genre := ""
	if len(spArtist.Genres) > 0 {
		genre = spArtist.Genres[0]
	}

	artistOID := primitive.NewObjectID()
	avatarPath := filepath.Join("uploads", "image", "avatar", artistOID.Hex()+".png")

	artistColor := "#8b5cf6"
	if len(spArtist.Images) > 0 {
		q.addLog(jobID, "progress", "Baixando foto do artista...")
		if err := downloadAndSaveImage(spArtist.Images[0].URL, avatarPath); err == nil {
			if col, err := extractDominantLightColor(avatarPath); err == nil {
				artistColor = col
			}
		}
	}

	q.addLog(jobID, "progress", "Buscando bio do artista...")
	artistBio := fetchAudioDBBio(spArtist.Name)
	if artistBio != "" {
		q.addLog(jobID, "progress", "Bio encontrada ✓")
	} else {
		q.addLog(jobID, "progress", "Bio não encontrada, continuando...")
	}

	now := time.Now()
	dbArtist := model.Artist{
		ID:        artistOID,
		Name:      spArtist.Name,
		Genres:    spArtist.Genres,
		AvatarUrl: "/image/avatar/" + artistOID.Hex(),
		BannerUrl: "/image/banner/" + artistOID.Hex(),
		Bio:       artistBio,
		Color:     artistColor,
		CreatedAt: now,
		UpdatedAt: now,
	}

	insCtx, insCancel := context.WithTimeout(context.Background(), 30*time.Second)
	_, err = artistCollection.InsertOne(insCtx, dbArtist)
	insCancel()
	if err != nil {
		q.addLog(jobID, "error", "Erro ao criar artista no banco: "+err.Error())
		q.setStatus(jobID, "failed")
		return
	}
	q.addLog(jobID, "progress", "Artista criado: "+spArtist.Name)

	// 5. Process each album and its tracks
	processedTracks := 0
	totalAlbums := 0
	totalMusics := 0
	failedTracks := 0

	for _, album := range albums {
		if cancelled(ctx) {
			q.addLog(jobID, "progress", "Importação cancelada.")
			q.setResult(jobID, totalAlbums, totalMusics, failedTracks, artistOID.Hex())
			q.setStatus(jobID, "cancelled")
			return
		}

		isSingle := album.spotify.AlbumType == "single" && len(album.tracks) == 1

		var albumOID primitive.ObjectID
		albumColor := artistColor

		if !isSingle {
			albumOID = primitive.NewObjectID()
			coverPath := filepath.Join("uploads", "image", "cover", albumOID.Hex()+".png")

			if len(album.spotify.Images) > 0 {
				if err := downloadAndSaveImage(album.spotify.Images[0].URL, coverPath); err == nil {
					if col, err := extractDominantLightColor(coverPath); err == nil {
						albumColor = col
					}
				}
			}

			dbAlbum := model.Album{
				ID:            albumOID,
				Name:          album.spotify.Name,
				ArtistID:      artistOID,
				AlbumCoverUrl: "/image/cover/" + albumOID.Hex(),
				Color:         albumColor,
				CreatedAt:     now,
				UpdatedAt:     now,
			}

			albumCtx, albumCancel := context.WithTimeout(context.Background(), 10*time.Second)
			_, err = albumCollection.InsertOne(albumCtx, dbAlbum)
			albumCancel()
			if err != nil {
				q.addLog(jobID, "progress", fmt.Sprintf("⚠ Erro ao criar álbum '%s': %s", album.spotify.Name, err.Error()))
				continue
			}
			totalAlbums++
			q.addLog(jobID, "progress", fmt.Sprintf("📀 Álbum criado: %s", album.spotify.Name))
		}

		for _, track := range album.tracks {
			if cancelled(ctx) {
				q.addLog(jobID, "progress", "Importação cancelada.")
				q.setResult(jobID, totalAlbums, totalMusics, failedTracks, artistOID.Hex())
				q.setStatus(jobID, "cancelled")
				return
			}

			// Anti-bot: sleep between YouTube downloads to avoid rate limiting
			if processedTracks > 0 {
				select {
				case <-ctx.Done():
					q.addLog(jobID, "progress", "Importação cancelada.")
					q.setResult(jobID, totalAlbums, totalMusics, failedTracks, artistOID.Hex())
					q.setStatus(jobID, "cancelled")
					return
				case <-time.After(6 * time.Second):
				}
			}

			processedTracks++
			q.addLog(jobID, "progress", fmt.Sprintf("🔽 [%d/%d] Baixando: %s - %s", processedTracks, totalTracks, spArtist.Name, track.Name))
			q.updateProgress(jobID, processedTracks, totalTracks)

			musicOID := primitive.NewObjectID()

			searchQuery := fmt.Sprintf("ytsearch1:%s - %s", spArtist.Name, track.Name)
			outputPath := fmt.Sprintf("./uploads/music/%s.%%(ext)s", musicOID.Hex())

			ytArgs := []string{
				"-f", "bestaudio[ext=m4a]/bestaudio[abr>0]/bestaudio/best",
				"-x", "--audio-format", "m4a",
				"--ffmpeg-location", "/usr/bin/ffmpeg",
				"-o", outputPath,
				"--no-playlist",
				"--socket-timeout", "30",
				"--retries", "3",
				"--sleep-requests", "1.5",
				"--no-warnings",
				"--user-agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
			}
			cookiesPath := "/opt/lyria/server/cookies.txt"
			if info, err := os.Stat(cookiesPath); err == nil && info.Size() > 0 {
				ytArgs = append(ytArgs, "--cookies", cookiesPath)
			}
			ytArgs = append(ytArgs, searchQuery)

			cmd := exec.Command("yt-dlp", ytArgs...)
			var cmdStderr bytes.Buffer
			cmd.Stderr = &cmdStderr
			if err := cmd.Run(); err != nil {
				failedTracks++
				errMsg := cmdStderr.String()
				if len(errMsg) > 500 {
					errMsg = errMsg[len(errMsg)-500:]
				}
				reason := fmt.Sprintf("%s | %s", err.Error(), errMsg)
				q.addLog(jobID, "progress", fmt.Sprintf("⚠ Falha ao baixar '%s': %s", track.Name, reason))
				q.addFailedItem(jobID, track.Name, reason)
				continue
			}

			audioPath := fmt.Sprintf("uploads/music/%s.m4a", musicOID.Hex())
			for _, ext := range []string{"m4a", "webm", "opus", "mp3", "ogg"} {
				candidate := fmt.Sprintf("uploads/music/%s.%s", musicOID.Hex(), ext)
				if _, statErr := os.Stat(candidate); statErr == nil {
					audioPath = candidate
					break
				}
			}

			if audioPath != fmt.Sprintf("uploads/music/%s.m4a", musicOID.Hex()) {
				m4aPath := fmt.Sprintf("uploads/music/%s.m4a", musicOID.Hex())
				convCmd := exec.Command("/usr/bin/ffmpeg", "-i", audioPath, "-c:a", "aac", "-b:a", "192k", "-y", m4aPath)
				if convErr := convCmd.Run(); convErr == nil {
					os.Remove(audioPath)
					audioPath = m4aPath
				}
			}

			waveform, err := GetWaveform(audioPath)
			if err != nil {
				q.addLog(jobID, "progress", fmt.Sprintf("⚠ Waveform falhou para '%s': %v", track.Name, err))
				waveform = make([]float64, 70)
			}

			musicColor := albumColor
			var coverUrl string
			if isSingle {
				musicCoverPath := filepath.Join("uploads", "image", "music_cover", musicOID.Hex()+".png")
				if len(album.spotify.Images) > 0 {
					if err := downloadAndSaveImage(album.spotify.Images[0].URL, musicCoverPath); err == nil {
						if col, err := extractDominantLightColor(musicCoverPath); err == nil {
							musicColor = col
						}
					}
				}
				coverUrl = "/image/music_cover/" + musicOID.Hex()
			}

			dbMusic := model.Music{
				ID:        musicOID,
				Url:       "/stream/" + musicOID.Hex(),
				Name:      track.Name,
				ArtistID:  artistOID,
				Genre:     genre,
				Waveform:  waveform,
				Color:     musicColor,
				CreatedAt: now,
				UpdatedAt: now,
			}

			if !isSingle {
				dbMusic.AlbumID = albumOID
			}
			if coverUrl != "" {
				dbMusic.CoverUrl = coverUrl
			}

			musicCtx, musicCancel := context.WithTimeout(context.Background(), 10*time.Second)
			_, err = musicCollection.InsertOne(musicCtx, dbMusic)
			musicCancel()
			if err != nil {
				failedTracks++
				reason := fmt.Sprintf("Erro ao salvar no banco: %s", err.Error())
				q.addLog(jobID, "progress", fmt.Sprintf("⚠ Erro ao salvar '%s' no banco: %s", track.Name, err.Error()))
				q.addFailedItem(jobID, track.Name, reason)
				continue
			}

			totalMusics++

			lrcPath := filepath.Join("uploads", "lyrics", musicOID.Hex()+".lrc")
			if err := fetchAndSaveLRC(spArtist.Name, track.Name, track.DurationMs, lrcPath); err == nil {
				q.addLog(jobID, "progress", fmt.Sprintf("🎵 [%d/%d] %s (letra ✓)", processedTracks, totalTracks, track.Name))
			} else {
				q.addLog(jobID, "progress", fmt.Sprintf("✅ [%d/%d] %s", processedTracks, totalTracks, track.Name))
			}
		}
	}

	// 6. Done
	summary := fmt.Sprintf("Importação concluída! Artista: %s | Álbuns: %d | Músicas: %d", spArtist.Name, totalAlbums, totalMusics)
	if failedTracks > 0 {
		summary += fmt.Sprintf(" | Falhas: %d", failedTracks)
	}
	q.addLog(jobID, "done", summary)
	q.setResult(jobID, totalAlbums, totalMusics, failedTracks, artistOID.Hex())
	q.setStatus(jobID, "completed")
}

func cancelled(ctx context.Context) bool {
	select {
	case <-ctx.Done():
		return true
	default:
		return false
	}
}

// ===================== HTTP Handlers =====================

func CreateImportJobs() gin.HandlerFunc {
	return func(c *gin.Context) {
		var body struct {
			URLs []string `json:"urls" binding:"required,min=1"`
		}
		if err := c.ShouldBindJSON(&body); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Envie ao menos uma URL"})
			return
		}

		var created []model.ImportJob
		now := time.Now()

		for _, u := range body.URLs {
			u = trimURL(u)
			if u == "" {
				continue
			}
			job := model.ImportJob{
				ID:          primitive.NewObjectID(),
				SpotifyUrl:  u,
				Status:      "queued",
				Logs:        []model.ImportLog{},
				FailedItems: []model.ImportFailedItem{},
				CreatedAt:   now,
				UpdatedAt:   now,
			}

			ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			_, err := importJobCollection.InsertOne(ctx, job)
			cancel()
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao criar job: " + err.Error()})
				return
			}

			importQueue.Enqueue(job.ID)
			created = append(created, job)
		}

		c.JSON(http.StatusCreated, gin.H{"jobs": created})
	}
}

func ListImportJobs() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		opts := options.Find().SetSort(bson.M{"createdAt": -1}).SetProjection(bson.M{"logs": 0})
		cursor, err := importJobCollection.Find(ctx, bson.M{}, opts)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		var jobs []model.ImportJob
		if err := cursor.All(ctx, &jobs); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		if jobs == nil {
			jobs = []model.ImportJob{}
		}
		c.JSON(http.StatusOK, gin.H{"jobs": jobs})
	}
}

func GetImportJob() gin.HandlerFunc {
	return func(c *gin.Context) {
		id, err := primitive.ObjectIDFromHex(c.Param("jobId"))
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "ID inválido"})
			return
		}
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		var job model.ImportJob
		if err := importJobCollection.FindOne(ctx, bson.M{"_id": id}).Decode(&job); err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Job não encontrado"})
			return
		}
		c.JSON(http.StatusOK, job)
	}
}

func CancelImportJob() gin.HandlerFunc {
	return func(c *gin.Context) {
		jobId := c.Param("jobId")
		id, err := primitive.ObjectIDFromHex(jobId)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "ID inválido"})
			return
		}

		// Check job exists and is cancellable
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		var job model.ImportJob
		if err := importJobCollection.FindOne(ctx, bson.M{"_id": id}).Decode(&job); err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Job não encontrado"})
			return
		}
		if job.Status != "queued" && job.Status != "running" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Job não pode ser cancelado (status: " + job.Status + ")"})
			return
		}

		importQueue.Cancel(jobId)
		c.JSON(http.StatusOK, gin.H{"message": "Cancelamento solicitado"})
	}
}

func StreamImportJobLogs() gin.HandlerFunc {
	return func(c *gin.Context) {
		jobId := c.Param("jobId")
		id, err := primitive.ObjectIDFromHex(jobId)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "ID inválido"})
			return
		}

		// Verify job exists
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		var job model.ImportJob
		err = importJobCollection.FindOne(ctx, bson.M{"_id": id}).Decode(&job)
		cancel()
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Job não encontrado"})
			return
		}

		// Set SSE headers
		c.Header("Content-Type", "text/event-stream")
		c.Header("Cache-Control", "no-cache")
		c.Header("Connection", "keep-alive")
		c.Header("X-Accel-Buffering", "no")

		flusher, _ := c.Writer.(http.Flusher)

		// Send existing logs first
		for _, log := range job.Logs {
			data, _ := json.Marshal(log)
			fmt.Fprintf(c.Writer, "event: log\ndata: %s\n\n", data)
		}
		// Send current status
		statusData, _ := json.Marshal(map[string]interface{}{
			"status":   job.Status,
			"progress": job.Progress,
			"total":    job.Total,
			"albums":   job.Albums,
			"musics":   job.Musics,
			"failed":   job.Failed,
		})
		fmt.Fprintf(c.Writer, "event: status\ndata: %s\n\n", statusData)
		if flusher != nil {
			flusher.Flush()
		}

		// If job already finished, close
		if job.Status == "completed" || job.Status == "failed" || job.Status == "cancelled" {
			return
		}

		// Subscribe to real-time logs
		ch := importQueue.Subscribe(jobId)
		defer importQueue.Unsubscribe(jobId, ch)

		for {
			select {
			case <-c.Request.Context().Done():
				return
			case log, ok := <-ch:
				if !ok {
					return
				}
				data, _ := json.Marshal(log)
				fmt.Fprintf(c.Writer, "event: log\ndata: %s\n\n", data)
				if flusher != nil {
					flusher.Flush()
				}
				// If this is a done or error log, send final status and close
				if log.Type == "done" || log.Type == "error" {
					// Re-fetch job for final stats
					fCtx, fCancel := context.WithTimeout(context.Background(), 5*time.Second)
					var finalJob model.ImportJob
					if err := importJobCollection.FindOne(fCtx, bson.M{"_id": id}).Decode(&finalJob); err == nil {
						sd, _ := json.Marshal(map[string]interface{}{
							"status":   finalJob.Status,
							"progress": finalJob.Progress,
							"total":    finalJob.Total,
							"albums":   finalJob.Albums,
							"musics":   finalJob.Musics,
							"failed":   finalJob.Failed,
						})
						fmt.Fprintf(c.Writer, "event: status\ndata: %s\n\n", sd)
						if flusher != nil {
							flusher.Flush()
						}
					}
					fCancel()
					return
				}
			}
		}
	}
}

func trimURL(s string) string {
	// Simple trim
	result := ""
	for _, c := range s {
		if c != ' ' && c != '\n' && c != '\r' && c != '\t' {
			result += string(c)
		} else if result != "" && c == ' ' {
			// keep spaces in middle but trim edges
			result += string(c)
		}
	}
	// Trim trailing spaces
	for len(result) > 0 && result[len(result)-1] == ' ' {
		result = result[:len(result)-1]
	}
	return result
}
