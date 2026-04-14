package controllers

import (
	"context"
	"net/http"
	"os"
	"time"

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
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
		_, _ = c.GetQuery("page")
		if p, ok := c.GetQuery("page"); ok {
			_ = p
		}

		// Parse page and limit
		if p := page; p != "" {
			for _, ch := range p {
				if ch < '0' || ch > '9' {
					break
				}
			}
		}

		pInt := 0
		for _, ch := range page {
			pInt = pInt*10 + int(ch-'0')
		}
		if pInt > 0 {
			pageInt = pInt
		}

		lInt := 0
		for _, ch := range limit {
			lInt = lInt*10 + int(ch-'0')
		}
		if lInt > 0 {
			limitInt = lInt
		}

		skip := (pageInt - 1) * limitInt

		// Find artists by genre
		artistPipeline := []bson.M{
			{"$match": bson.M{"genres": bson.M{"$regex": genre, "$options": "i"}}},
		}
		artistCursor, err := artistCollection.Find(ctx, bson.M{"genres": bson.M{"$regex": genre, "$options": "i"}})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao buscar artistas"})
			return
		}
		_ = artistPipeline

		var artists []bson.M
		if err := artistCursor.All(ctx, &artists); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao processar artistas"})
			return
		}

		for i := range artists {
			artists[i]["avatarUrl"] = serverURL + artists[i]["avatarUrl"].(string)
		}

		// Find musics by genre with pagination
		musicPipeline := []bson.M{
			{"$match": bson.M{"genre": bson.M{"$regex": genre, "$options": "i"}}},
			{"$lookup": bson.M{"from": "albums", "localField": "albumId", "foreignField": "_id", "as": "album"}},
			{"$unwind": "$album"},
			{"$lookup": bson.M{"from": "artists", "localField": "album.artistId", "foreignField": "_id", "as": "artist"}},
			{"$unwind": "$artist"},
			{"$addFields": bson.M{
				"coverUrl":   bson.M{"$concat": []interface{}{serverURL, "$album.albumCoverUrl"}},
				"artistName": "$artist.name",
				"albumName":  "$album.name",
				"color":      "$album.color",
				"url":        bson.M{"$concat": []interface{}{serverURL, "$url"}},
			}},
			{"$skip": skip},
			{"$limit": limitInt},
		}

		musicCursor, err := musicCollection.Aggregate(ctx, musicPipeline)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao buscar músicas"})
			return
		}

		var musics []bson.M
		if err := musicCursor.All(ctx, &musics); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao processar músicas"})
			return
		}

		// Get total count
		totalCount, err := musicCollection.CountDocuments(ctx, bson.M{"genre": bson.M{"$regex": genre, "$options": "i"}})
		if err != nil {
			totalCount = 0
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

		// Add lyrics to musics
		for i := range musics {
			if id, ok := musics[i]["_id"]; ok {
				lyricsPath := "./uploads/lyrics/" + id.(interface{ Hex() string }).Hex() + ".lrc"
				if _, err := os.Stat(lyricsPath); err == nil {
					lyrics, err := parseLRC(lyricsPath)
					if err == nil {
						musics[i]["lyrics"] = lyrics
					}
				}
			}
		}

		c.JSON(http.StatusOK, gin.H{
			"genre":   genre,
			"artists": artists,
			"albums":  albums,
			"musics":  musics,
			"total":   totalCount,
			"page":    pageInt,
			"limit":   limitInt,
		})
	}
}
