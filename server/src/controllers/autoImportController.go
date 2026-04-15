package controllers

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
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

var settingsCollection *mongo.Collection = database.OpenCollection(database.Client, "settings")

var autoImportGenres = []string{
	"pop", "rock", "hip hop", "r&b", "electronic", "latin",
	"indie", "country", "jazz", "reggaeton", "k-pop", "metal",
	"folk", "blues", "soul", "funk", "punk", "alternative",
	"dance", "classical", "sertanejo", "mpb", "pagode", "samba",
	"forró", "axé", "trap", "rap", "edm", "bossa nova",
}

type autoImportState struct {
	ID         string `bson:"_id" json:"-"`
	Enabled    bool   `bson:"enabled" json:"enabled"`
	GenreIndex int    `bson:"genreIndex" json:"genreIndex"`
	Offset     int    `bson:"offset" json:"offset"`
}

// AutoImporter manages automatic discovery and import of popular Spotify artists
type AutoImporter struct {
	mu      sync.Mutex
	cancel  context.CancelFunc
	running bool
}

var autoImporter = &AutoImporter{}

// InitAutoImport restores autoimport state on server startup
func InitAutoImport() {
	state := loadAutoImportState()
	if state.Enabled {
		autoImporter.Start()
	}
}

func (ai *AutoImporter) Start() {
	ai.mu.Lock()
	if ai.running {
		ai.mu.Unlock()
		return
	}
	ai.running = true
	ctx, cancel := context.WithCancel(context.Background())
	ai.cancel = cancel
	ai.mu.Unlock()

	saveAutoImportEnabled(true)
	go ai.run(ctx)
}

func (ai *AutoImporter) Stop() {
	ai.mu.Lock()
	if ai.cancel != nil {
		ai.cancel()
	}
	ai.running = false
	ai.mu.Unlock()

	saveAutoImportEnabled(false)
}

func (ai *AutoImporter) IsRunning() bool {
	ai.mu.Lock()
	defer ai.mu.Unlock()
	return ai.running
}

func loadAutoImportState() autoImportState {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	var state autoImportState
	err := settingsCollection.FindOne(ctx, bson.M{"_id": "autoimport"}).Decode(&state)
	if err != nil {
		return autoImportState{ID: "autoimport"}
	}
	return state
}

func saveAutoImportEnabled(enabled bool) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	settingsCollection.UpdateOne(ctx,
		bson.M{"_id": "autoimport"},
		bson.M{"$set": bson.M{"enabled": enabled}},
		options.Update().SetUpsert(true),
	)
}

func saveAutoImportProgress(genreIndex, offset int) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	settingsCollection.UpdateOne(ctx,
		bson.M{"_id": "autoimport"},
		bson.M{"$set": bson.M{"genreIndex": genreIndex, "offset": offset}},
		options.Update().SetUpsert(true),
	)
}

// --- Spotify search for artists ---

type spotifySearchArtistsResponse struct {
	Artists struct {
		Items []spotifyArtist `json:"items"`
		Total int             `json:"total"`
	} `json:"artists"`
}

func searchSpotifyArtists(token, genre string, offset int) ([]spotifyArtist, error) {
	q := url.QueryEscape(fmt.Sprintf("genre:%s", genre))
	apiURL := fmt.Sprintf("https://api.spotify.com/v1/search?q=%s&type=artist&market=BR&limit=50&offset=%d", q, offset)

	data, err := spotifyGet(token, apiURL)
	if err != nil {
		return nil, err
	}

	var resp spotifySearchArtistsResponse
	if err := json.Unmarshal(data, &resp); err != nil {
		return nil, err
	}

	return resp.Artists.Items, nil
}

func isArtistAlreadyImported(spotifyID string) bool {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Check import_jobs for any job with this artist's Spotify URL
	pattern := "artist/" + spotifyID
	count, err := importJobCollection.CountDocuments(ctx, bson.M{
		"spotifyUrl": bson.M{"$regex": pattern},
	})
	return err == nil && count > 0
}

func countPendingImportJobs() int64 {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	count, _ := importJobCollection.CountDocuments(ctx, bson.M{
		"status": bson.M{"$in": []string{"queued", "running"}},
	})
	return count
}

func (ai *AutoImporter) run(ctx context.Context) {
	defer func() {
		ai.mu.Lock()
		ai.running = false
		ai.mu.Unlock()
	}()

	state := loadAutoImportState()

	for {
		select {
		case <-ctx.Done():
			return
		default:
		}

		// Wait until queue has room (max 2 pending jobs)
		for countPendingImportJobs() >= 2 {
			select {
			case <-ctx.Done():
				return
			case <-time.After(30 * time.Second):
			}
		}

		// Get fresh Spotify token
		token, err := getSpotifyToken()
		if err != nil {
			select {
			case <-ctx.Done():
				return
			case <-time.After(60 * time.Second):
				continue
			}
		}

		genre := autoImportGenres[state.GenreIndex%len(autoImportGenres)]

		artists, err := searchSpotifyArtists(token, genre, state.Offset)
		if err != nil || len(artists) == 0 {
			// Move to next genre
			state.GenreIndex++
			state.Offset = 0
			saveAutoImportProgress(state.GenreIndex, state.Offset)

			// If we've cycled through all genres, pause before restarting
			if state.GenreIndex%len(autoImportGenres) == 0 {
				select {
				case <-ctx.Done():
					return
				case <-time.After(5 * time.Minute):
				}
			}
			continue
		}

		for _, artist := range artists {
			select {
			case <-ctx.Done():
				return
			default:
			}

			if artist.ID == "" {
				continue
			}

			if isArtistAlreadyImported(artist.ID) {
				continue
			}

			// Create import job
			spotifyUrl := "https://open.spotify.com/artist/" + artist.ID
			now := time.Now()
			job := model.ImportJob{
				ID:          primitive.NewObjectID(),
				SpotifyUrl:  spotifyUrl,
				ArtistName:  artist.Name,
				Status:      "queued",
				Logs:        []model.ImportLog{},
				FailedItems: []model.ImportFailedItem{},
				CreatedAt:   now,
				UpdatedAt:   now,
			}

			jobCtx, jobCancel := context.WithTimeout(context.Background(), 5*time.Second)
			_, err := importJobCollection.InsertOne(jobCtx, job)
			jobCancel()
			if err != nil {
				continue
			}

			importQueue.Enqueue(job.ID)

			// Wait for queue to clear before adding more
			for countPendingImportJobs() >= 2 {
				select {
				case <-ctx.Done():
					return
				case <-time.After(30 * time.Second):
				}
			}
		}

		// Advance offset for this genre
		state.Offset += 50
		saveAutoImportProgress(state.GenreIndex, state.Offset)

		// Small delay between Spotify API calls to respect rate limits
		select {
		case <-ctx.Done():
			return
		case <-time.After(2 * time.Second):
		}
	}
}

// ===================== HTTP Handlers =====================

func GetAutoImportStatus() gin.HandlerFunc {
	return func(c *gin.Context) {
		state := loadAutoImportState()
		genreIdx := state.GenreIndex % len(autoImportGenres)

		c.JSON(http.StatusOK, gin.H{
			"enabled":    autoImporter.IsRunning(),
			"genreIndex": state.GenreIndex,
			"offset":     state.Offset,
			"genre":      autoImportGenres[genreIdx],
		})
	}
}

func ToggleAutoImport() gin.HandlerFunc {
	return func(c *gin.Context) {
		var body struct {
			Enabled bool `json:"enabled"`
		}
		if err := c.ShouldBindJSON(&body); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Campo 'enabled' é obrigatório"})
			return
		}

		if body.Enabled {
			autoImporter.Start()
		} else {
			autoImporter.Stop()
		}

		c.JSON(http.StatusOK, gin.H{"enabled": autoImporter.IsRunning()})
	}
}
