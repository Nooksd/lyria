package controllers

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"image"
	_ "image/jpeg"
	"image/png"
	"io"
	"math"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	model "server/src/models"

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson/primitive"
)

// --- Spotify API types ---

type spotifyToken struct {
	AccessToken string `json:"access_token"`
	TokenType   string `json:"token_type"`
	ExpiresIn   int    `json:"expires_in"`
}

type spotifyArtist struct {
	ID     string         `json:"id"`
	Name   string         `json:"name"`
	Genres []string       `json:"genres"`
	Images []spotifyImage `json:"images"`
}

type spotifyImage struct {
	URL    string `json:"url"`
	Height int    `json:"height"`
	Width  int    `json:"width"`
}

type spotifyAlbumsResponse struct {
	Items []spotifyAlbum `json:"items"`
	Next  *string        `json:"next"`
	Total int            `json:"total"`
}

type spotifyAlbum struct {
	ID          string         `json:"id"`
	Name        string         `json:"name"`
	AlbumType   string         `json:"album_type"`
	AlbumGroup  string         `json:"album_group"`
	Images      []spotifyImage `json:"images"`
	TotalTracks int            `json:"total_tracks"`
	ReleaseDate string         `json:"release_date"`
}

type spotifyTracksResponse struct {
	Items []spotifyTrack `json:"items"`
	Next  *string        `json:"next"`
	Total int            `json:"total"`
}

type spotifyTrack struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	TrackNumber int    `json:"track_number"`
	DurationMs  int    `json:"duration_ms"`
}

// --- SSE helper ---

type sseWriter struct {
	c       *gin.Context
	flusher http.Flusher
}

func newSSEWriter(c *gin.Context) *sseWriter {
	c.Header("Content-Type", "text/event-stream")
	c.Header("Cache-Control", "no-cache")
	c.Header("Connection", "keep-alive")
	c.Header("X-Accel-Buffering", "no")

	flusher, _ := c.Writer.(http.Flusher)
	return &sseWriter{c: c, flusher: flusher}
}

func (s *sseWriter) send(event string, data interface{}) bool {
	select {
	case <-s.c.Request.Context().Done():
		return false
	default:
	}
	jsonData, _ := json.Marshal(data)
	fmt.Fprintf(s.c.Writer, "event: %s\ndata: %s\n\n", event, jsonData)
	if s.flusher != nil {
		s.flusher.Flush()
	}
	return true
}

// --- Pre-fetch structure for progress tracking ---

type importAlbum struct {
	spotify spotifyAlbum
	tracks  []spotifyTrack
}

// --- Main import handler ---

func ImportFromSpotify() gin.HandlerFunc {
	return func(c *gin.Context) {
		sse := newSSEWriter(c)

		spotifyUrl := c.Query("url")
		if spotifyUrl == "" {
			sse.send("error", map[string]string{"message": "URL do Spotify não fornecida"})
			return
		}

		artistSpotifyId := parseSpotifyArtistId(spotifyUrl)
		if artistSpotifyId == "" {
			sse.send("error", map[string]string{"message": "URL do Spotify inválida. Use o link de um artista."})
			return
		}

		// 1. Authenticate with Spotify
		if !sse.send("progress", map[string]string{"message": "Autenticando no Spotify..."}) {
			return
		}
		token, err := getSpotifyToken()
		if err != nil {
			sse.send("error", map[string]string{"message": "Erro ao autenticar no Spotify: " + err.Error()})
			return
		}

		// 2. Fetch artist info
		if !sse.send("progress", map[string]string{"message": "Buscando dados do artista..."}) {
			return
		}
		spArtist, err := fetchSpotifyArtist(token, artistSpotifyId)
		if err != nil {
			sse.send("error", map[string]string{"message": "Erro ao buscar artista: " + err.Error()})
			return
		}
		if !sse.send("progress", map[string]string{"message": fmt.Sprintf("Artista encontrado: %s", spArtist.Name)}) {
			return
		}

		// 3. Fetch all albums and tracks (metadata only)
		if !sse.send("progress", map[string]string{"message": "Buscando álbuns e faixas..."}) {
			return
		}
		spAlbums, err := fetchAllSpotifyAlbums(token, artistSpotifyId)
		if err != nil {
			sse.send("error", map[string]string{"message": "Erro ao buscar álbuns: " + err.Error()})
			return
		}

		var albums []importAlbum
		totalTracks := 0
		for _, spAlbum := range spAlbums {
			tracks, err := fetchAllSpotifyTracks(token, spAlbum.ID)
			if err != nil {
				sse.send("progress", map[string]string{"message": fmt.Sprintf("Aviso: não foi possível buscar faixas de '%s'", spAlbum.Name)})
				continue
			}
			albums = append(albums, importAlbum{spotify: spAlbum, tracks: tracks})
			totalTracks += len(tracks)
		}

		if !sse.send("progress", map[string]string{
			"message": fmt.Sprintf("Encontrados %d álbuns/singles com %d faixas no total", len(albums), totalTracks),
		}) {
			return
		}

		// 4. Create artist in DB
		genre := ""
		if len(spArtist.Genres) > 0 {
			genre = spArtist.Genres[0]
		}

		artistOID := primitive.NewObjectID()
		avatarPath := filepath.Join("uploads", "image", "avatar", artistOID.Hex()+".png")

		artistColor := "#8b5cf6"
		if len(spArtist.Images) > 0 {
			sse.send("progress", map[string]string{"message": "Baixando foto do artista..."})
			if err := downloadAndSaveImage(spArtist.Images[0].URL, avatarPath); err == nil {
				if col, err := extractDominantLightColor(avatarPath); err == nil {
					artistColor = col
				}
			}
		}

		// Fetch artist bio from TheAudioDB
		sse.send("progress", map[string]string{"message": "Buscando bio do artista..."})
		artistBio := fetchAudioDBBio(spArtist.Name)
		if artistBio != "" {
			sse.send("progress", map[string]string{"message": "Bio encontrada ✓"})
		} else {
			sse.send("progress", map[string]string{"message": "Bio não encontrada, continuando..."})
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

		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		_, err = artistCollection.InsertOne(ctx, dbArtist)
		cancel()
		if err != nil {
			sse.send("error", map[string]string{"message": "Erro ao criar artista no banco: " + err.Error()})
			return
		}
		if !sse.send("progress", map[string]string{"message": "Artista criado: " + spArtist.Name}) {
			return
		}

		// 5. Process each album and its tracks
		processedTracks := 0
		totalAlbums := 0
		totalMusics := 0
		failedTracks := 0

		for _, album := range albums {
			select {
			case <-c.Request.Context().Done():
				return
			default:
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
					sse.send("progress", map[string]string{
						"message": fmt.Sprintf("⚠ Erro ao criar álbum '%s': %s", album.spotify.Name, err.Error()),
					})
					continue
				}
				totalAlbums++
				sse.send("progress", map[string]string{
					"message": fmt.Sprintf("📀 Álbum criado: %s", album.spotify.Name),
				})
			}

			for _, track := range album.tracks {
				select {
				case <-c.Request.Context().Done():
					return
				default:
				}

				processedTracks++
				if !sse.send("progress", map[string]interface{}{
					"message": fmt.Sprintf("🔽 [%d/%d] Baixando: %s - %s", processedTracks, totalTracks, spArtist.Name, track.Name),
					"current": processedTracks,
					"total":   totalTracks,
				}) {
					return
				}

				musicOID := primitive.NewObjectID()

				// Search YouTube and download
				searchQuery := fmt.Sprintf("ytsearch1:%s - %s", spArtist.Name, track.Name)
				outputPath := fmt.Sprintf("./uploads/music/%s.%%(ext)s", musicOID.Hex())

				ytArgs := []string{
					"-f", "bestaudio[ext=m4a]/bestaudio[abr>0]/bestaudio/best",
					"-x", "--audio-format", "m4a",
					"-o", outputPath,
					"--no-playlist",
					"--socket-timeout", "30",
					"--retries", "3",
					"--extractor-args", "youtube:player_client=ios,android,web",
					"--add-header", "User-Agent:Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
				}
				// Use cookies file if available (absolute path, non-empty)
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
					if len(errMsg) > 200 {
						errMsg = errMsg[len(errMsg)-200:]
					}
					sse.send("progress", map[string]string{
						"message": fmt.Sprintf("⚠ Falha ao baixar '%s': %s | %s", track.Name, err.Error(), errMsg),
					})
					continue
				}

				// Generate waveform
				audioPath := fmt.Sprintf("uploads/music/%s.m4a", musicOID.Hex())
				waveform, err := GetWaveform(audioPath)
				if err != nil {
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
					sse.send("progress", map[string]string{
						"message": fmt.Sprintf("⚠ Erro ao salvar '%s' no banco: %s", track.Name, err.Error()),
					})
					continue
				}

				totalMusics++

				// Try to fetch and save synced lyrics from lrclib.net (best-effort)
				lrcPath := filepath.Join("uploads", "lyrics", musicOID.Hex()+".lrc")
				if err := fetchAndSaveLRC(spArtist.Name, track.Name, track.DurationMs, lrcPath); err == nil {
					sse.send("progress", map[string]string{
						"message": fmt.Sprintf("🎵 [%d/%d] %s (letra ✓)", processedTracks, totalTracks, track.Name),
					})
				} else {
					sse.send("progress", map[string]string{
						"message": fmt.Sprintf("✅ [%d/%d] %s", processedTracks, totalTracks, track.Name),
					})
				}
			}
		}

		// 6. Done
		summary := fmt.Sprintf("Importação concluída! Artista: %s | Álbuns: %d | Músicas: %d", spArtist.Name, totalAlbums, totalMusics)
		if failedTracks > 0 {
			summary += fmt.Sprintf(" | Falhas: %d", failedTracks)
		}
		sse.send("done", map[string]interface{}{
			"message":  summary,
			"artistId": artistOID.Hex(),
			"albums":   totalAlbums,
			"musics":   totalMusics,
			"failed":   failedTracks,
		})
	}
}

// --- Spotify API helpers ---

func parseSpotifyArtistId(url string) string {
	re := regexp.MustCompile(`artist[/:]([a-zA-Z0-9]+)`)
	matches := re.FindStringSubmatch(url)
	if len(matches) > 1 {
		return matches[1]
	}
	url = strings.TrimSpace(url)
	if matched, _ := regexp.MatchString(`^[a-zA-Z0-9]{22}$`, url); matched {
		return url
	}
	return ""
}

func getSpotifyToken() (string, error) {
	clientId := os.Getenv("SPOTIFY_CLIENT_ID")
	clientSecret := os.Getenv("SPOTIFY_CLIENT_SECRET")

	if clientId == "" || clientSecret == "" {
		return "", fmt.Errorf("SPOTIFY_CLIENT_ID e SPOTIFY_CLIENT_SECRET não configurados no .env")
	}

	authStr := base64.StdEncoding.EncodeToString([]byte(clientId + ":" + clientSecret))

	body := strings.NewReader("grant_type=client_credentials")
	req, err := http.NewRequest("POST", "https://accounts.spotify.com/api/token", body)
	if err != nil {
		return "", err
	}
	req.Header.Set("Authorization", "Basic "+authStr)
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	var token spotifyToken
	if err := json.NewDecoder(resp.Body).Decode(&token); err != nil {
		return "", err
	}

	if token.AccessToken == "" {
		return "", fmt.Errorf("falha ao obter token do Spotify")
	}

	return token.AccessToken, nil
}

func spotifyGet(token, url string) ([]byte, error) {
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+token)

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		respBody, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("Spotify API retornou %d: %s", resp.StatusCode, string(respBody))
	}

	return io.ReadAll(resp.Body)
}

func fetchSpotifyArtist(token, artistId string) (*spotifyArtist, error) {
	data, err := spotifyGet(token, "https://api.spotify.com/v1/artists/"+artistId)
	if err != nil {
		return nil, err
	}

	var artist spotifyArtist
	if err := json.Unmarshal(data, &artist); err != nil {
		return nil, err
	}

	return &artist, nil
}

func fetchAllSpotifyAlbums(token, artistId string) ([]spotifyAlbum, error) {
	var allAlbums []spotifyAlbum
	url := fmt.Sprintf("https://api.spotify.com/v1/artists/%s/albums?include_groups=album,single,compilation&limit=50&market=BR", artistId)

	for url != "" {
		data, err := spotifyGet(token, url)
		if err != nil {
			return nil, err
		}

		var resp spotifyAlbumsResponse
		if err := json.Unmarshal(data, &resp); err != nil {
			return nil, err
		}

		allAlbums = append(allAlbums, resp.Items...)

		if resp.Next != nil {
			url = *resp.Next
		} else {
			url = ""
		}
	}

	return allAlbums, nil
}

func fetchAllSpotifyTracks(token, albumId string) ([]spotifyTrack, error) {
	var allTracks []spotifyTrack
	url := fmt.Sprintf("https://api.spotify.com/v1/albums/%s/tracks?limit=50&market=BR", albumId)

	for url != "" {
		data, err := spotifyGet(token, url)
		if err != nil {
			return nil, err
		}

		var resp spotifyTracksResponse
		if err := json.Unmarshal(data, &resp); err != nil {
			return nil, err
		}

		allTracks = append(allTracks, resp.Items...)

		if resp.Next != nil {
			url = *resp.Next
		} else {
			url = ""
		}
	}

	return allTracks, nil
}

// --- External metadata helpers ---

// fetchAudioDBBio busca a bio do artista no TheAudioDB (key pública gratuita "1").
// Prefere a biografia em português; cai para inglês se não houver.
func fetchAudioDBBio(artistName string) string {
	apiURL := "https://www.theaudiodb.com/api/v1/json/1/search.php?s=" + url.QueryEscape(artistName)
	resp, err := http.Get(apiURL)
	if err != nil || resp.StatusCode != 200 {
		return ""
	}
	defer resp.Body.Close()

	var result struct {
		Artists []struct {
			BioPT string `json:"strBiographyPT"`
			BioEN string `json:"strBiographyEN"`
		} `json:"artists"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil || len(result.Artists) == 0 {
		return ""
	}

	if result.Artists[0].BioPT != "" {
		return result.Artists[0].BioPT
	}
	return result.Artists[0].BioEN
}

// fetchAndSaveLRC busca a letra sincronizada (.lrc) no lrclib.net e salva em destPath.
// durationMs é a duração em milissegundos (vem do Spotify).
func fetchAndSaveLRC(artistName, trackName string, durationMs int, destPath string) error {
	params := url.Values{}
	params.Set("artist_name", artistName)
	params.Set("track_name", trackName)
	if durationMs > 0 {
		params.Set("duration", fmt.Sprintf("%d", durationMs/1000))
	}

	apiURL := "https://lrclib.net/api/get?" + params.Encode()
	resp, err := http.Get(apiURL)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode == 404 {
		return fmt.Errorf("letra não encontrada")
	}
	if resp.StatusCode != 200 {
		return fmt.Errorf("lrclib retornou %d", resp.StatusCode)
	}

	var result struct {
		SyncedLyrics string `json:"syncedLyrics"`
		PlainLyrics  string `json:"plainLyrics"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return err
	}

	lrc := result.SyncedLyrics
	if lrc == "" {
		return fmt.Errorf("letra sincronizada não disponível")
	}

	if err := os.MkdirAll(filepath.Dir(destPath), os.ModePerm); err != nil {
		return err
	}
	return os.WriteFile(destPath, []byte(lrc), 0644)
}

// --- Image helpers ---

func downloadAndSaveImage(url, destPath string) error {
	if err := os.MkdirAll(filepath.Dir(destPath), os.ModePerm); err != nil {
		return err
	}

	resp, err := http.Get(url)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	img, _, err := image.Decode(resp.Body)
	if err != nil {
		return err
	}

	file, err := os.Create(destPath)
	if err != nil {
		return err
	}
	defer file.Close()

	return png.Encode(file, img)
}

func extractDominantLightColor(imgPath string) (string, error) {
	file, err := os.Open(imgPath)
	if err != nil {
		return "", err
	}
	defer file.Close()

	img, _, err := image.Decode(file)
	if err != nil {
		return "", err
	}

	bounds := img.Bounds()
	width := bounds.Max.X - bounds.Min.X
	height := bounds.Max.Y - bounds.Min.Y
	totalPixels := width * height

	step := 1
	if totalPixels > 10000 {
		step = totalPixels / 10000
	}

	type bucket struct {
		totalR, totalG, totalB float64
		count                  int
	}
	buckets := make([]bucket, 12)

	idx := 0
	for y := bounds.Min.Y; y < bounds.Max.Y; y++ {
		for x := bounds.Min.X; x < bounds.Max.X; x++ {
			idx++
			if idx%step != 0 {
				continue
			}

			r, g, b, _ := img.At(x, y).RGBA()
			rf := float64(r) / 65535.0
			gf := float64(g) / 65535.0
			bf := float64(b) / 65535.0

			h, s, l := rgbToHSL(rf, gf, bf)

			if s < 0.15 || l < 0.2 || l > 0.85 {
				continue
			}

			bucketIdx := int(h/30.0) % 12
			buckets[bucketIdx].totalR += rf
			buckets[bucketIdx].totalG += gf
			buckets[bucketIdx].totalB += bf
			buckets[bucketIdx].count++
		}
	}

	maxIdx := 0
	maxCount := 0
	for i, b := range buckets {
		if b.count > maxCount {
			maxCount = b.count
			maxIdx = i
		}
	}

	if maxCount == 0 {
		return "#8b5cf6", nil
	}

	b := buckets[maxIdx]
	avgR := b.totalR / float64(b.count)
	avgG := b.totalG / float64(b.count)
	avgB := b.totalB / float64(b.count)

	h, s, l := rgbToHSL(avgR, avgG, avgB)
	if l < 0.65 {
		l = 0.65
	}
	if s > 0.7 {
		s = 0.7
	}
	lightR, lightG, lightB := hslToRGB(h, s, l)

	return fmt.Sprintf("#%02x%02x%02x",
		int(math.Round(lightR*255)),
		int(math.Round(lightG*255)),
		int(math.Round(lightB*255)),
	), nil
}

func rgbToHSL(r, g, b float64) (h, s, l float64) {
	maxC := math.Max(r, math.Max(g, b))
	minC := math.Min(r, math.Min(g, b))
	l = (maxC + minC) / 2

	if maxC == minC {
		return 0, 0, l
	}

	d := maxC - minC
	if l > 0.5 {
		s = d / (2 - maxC - minC)
	} else {
		s = d / (maxC + minC)
	}

	switch maxC {
	case r:
		h = (g - b) / d
		if g < b {
			h += 6
		}
	case g:
		h = (b-r)/d + 2
	case b:
		h = (r-g)/d + 4
	}
	h *= 60

	return h, s, l
}

func hslToRGB(h, s, l float64) (r, g, b float64) {
	if s == 0 {
		return l, l, l
	}

	var q float64
	if l < 0.5 {
		q = l * (1 + s)
	} else {
		q = l + s - l*s
	}
	p := 2*l - q

	hNorm := h / 360.0

	hueToRGB := func(p, q, t float64) float64 {
		if t < 0 {
			t++
		}
		if t > 1 {
			t--
		}
		if t < 1.0/6.0 {
			return p + (q-p)*6*t
		}
		if t < 0.5 {
			return q
		}
		if t < 2.0/3.0 {
			return p + (q-p)*(2.0/3.0-t)*6
		}
		return p
	}

	r = hueToRGB(p, q, hNorm+1.0/3.0)
	g = hueToRGB(p, q, hNorm)
	b = hueToRGB(p, q, hNorm-1.0/3.0)

	return r, g, b
}
