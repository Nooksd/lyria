package controllers

import (
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
	"strconv"
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
	ID           string         `json:"id"`
	Name         string         `json:"name"`
	Genres       []string       `json:"genres"`
	Images       []spotifyImage `json:"images"`
	Popularity   int            `json:"popularity"`
	ExternalURLs struct {
		Spotify string `json:"spotify"`
	} `json:"external_urls"`
	Followers struct {
		Total int `json:"total"`
	} `json:"followers"`
}

type spotifyImage struct {
	URL    string `json:"url"`
	Height *int   `json:"height"`
	Width  *int   `json:"width"`
}

type spotifyAlbumsResponse struct {
	Items []spotifyAlbum `json:"items"`
	Next  *string        `json:"next"`
	Total int            `json:"total"`
}

type spotifyAlbum struct {
	ID           string         `json:"id"`
	Name         string         `json:"name"`
	AlbumType    string         `json:"album_type"`
	AlbumGroup   string         `json:"album_group"`
	Images       []spotifyImage `json:"images"`
	TotalTracks  int            `json:"total_tracks"`
	ReleaseDate  string         `json:"release_date"`
	ExternalURLs struct {
		Spotify string `json:"spotify"`
	} `json:"external_urls"`
}

type spotifyTracksResponse struct {
	Items []spotifyTrack `json:"items"`
	Next  *string        `json:"next"`
	Total int            `json:"total"`
}

type spotifyTrack struct {
	ID           string `json:"id"`
	Name         string `json:"name"`
	TrackNumber  int    `json:"track_number"`
	DiscNumber   int    `json:"disc_number"`
	DurationMs   int    `json:"duration_ms"`
	Popularity   int    `json:"popularity"`
	Explicit     bool   `json:"explicit"`
	ExternalURLs struct {
		Spotify string `json:"spotify"`
	} `json:"external_urls"`
}

type spotifySeveralTracksResponse struct {
	Tracks []spotifyTrack `json:"tracks"`
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
		token, err := getSpotifyTokenWithContext(c.Request.Context())
		if err != nil {
			sse.send("error", map[string]string{"message": "Erro ao autenticar no Spotify: " + err.Error()})
			return
		}

		// 2. Fetch artist info
		if !sse.send("progress", map[string]string{"message": "Buscando dados do artista..."}) {
			return
		}
		spArtist, err := fetchSpotifyArtist(c.Request.Context(), token, artistSpotifyId)
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
		spAlbums, err := fetchAllSpotifyAlbums(c.Request.Context(), token, artistSpotifyId)
		if err != nil {
			sse.send("error", map[string]string{"message": "Erro ao buscar álbuns: " + err.Error()})
			return
		}

		var albums []importAlbum
		totalTracks := 0
		for _, spAlbum := range spAlbums {
			tracks, err := fetchAllSpotifyTracks(c.Request.Context(), token, spAlbum.ID)
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
			ID:                artistOID,
			Name:              spArtist.Name,
			SpotifyID:         spArtist.ID,
			SpotifyURL:        spotifyExternalURL(spArtist.ExternalURLs.Spotify, "artist", spArtist.ID),
			SpotifyPopularity: spArtist.Popularity,
			SpotifyFollowers:  spArtist.Followers.Total,
			Genres:            spArtist.Genres,
			AvatarUrl:         "/image/avatar/" + artistOID.Hex(),
			BannerUrl:         "/image/banner/" + artistOID.Hex(),
			Bio:               artistBio,
			Color:             artistColor,
			CreatedAt:         now,
			UpdatedAt:         now,
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
					SpotifyID:     album.spotify.ID,
					SpotifyURL:    spotifyExternalURL(album.spotify.ExternalURLs.Spotify, "album", album.spotify.ID),
					AlbumType:     album.spotify.AlbumType,
					AlbumGroup:    album.spotify.AlbumGroup,
					ReleaseDate:   album.spotify.ReleaseDate,
					TotalTracks:   album.spotify.TotalTracks,
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

				// Anti-bot: sleep between YouTube downloads to avoid rate limiting
				if processedTracks > 0 {
					select {
					case <-c.Request.Context().Done():
						return
					case <-time.After(6 * time.Second):
					}
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
					"--ffmpeg-location", "/usr/bin/ffmpeg",
					"-o", outputPath,
					"--no-playlist",
					"--socket-timeout", "30",
					"--retries", "3",
					"--sleep-requests", "1.5",
					"--no-warnings",
					"--user-agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
				}
				// Use cookies file if available (absolute path, non-empty)
				cookiesPath := "/opt/lyria/server/cookies.txt"
				if info, err := os.Stat(cookiesPath); err == nil && info.Size() > 0 {
					ytArgs = append(ytArgs, "--cookies", cookiesPath)
				}
				ytArgs = append(ytArgs, searchQuery)

				// Smart retry: bot detection / cookie errors pause and retry with backoff
				reqCtx := c.Request.Context()
				result := runYtdlpWithRetry(reqCtx, ytArgs, defaultRetryConfig, func(msg string) {
					sse.send("progress", map[string]string{"message": msg})
				})
				if !result.Success {
					if result.Stderr == "cancelled" {
						return
					}
					failedTracks++
					sse.send("progress", map[string]string{
						"message": fmt.Sprintf("⚠ Falha ao baixar '%s': %s", track.Name, result.Stderr),
					})
					continue
				}

				// Find the actual downloaded file (yt-dlp may produce different extensions)
				audioPath := fmt.Sprintf("uploads/music/%s.m4a", musicOID.Hex())
				for _, ext := range []string{"m4a", "webm", "opus", "mp3", "ogg"} {
					candidate := fmt.Sprintf("uploads/music/%s.%s", musicOID.Hex(), ext)
					if _, statErr := os.Stat(candidate); statErr == nil {
						audioPath = candidate
						break
					}
				}

				// Ensure file is m4a for streaming compatibility
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
					sse.send("progress", map[string]string{
						"message": fmt.Sprintf("⚠ Waveform falhou para '%s': %v", track.Name, err),
					})
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
					ID:                musicOID,
					Url:               "/stream/" + musicOID.Hex(),
					Name:              track.Name,
					ArtistID:          artistOID,
					Genre:             genre,
					Waveform:          waveform,
					Color:             musicColor,
					SpotifyID:         track.ID,
					SpotifyURL:        spotifyExternalURL(track.ExternalURLs.Spotify, "track", track.ID),
					SpotifyPopularity: track.Popularity,
					SpotifyDurationMs: track.DurationMs,
					SpotifyTrackNo:    track.TrackNumber,
					SpotifyDiscNo:     track.DiscNumber,
					SpotifyExplicit:   track.Explicit,
					CreatedAt:         now,
					UpdatedAt:         now,
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
	return getSpotifyTokenWithContext(context.Background())
}

func getSpotifyTokenWithContext(ctx context.Context) (string, error) {
	clientId := os.Getenv("SPOTIFY_CLIENT_ID")
	clientSecret := os.Getenv("SPOTIFY_CLIENT_SECRET")

	if clientId == "" || clientSecret == "" {
		return "", fmt.Errorf("SPOTIFY_CLIENT_ID e SPOTIFY_CLIENT_SECRET não configurados no .env")
	}

	authStr := base64.StdEncoding.EncodeToString([]byte(clientId + ":" + clientSecret))

	attempt := 0
	for {
		body := strings.NewReader("grant_type=client_credentials")
		req, err := http.NewRequestWithContext(ctx, "POST", "https://accounts.spotify.com/api/token", body)
		if err != nil {
			return "", err
		}
		req.Header.Set("Authorization", "Basic "+authStr)
		req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			if ctx.Err() != nil {
				return "", ctx.Err()
			}
			if attempt < 4 {
				if err := sleepWithContext(ctx, spotifyRetryDelay("", attempt)); err != nil {
					return "", err
				}
				attempt++
				continue
			}
			return "", err
		}

		if resp.StatusCode == http.StatusTooManyRequests {
			wait := spotifyRetryDelay(resp.Header.Get("Retry-After"), attempt)
			resp.Body.Close()
			if err := sleepWithContext(ctx, wait); err != nil {
				return "", err
			}
			attempt++
			continue
		}

		if resp.StatusCode >= 500 && resp.StatusCode <= 599 && attempt < 5 {
			resp.Body.Close()
			if err := sleepWithContext(ctx, spotifyRetryDelay("", attempt)); err != nil {
				return "", err
			}
			attempt++
			continue
		}

		if resp.StatusCode != http.StatusOK {
			respBody, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
			resp.Body.Close()
			return "", fmt.Errorf("Spotify token retornou %d: %s", resp.StatusCode, string(respBody))
		}

		var token spotifyToken
		if err := json.NewDecoder(resp.Body).Decode(&token); err != nil {
			resp.Body.Close()
			return "", err
		}
		resp.Body.Close()

		if token.AccessToken == "" {
			return "", fmt.Errorf("falha ao obter token do Spotify")
		}

		return token.AccessToken, nil
	}
}

func spotifyGet(token, url string) ([]byte, error) {
	return spotifyGetWithContext(context.Background(), token, url)
}

func spotifyGetWithContext(ctx context.Context, token, url string) ([]byte, error) {
	attempt := 0

	for {
		req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
		if err != nil {
			return nil, err
		}
		req.Header.Set("Authorization", "Bearer "+token)

		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			if ctx.Err() != nil {
				return nil, ctx.Err()
			}
			if attempt < 4 {
				if err := sleepWithContext(ctx, spotifyRetryDelay("", attempt)); err != nil {
					return nil, err
				}
				attempt++
				continue
			}
			return nil, err
		}

		if resp.StatusCode == http.StatusOK {
			body, readErr := io.ReadAll(resp.Body)
			resp.Body.Close()
			return body, readErr
		}

		respBody, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
		resp.Body.Close()

		if resp.StatusCode == http.StatusTooManyRequests {
			wait := spotifyRetryDelay(resp.Header.Get("Retry-After"), attempt)
			if err := sleepWithContext(ctx, wait); err != nil {
				return nil, err
			}
			attempt++
			continue
		}

		if resp.StatusCode >= 500 && resp.StatusCode <= 599 && attempt < 5 {
			if err := sleepWithContext(ctx, spotifyRetryDelay("", attempt)); err != nil {
				return nil, err
			}
			attempt++
			continue
		}

		return nil, fmt.Errorf("Spotify API retornou %d: %s", resp.StatusCode, string(respBody))
	}
}

func spotifyRetryDelay(retryAfter string, attempt int) time.Duration {
	if retryAfter != "" {
		if seconds, err := strconv.Atoi(strings.TrimSpace(retryAfter)); err == nil && seconds > 0 {
			return capSpotifyDelay(time.Duration(seconds) * time.Second)
		}
		if retryAt, err := time.Parse(http.TimeFormat, retryAfter); err == nil {
			return capSpotifyDelay(time.Until(retryAt))
		}
	}

	delay := time.Duration(5*(1<<min(attempt, 5))) * time.Second
	return capSpotifyDelay(delay)
}

func capSpotifyDelay(delay time.Duration) time.Duration {
	if delay < 5*time.Second {
		return 5 * time.Second
	}
	if delay > 5*time.Minute {
		return 5 * time.Minute
	}
	return delay
}

func sleepWithContext(ctx context.Context, delay time.Duration) error {
	timer := time.NewTimer(delay)
	defer timer.Stop()

	select {
	case <-ctx.Done():
		return ctx.Err()
	case <-timer.C:
		return nil
	}
}

func fetchSpotifyArtist(ctx context.Context, token, artistId string) (*spotifyArtist, error) {
	data, err := spotifyGetWithContext(ctx, token, "https://api.spotify.com/v1/artists/"+artistId)
	if err != nil {
		return nil, err
	}

	var artist spotifyArtist
	if err := json.Unmarshal(data, &artist); err != nil {
		return nil, err
	}

	return &artist, nil
}

func spotifyExternalURL(value, itemType, id string) string {
	if strings.TrimSpace(value) != "" {
		return value
	}
	if strings.TrimSpace(id) == "" {
		return ""
	}
	return fmt.Sprintf("https://open.spotify.com/%s/%s", itemType, id)
}

func fetchAllSpotifyAlbums(ctx context.Context, token, artistId string) ([]spotifyAlbum, error) {
	var allAlbums []spotifyAlbum
	url := fmt.Sprintf("https://api.spotify.com/v1/artists/%s/albums?include_groups=album,single,compilation&limit=50&market=BR", artistId)

	for url != "" {
		data, err := spotifyGetWithContext(ctx, token, url)
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

func fetchAllSpotifyTracks(ctx context.Context, token, albumId string) ([]spotifyTrack, error) {
	var allTracks []spotifyTrack
	url := fmt.Sprintf("https://api.spotify.com/v1/albums/%s/tracks?limit=50&market=BR", albumId)

	for url != "" {
		data, err := spotifyGetWithContext(ctx, token, url)
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

	return hydrateSpotifyTrackDetails(ctx, token, allTracks)
}

func hydrateSpotifyTrackDetails(ctx context.Context, token string, tracks []spotifyTrack) ([]spotifyTrack, error) {
	if len(tracks) == 0 {
		return tracks, nil
	}

	trackByID := make(map[string]spotifyTrack, len(tracks))
	ids := make([]string, 0, len(tracks))
	for _, track := range tracks {
		if track.ID == "" {
			continue
		}
		trackByID[track.ID] = track
		ids = append(ids, track.ID)
	}
	if len(ids) == 0 {
		return tracks, nil
	}

	for start := 0; start < len(ids); start += 50 {
		end := start + 50
		if end > len(ids) {
			end = len(ids)
		}
		apiURL := "https://api.spotify.com/v1/tracks?market=BR&ids=" + strings.Join(ids[start:end], ",")
		data, err := spotifyGetWithContext(ctx, token, apiURL)
		if err != nil {
			return tracks, nil
		}

		var resp spotifySeveralTracksResponse
		if err := json.Unmarshal(data, &resp); err != nil {
			return tracks, nil
		}

		for _, fullTrack := range resp.Tracks {
			if fullTrack.ID == "" {
				continue
			}
			existing := trackByID[fullTrack.ID]
			if fullTrack.Name == "" {
				fullTrack.Name = existing.Name
			}
			if fullTrack.TrackNumber == 0 {
				fullTrack.TrackNumber = existing.TrackNumber
			}
			if fullTrack.DurationMs == 0 {
				fullTrack.DurationMs = existing.DurationMs
			}
			trackByID[fullTrack.ID] = fullTrack
		}
	}

	for i, track := range tracks {
		if hydrated, ok := trackByID[track.ID]; ok {
			tracks[i] = hydrated
		}
	}

	return tracks, nil
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
