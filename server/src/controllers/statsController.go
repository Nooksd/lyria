package controllers

import (
	"context"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"sync"
	"time"

	database "server/src/db"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
)

var playEventsCollection *mongo.Collection = database.OpenCollection(database.Client, "play_events")

type TopMusic struct {
	ID         primitive.ObjectID `json:"_id"`
	Name       string             `json:"name"`
	ArtistName string             `json:"artistName"`
	CoverUrl   string             `json:"coverUrl"`
	PlayCount  int                `json:"playCount"`
}

type TopArtist struct {
	ID        primitive.ObjectID `json:"_id"`
	Name      string             `json:"name"`
	AvatarUrl string             `json:"avatarUrl"`
	PlayCount int                `json:"playCount"`
}

type DashboardStats struct {
	MusicCount    int64       `json:"musicCount"`
	ArtistCount   int64       `json:"artistCount"`
	AlbumCount    int64       `json:"albumCount"`
	UserCount     int64       `json:"userCount"`
	DiskUsageMB   float64     `json:"diskUsageMB"`
	TopMusics     []TopMusic  `json:"topMusics"`
	TopArtists    []TopArtist `json:"topArtists"`
	TotalPlays    int64       `json:"totalPlays"`
	PlaysToday    int64       `json:"playsToday"`
	PlaysThisWeek int64       `json:"playsThisWeek"`
	UpdatedAt     time.Time   `json:"updatedAt"`
}

var (
	cachedStats *DashboardStats
	statsMu     sync.RWMutex
)

func RecordPlay() gin.HandlerFunc {
	return func(c *gin.Context) {
		musicId := c.Param("musicId")
		objectId, err := primitive.ObjectIDFromHex(musicId)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "ID inválido"})
			return
		}

		userClaims, exists := c.Get("user")
		if !exists {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Não autenticado"})
			return
		}
		claims := userClaims.(jwt.MapClaims)
		userId := claims["UserId"].(string)

		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		event := bson.M{
			"_id":       primitive.NewObjectID(),
			"musicId":   objectId,
			"userId":    userId,
			"createdAt": time.Now(),
		}

		_, err = playEventsCollection.InsertOne(ctx, event)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao registrar play"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "ok"})
	}
}

func GetDashboardStats() gin.HandlerFunc {
	return func(c *gin.Context) {
		statsMu.RLock()
		stats := cachedStats
		statsMu.RUnlock()

		if stats == nil {
			c.JSON(http.StatusOK, gin.H{"message": "Estatísticas ainda não coletadas"})
			return
		}

		c.JSON(http.StatusOK, stats)
	}
}

func StartStatsCollector() {
	go func() {
		// Collect immediately on startup
		collectStats()

		ticker := time.NewTicker(5 * time.Minute)
		defer ticker.Stop()

		for range ticker.C {
			collectStats()
		}
	}()
	log.Println("Stats collector started (every 5 min)")
}

func collectStats() {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	serverURL := os.Getenv("SERVER_URL")

	musicCount, _ := musicCollection.CountDocuments(ctx, bson.M{})
	artistCount, _ := artistCollection.CountDocuments(ctx, bson.M{})
	albumCount, _ := albumCollection.CountDocuments(ctx, bson.M{})
	userCount, _ := userCollection.CountDocuments(ctx, bson.M{})
	totalPlays, _ := playEventsCollection.CountDocuments(ctx, bson.M{})

	now := time.Now()
	startOfDay := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	startOfWeek := startOfDay.AddDate(0, 0, -int(now.Weekday()))

	playsToday, _ := playEventsCollection.CountDocuments(ctx, bson.M{
		"createdAt": bson.M{"$gte": startOfDay},
	})
	playsThisWeek, _ := playEventsCollection.CountDocuments(ctx, bson.M{
		"createdAt": bson.M{"$gte": startOfWeek},
	})

	diskUsage := calculateDiskUsage("uploads")

	// Top 10 musics by play count
	topMusics := getTopMusics(ctx, serverURL)

	// Top 10 artists by play count
	topArtists := getTopArtists(ctx, serverURL)

	stats := &DashboardStats{
		MusicCount:    musicCount,
		ArtistCount:   artistCount,
		AlbumCount:    albumCount,
		UserCount:     userCount,
		DiskUsageMB:   diskUsage,
		TopMusics:     topMusics,
		TopArtists:    topArtists,
		TotalPlays:    totalPlays,
		PlaysToday:    playsToday,
		PlaysThisWeek: playsThisWeek,
		UpdatedAt:     now,
	}

	statsMu.Lock()
	cachedStats = stats
	statsMu.Unlock()
}

func getTopMusics(ctx context.Context, serverURL string) []TopMusic {
	pipeline := mongo.Pipeline{
		{{Key: "$group", Value: bson.M{
			"_id":   "$musicId",
			"count": bson.M{"$sum": 1},
		}}},
		{{Key: "$sort", Value: bson.M{"count": -1}}},
		{{Key: "$limit", Value: 10}},
		{{Key: "$lookup", Value: bson.M{
			"from":         "musics",
			"localField":   "_id",
			"foreignField": "_id",
			"as":           "music",
		}}},
		{{Key: "$unwind", Value: "$music"}},
		{{Key: "$lookup", Value: bson.M{
			"from":         "artists",
			"localField":   "music.artistId",
			"foreignField": "_id",
			"as":           "artist",
		}}},
		{{Key: "$unwind", Value: bson.M{
			"path":                       "$artist",
			"preserveNullAndEmptyArrays": true,
		}}},
		{{Key: "$project", Value: bson.M{
			"_id":        "$music._id",
			"name":       "$music.name",
			"artistName": bson.M{"$ifNull": []interface{}{"$artist.name", "Desconhecido"}},
			"coverUrl":   "$music.coverUrl",
			"playCount":  "$count",
		}}},
	}

	cursor, err := playEventsCollection.Aggregate(ctx, pipeline)
	if err != nil {
		return []TopMusic{}
	}
	defer cursor.Close(ctx)

	var results []TopMusic
	if err := cursor.All(ctx, &results); err != nil {
		return []TopMusic{}
	}

	for i, m := range results {
		if m.CoverUrl != "" && m.CoverUrl[0] == '/' {
			results[i].CoverUrl = serverURL + m.CoverUrl
		}
		if m.CoverUrl == "" {
			results[i].CoverUrl = serverURL + "/image/cover/" + m.ID.Hex()
		}
	}

	return results
}

func getTopArtists(ctx context.Context, serverURL string) []TopArtist {
	pipeline := mongo.Pipeline{
		{{Key: "$lookup", Value: bson.M{
			"from":         "musics",
			"localField":   "musicId",
			"foreignField": "_id",
			"as":           "music",
		}}},
		{{Key: "$unwind", Value: "$music"}},
		{{Key: "$group", Value: bson.M{
			"_id":   "$music.artistId",
			"count": bson.M{"$sum": 1},
		}}},
		{{Key: "$sort", Value: bson.M{"count": -1}}},
		{{Key: "$limit", Value: 10}},
		{{Key: "$lookup", Value: bson.M{
			"from":         "artists",
			"localField":   "_id",
			"foreignField": "_id",
			"as":           "artist",
		}}},
		{{Key: "$unwind", Value: "$artist"}},
		{{Key: "$project", Value: bson.M{
			"_id":       "$artist._id",
			"name":      "$artist.name",
			"avatarUrl": "$artist.avatarUrl",
			"playCount": "$count",
		}}},
	}

	cursor, err := playEventsCollection.Aggregate(ctx, pipeline)
	if err != nil {
		return []TopArtist{}
	}
	defer cursor.Close(ctx)

	var results []TopArtist
	if err := cursor.All(ctx, &results); err != nil {
		return []TopArtist{}
	}

	for i, a := range results {
		if a.AvatarUrl != "" && a.AvatarUrl[0] == '/' {
			results[i].AvatarUrl = serverURL + a.AvatarUrl
		}
	}

	return results
}

func calculateDiskUsage(root string) float64 {
	var totalBytes int64

	filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil
		}
		if !info.IsDir() {
			totalBytes += info.Size()
		}
		return nil
	})

	return float64(totalBytes) / (1024 * 1024)
}

// GetTopMusicsByArtist returns top N music IDs for an artist by play count
func GetTopMusicsByArtist(ctx context.Context, artistID primitive.ObjectID, limit int) []primitive.ObjectID {
	pipeline := mongo.Pipeline{
		{{Key: "$lookup", Value: bson.M{
			"from":         "musics",
			"localField":   "musicId",
			"foreignField": "_id",
			"as":           "music",
		}}},
		{{Key: "$unwind", Value: "$music"}},
		{{Key: "$match", Value: bson.M{"music.artistId": artistID}}},
		{{Key: "$group", Value: bson.M{
			"_id":   "$musicId",
			"count": bson.M{"$sum": 1},
		}}},
		{{Key: "$sort", Value: bson.M{"count": -1}}},
		{{Key: "$limit", Value: limit}},
	}

	cursor, err := playEventsCollection.Aggregate(ctx, pipeline)
	if err != nil {
		return nil
	}
	defer cursor.Close(ctx)

	var results []struct {
		ID    primitive.ObjectID `bson:"_id"`
		Count int                `bson:"count"`
	}
	if err := cursor.All(ctx, &results); err != nil {
		return nil
	}

	ids := make([]primitive.ObjectID, len(results))
	for i, r := range results {
		ids[i] = r.ID
	}
	return ids
}
