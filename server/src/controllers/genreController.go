package controllers

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"strings"
	"time"

	model "server/src/models"

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo/options"
)

func SearchByGenre() gin.HandlerFunc {
	return func(c *gin.Context) {
		genre := c.Param("genre")
		page := c.DefaultQuery("page", "1")
		limit := c.DefaultQuery("limit", "20")

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		serverURL := os.Getenv("SERVER_URL")

		pageInt := 1
		limitInt := 20

		pInt := 0
		for _, ch := range page {
			if ch >= '0' && ch <= '9' {
				pInt = pInt*10 + int(ch-'0')
			}
		}
		if pInt > 0 {
			pageInt = pInt
		}

		lInt := 0
		for _, ch := range limit {
			if ch >= '0' && ch <= '9' {
				lInt = lInt*10 + int(ch-'0')
			}
		}
		if lInt > 0 {
			limitInt = lInt
		}

		skip := int64((pageInt - 1) * limitInt)

		// Find artists by genre
		artistCursor, err := artistCollection.Find(ctx, bson.M{"genres": bson.M{"$regex": genre, "$options": "i"}})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao buscar artistas"})
			return
		}

		var artists []model.Artist
		if err := artistCursor.All(ctx, &artists); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao processar artistas"})
			return
		}

		enrichedArtists := make([]gin.H, len(artists))
		for i, a := range artists {
			enrichedArtists[i] = gin.H{
				"_id":       a.ID,
				"name":      a.Name,
				"avatarUrl": serverURL + a.AvatarUrl,
				"genres":    a.Genres,
			}
		}

		// Find musics by genre with pagination
		genreFilter := bson.M{"genre": bson.M{"$regex": genre, "$options": "i"}}

		totalCount, err := musicCollection.CountDocuments(ctx, genreFilter)
		if err != nil {
			totalCount = 0
		}

		var musics []model.Music
		musicCursor, err := musicCollection.Find(
			ctx,
			genreFilter,
			options.Find().SetSkip(skip).SetLimit(int64(limitInt)).SetSort(bson.M{"createdAt": -1}),
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao buscar músicas"})
			return
		}
		if err := musicCursor.All(ctx, &musics); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao processar músicas"})
			return
		}

		// Collect unique album and artist IDs
		albumIDs := make(map[primitive.ObjectID]bool)
		artistIDs := make(map[primitive.ObjectID]bool)
		for _, m := range musics {
			if m.AlbumID != primitive.NilObjectID {
				albumIDs[m.AlbumID] = true
			}
			artistIDs[m.ArtistID] = true
		}

		// Fetch albums
		albumMap := make(map[primitive.ObjectID]model.Album)
		if len(albumIDs) > 0 {
			ids := make([]primitive.ObjectID, 0, len(albumIDs))
			for id := range albumIDs {
				ids = append(ids, id)
			}
			albumCursor, err := albumCollection.Find(ctx, bson.M{"_id": bson.M{"$in": ids}})
			if err == nil {
				var albumList []model.Album
				if err := albumCursor.All(ctx, &albumList); err == nil {
					for _, a := range albumList {
						albumMap[a.ID] = a
					}
				}
			}
		}

		// Fetch artists
		artistMap := make(map[primitive.ObjectID]model.Artist)
		if len(artistIDs) > 0 {
			ids := make([]primitive.ObjectID, 0, len(artistIDs))
			for id := range artistIDs {
				ids = append(ids, id)
			}
			artCursor, err := artistCollection.Find(ctx, bson.M{"_id": bson.M{"$in": ids}})
			if err == nil {
				var artList []model.Artist
				if err := artCursor.All(ctx, &artList); err == nil {
					for _, a := range artList {
						artistMap[a.ID] = a
					}
				}
			}
		}

		// Enrich musics
		enrichedMusics := make([]gin.H, len(musics))
		for i, m := range musics {
			coverUrl := m.CoverUrl
			color := m.Color
			albumName := ""
			artistName := ""

			if a, ok := albumMap[m.AlbumID]; ok {
				albumName = a.Name
				if coverUrl == "" {
					coverUrl = serverURL + a.AlbumCoverUrl
				}
				if color == "" {
					color = a.Color
				}
			}
			if a, ok := artistMap[m.ArtistID]; ok {
				artistName = a.Name
			}
			if coverUrl == "" {
				coverUrl = serverURL + "/image/cover/" + m.ID.Hex()
			}
			if m.CoverUrl != "" && !strings.HasPrefix(m.CoverUrl, "http") {
				coverUrl = serverURL + m.CoverUrl
			}

			var lyrics interface{}
			lyricsPath := fmt.Sprintf("./uploads/lyrics/%s.lrc", m.ID.Hex())
			if _, err := os.Stat(lyricsPath); err == nil {
				if parsed, err := parseLRC(lyricsPath); err == nil {
					lyrics = parsed
				}
			}

			enrichedMusics[i] = gin.H{
				"_id":        m.ID,
				"url":        serverURL + m.Url,
				"name":       m.Name,
				"artistId":   m.ArtistID,
				"artistName": artistName,
				"albumId":    m.AlbumID,
				"albumName":  albumName,
				"genre":      m.Genre,
				"coverUrl":   coverUrl,
				"color":      color,
				"waveform":   m.Waveform,
				"lyrics":     lyrics,
				"createdAt":  m.CreatedAt,
				"updatedAt":  m.UpdatedAt,
			}
		}

		// Find albums that have songs of this genre
		albumPipeline := []bson.M{
			{"$match": bson.M{"genre": bson.M{"$regex": genre, "$options": "i"}}},
			{"$group": bson.M{"_id": "$albumId"}},
			{"$lookup": bson.M{"from": "albums", "localField": "_id", "foreignField": "_id", "as": "album"}},
			{"$unwind": "$album"},
			{"$lookup": bson.M{"from": "artists", "localField": "album.artistId", "foreignField": "_id", "as": "artist"}},
			{"$unwind": "$artist"},
			{"$project": bson.M{
				"_id":           "$album._id",
				"name":          "$album.name",
				"albumCoverUrl": bson.M{"$concat": []interface{}{serverURL, "$album.albumCoverUrl"}},
				"color":         "$album.color",
				"artistName":    "$artist.name",
				"artistId":      "$artist._id",
			}},
		}

		albumCursor, err := musicCollection.Aggregate(ctx, albumPipeline)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao buscar álbuns"})
			return
		}

		var albums []bson.M
		if err := albumCursor.All(ctx, &albums); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao processar álbuns"})
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"genre":   genre,
			"artists": enrichedArtists,
			"albums":  albums,
			"musics":  enrichedMusics,
			"total":   totalCount,
			"page":    pageInt,
			"limit":   limitInt,
		})
	}
}
