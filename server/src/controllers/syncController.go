package controllers

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	model "server/src/models"

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// ===================== Single Artist Sync (HTTP) =====================

func SyncArtist() gin.HandlerFunc {
	return func(c *gin.Context) {
		artistId := c.Param("artistId")
		oid, err := primitive.ObjectIDFromHex(artistId)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "ID inválido"})
			return
		}

		// Load artist
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		var artist model.Artist
		if err := artistCollection.FindOne(ctx, bson.M{"_id": oid}).Decode(&artist); err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Artista não encontrado"})
			return
		}

		// Try to resolve SpotifyID from import_jobs if missing
		if artist.SpotifyID == "" {
			spotifyID := resolveSpotifyIDFromJobs(artist)
			if spotifyID == "" {
				c.JSON(http.StatusBadRequest, gin.H{"error": "Este artista não tem um Spotify ID vinculado. Ele precisa ter sido importado via Spotify."})
				return
			}
			artist.SpotifyID = spotifyID
			// Persist the resolved ID
			uCtx, uCancel := context.WithTimeout(context.Background(), 5*time.Second)
			artistCollection.UpdateOne(uCtx, bson.M{"_id": oid}, bson.M{"$set": bson.M{"spotifyId": spotifyID, "updatedAt": time.Now()}})
			uCancel()
		}

		result, err := syncArtistData(context.Background(), artist)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		c.JSON(http.StatusOK, result)
	}
}

// resolveSpotifyIDFromJobs attempts to find the Spotify ID for an artist
// by looking at completed import jobs.
func resolveSpotifyIDFromJobs(artist model.Artist) string {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	var job model.ImportJob
	err := importJobCollection.FindOne(ctx, bson.M{
		"artistId": artist.ID.Hex(),
		"status":   "completed",
	}, options.FindOne().SetSort(bson.M{"createdAt": -1})).Decode(&job)

	if err != nil {
		// Fallback: search by artist name in completed jobs
		err = importJobCollection.FindOne(ctx, bson.M{
			"artistName": artist.Name,
			"status":     "completed",
		}, options.FindOne().SetSort(bson.M{"createdAt": -1})).Decode(&job)
		if err != nil {
			return ""
		}
	}

	return parseSpotifyArtistId(job.SpotifyUrl)
}

// ===================== Core sync logic =====================

type syncResult struct {
	ArtistName    string `json:"artistName"`
	AvatarUpdated bool   `json:"avatarUpdated"`
	NewAlbums     int    `json:"newAlbums"`
	NewMusics     int    `json:"newMusics"`
	FailedMusics  int    `json:"failedMusics"`
	Message       string `json:"message"`
}

func syncArtistData(ctx context.Context, artist model.Artist) (*syncResult, error) {
	result := &syncResult{ArtistName: artist.Name}

	// 1. Authenticate with Spotify
	token, err := getSpotifyToken()
	if err != nil {
		return nil, fmt.Errorf("erro ao autenticar no Spotify: %w", err)
	}

	// 2. Fetch current artist info from Spotify
	spArtist, err := fetchSpotifyArtist(token, artist.SpotifyID)
	if err != nil {
		return nil, fmt.Errorf("erro ao buscar artista no Spotify: %w", err)
	}

	// 3. Update artist profile photo + genres
	if len(spArtist.Images) > 0 {
		avatarPath := filepath.Join("uploads", "image", "avatar", artist.ID.Hex()+".png")
		if err := downloadAndSaveImage(spArtist.Images[0].URL, avatarPath); err == nil {
			result.AvatarUpdated = true
			// Update color from new avatar
			newColor := artist.Color
			if col, err := extractDominantLightColor(avatarPath); err == nil {
				newColor = col
			}

			uCtx, uCancel := context.WithTimeout(context.Background(), 5*time.Second)
			artistCollection.UpdateOne(uCtx, bson.M{"_id": artist.ID}, bson.M{"$set": bson.M{
				"genres":    spArtist.Genres,
				"color":     newColor,
				"updatedAt": time.Now(),
			}})
			uCancel()
		}
	}

	// 4. Fetch all albums from Spotify
	spAlbums, err := fetchAllSpotifyAlbums(token, artist.SpotifyID)
	if err != nil {
		return nil, fmt.Errorf("erro ao buscar álbuns do Spotify: %w", err)
	}

	// 5. Load existing albums and musics from DB
	dbCtx, dbCancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer dbCancel()

	existingAlbumNames := make(map[string]primitive.ObjectID)
	cursor, err := albumCollection.Find(dbCtx, bson.M{"artistId": artist.ID})
	if err == nil {
		var albums []model.Album
		if cursor.All(dbCtx, &albums) == nil {
			for _, a := range albums {
				existingAlbumNames[normalizeTrackName(a.Name)] = a.ID
			}
		}
	}

	existingMusicNames := make(map[string]bool)
	mCursor, err := musicCollection.Find(dbCtx, bson.M{"artistId": artist.ID})
	if err == nil {
		var musics []model.Music
		if mCursor.All(dbCtx, &musics) == nil {
			for _, m := range musics {
				existingMusicNames[normalizeTrackName(m.Name)] = true
			}
		}
	}

	// 6. Process each Spotify album
	genre := ""
	if len(spArtist.Genres) > 0 {
		genre = spArtist.Genres[0]
	}

	for _, spAlbum := range spAlbums {
		if cancelled(ctx) {
			break
		}

		tracks, err := fetchAllSpotifyTracks(token, spAlbum.ID)
		if err != nil {
			continue
		}

		isSingle := spAlbum.AlbumType == "single" && len(tracks) == 1

		// Check which tracks are new
		var newTracks []spotifyTrack
		for _, t := range tracks {
			if !existingMusicNames[normalizeTrackName(t.Name)] {
				newTracks = append(newTracks, t)
			}
		}

		if len(newTracks) == 0 {
			continue // All tracks already exist
		}

		// Determine or create album
		var albumOID primitive.ObjectID
		albumColor := artist.Color

		if !isSingle {
			normalizedAlbumName := normalizeTrackName(spAlbum.Name)
			if existingID, ok := existingAlbumNames[normalizedAlbumName]; ok {
				albumOID = existingID
			} else {
				// Create new album
				albumOID = primitive.NewObjectID()
				coverPath := filepath.Join("uploads", "image", "cover", albumOID.Hex()+".png")

				if len(spAlbum.Images) > 0 {
					if err := downloadAndSaveImage(spAlbum.Images[0].URL, coverPath); err == nil {
						if col, err := extractDominantLightColor(coverPath); err == nil {
							albumColor = col
						}
					}
				}

				now := time.Now()
				dbAlbum := model.Album{
					ID:            albumOID,
					Name:          spAlbum.Name,
					ArtistID:      artist.ID,
					AlbumCoverUrl: "/image/cover/" + albumOID.Hex(),
					Color:         albumColor,
					CreatedAt:     now,
					UpdatedAt:     now,
				}

				aCtx, aCancel := context.WithTimeout(context.Background(), 10*time.Second)
				_, err = albumCollection.InsertOne(aCtx, dbAlbum)
				aCancel()
				if err != nil {
					continue
				}
				existingAlbumNames[normalizedAlbumName] = albumOID
				result.NewAlbums++
			}
		}

		// Download new tracks
		for _, track := range newTracks {
			if cancelled(ctx) {
				break
			}

			musicOID := primitive.NewObjectID()

			searchQuery := fmt.Sprintf("ytsearch1:%s - %s", artist.Name, track.Name)
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

			// Anti-bot delay
			time.Sleep(6 * time.Second)

			dlResult := runYtdlpWithRetry(ctx, ytArgs, defaultRetryConfig, func(msg string) {
				log.Printf("[sync:%s] %s", artist.Name, msg)
			})
			if !dlResult.Success {
				result.FailedMusics++
				continue
			}

			// Find downloaded file
			audioPath := fmt.Sprintf("uploads/music/%s.m4a", musicOID.Hex())
			for _, ext := range []string{"m4a", "webm", "opus", "mp3", "ogg"} {
				candidate := fmt.Sprintf("uploads/music/%s.%s", musicOID.Hex(), ext)
				if _, statErr := os.Stat(candidate); statErr == nil {
					audioPath = candidate
					break
				}
			}

			// Convert to m4a if needed
			if audioPath != fmt.Sprintf("uploads/music/%s.m4a", musicOID.Hex()) {
				m4aPath := fmt.Sprintf("uploads/music/%s.m4a", musicOID.Hex())
				convCmd := exec.Command("/usr/bin/ffmpeg", "-i", audioPath, "-c:a", "aac", "-b:a", "192k", "-y", m4aPath)
				if convErr := convCmd.Run(); convErr == nil {
					os.Remove(audioPath)
					audioPath = m4aPath
				}
			}

			// Generate waveform
			waveform, err := GetWaveform(audioPath)
			if err != nil {
				waveform = make([]float64, 70)
			}

			musicColor := albumColor
			var coverUrl string
			if isSingle {
				musicCoverPath := filepath.Join("uploads", "image", "music_cover", musicOID.Hex()+".png")
				if len(spAlbum.Images) > 0 {
					if err := downloadAndSaveImage(spAlbum.Images[0].URL, musicCoverPath); err == nil {
						if col, err := extractDominantLightColor(musicCoverPath); err == nil {
							musicColor = col
						}
					}
				}
				coverUrl = "/image/music_cover/" + musicOID.Hex()
			}

			now := time.Now()
			dbMusic := model.Music{
				ID:        musicOID,
				Url:       "/stream/" + musicOID.Hex(),
				Name:      track.Name,
				ArtistID:  artist.ID,
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

			mCtx, mCancel := context.WithTimeout(context.Background(), 10*time.Second)
			_, err = musicCollection.InsertOne(mCtx, dbMusic)
			mCancel()
			if err != nil {
				result.FailedMusics++
				continue
			}

			result.NewMusics++
			existingMusicNames[normalizeTrackName(track.Name)] = true

			// Try to fetch lyrics
			lrcPath := filepath.Join("uploads", "lyrics", musicOID.Hex()+".lrc")
			fetchAndSaveLRC(artist.Name, track.Name, track.DurationMs, lrcPath)
		}
	}

	// Build summary message
	parts := []string{}
	if result.AvatarUpdated {
		parts = append(parts, "foto atualizada")
	}
	if result.NewAlbums > 0 {
		parts = append(parts, fmt.Sprintf("%d álbuns novos", result.NewAlbums))
	}
	if result.NewMusics > 0 {
		parts = append(parts, fmt.Sprintf("%d músicas novas", result.NewMusics))
	}
	if result.FailedMusics > 0 {
		parts = append(parts, fmt.Sprintf("%d falhas", result.FailedMusics))
	}
	if len(parts) == 0 {
		result.Message = "Tudo atualizado, nenhuma novidade encontrada."
	} else {
		result.Message = "Sincronização concluída: " + strings.Join(parts, ", ") + "."
	}

	return result, nil
}

// normalizeTrackName normalizes a track/album name for comparison (lowercase, trimmed)
func normalizeTrackName(name string) string {
	return strings.ToLower(strings.TrimSpace(name))
}

// ===================== Weekly Sync Routine =====================

func StartWeeklySync() {
	go func() {
		for {
			// Calculate time until next Sunday 03:00 UTC
			now := time.Now().UTC()
			next := nextWeekday(now, time.Sunday, 3) // Sunday 3 AM UTC
			sleepDuration := next.Sub(now)

			log.Printf("[weekly-sync] Próxima sincronização em %s (%s)", sleepDuration.Round(time.Minute), next.Format("2006-01-02 15:04 UTC"))
			time.Sleep(sleepDuration)

			log.Println("[weekly-sync] Iniciando sincronização semanal de todos os artistas...")
			runFullSync()
		}
	}()
}

func nextWeekday(from time.Time, day time.Weekday, hour int) time.Time {
	t := time.Date(from.Year(), from.Month(), from.Day(), hour, 0, 0, 0, time.UTC)
	daysUntil := int(day - from.Weekday())
	if daysUntil < 0 {
		daysUntil += 7
	}
	// If today is the target day but the hour already passed, go to next week
	if daysUntil == 0 && from.After(t) {
		daysUntil = 7
	}
	return t.AddDate(0, 0, daysUntil)
}

func runFullSync() {
	ctx := context.Background()

	// Find all artists with a SpotifyID
	dbCtx, dbCancel := context.WithTimeout(ctx, 30*time.Second)
	defer dbCancel()

	cursor, err := artistCollection.Find(dbCtx, bson.M{
		"spotifyId": bson.M{"$ne": ""},
	}, options.Find().SetSort(bson.M{"name": 1}))
	if err != nil {
		log.Printf("[weekly-sync] Erro ao buscar artistas: %v", err)
		return
	}

	var artists []model.Artist
	if err := cursor.All(dbCtx, &artists); err != nil {
		log.Printf("[weekly-sync] Erro ao decodificar artistas: %v", err)
		return
	}

	log.Printf("[weekly-sync] %d artistas encontrados para sincronizar", len(artists))

	totalNew := 0
	totalFailed := 0
	synced := 0

	for _, artist := range artists {
		result, err := syncArtistData(ctx, artist)
		if err != nil {
			log.Printf("[weekly-sync] Erro ao sincronizar '%s': %v", artist.Name, err)
			totalFailed++
			continue
		}

		synced++
		totalNew += result.NewMusics

		if result.NewMusics > 0 || result.NewAlbums > 0 {
			log.Printf("[weekly-sync] %s: %s", artist.Name, result.Message)
		}

		// Small pause between artists to avoid Spotify rate limits
		time.Sleep(2 * time.Second)
	}

	log.Printf("[weekly-sync] Sincronização concluída: %d artistas sincronizados, %d músicas novas, %d erros", synced, totalNew, totalFailed)
}

// SyncAllArtists exposes the full sync as an admin HTTP endpoint (manual trigger)
func SyncAllArtists() gin.HandlerFunc {
	return func(c *gin.Context) {
		go runFullSync()
		c.JSON(http.StatusOK, gin.H{"message": "Sincronização de todos os artistas iniciada em background."})
	}
}
