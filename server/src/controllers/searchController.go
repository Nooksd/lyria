package controllers

import (
	"context"
	"net/http"
	"sort"
	"time"

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
)

func GeneralSearch() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		searchQuery := c.Query("query")
		if searchQuery == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Parâmetro de pesquisa 'query' é obrigatório"})
			return
		}

		var results []bson.M

		searchRegex := bson.M{"name": bson.M{"$regex": searchQuery, "$options": "i"}}

		artistCursor, err := artistCollection.Find(ctx, searchRegex)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao buscar artistas"})
			return
		}
		var artists []bson.M
		if err := artistCursor.All(ctx, &artists); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao processar artistas"})
			return
		}
		for i := range artists {
			results = append(results, bson.M{
				"name":        artists[i]["name"],
				"type":        "artist",
				"id":          artists[i]["_id"],
				"description": "Artista",
				"imageUrl":    artists[i]["avatarUrl"],
			})
		}

		albumPipeline := []bson.M{
			{"$match": searchRegex},
			{
				"$lookup": bson.M{
					"from":         "artists",
					"localField":   "artistId",
					"foreignField": "_id",
					"as":           "artist",
				},
			},
			{"$unwind": "$artist"},
		}

		albumCursor, err := albumCollection.Aggregate(ctx, albumPipeline)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao buscar álbuns"})
			return
		}
		var albums []bson.M
		if err := albumCursor.All(ctx, &albums); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao processar álbuns"})
			return
		}
		for i := range albums {
			results = append(results, bson.M{
				"name":        albums[i]["name"],
				"type":        "album",
				"id":          albums[i]["_id"],
				"description": "Álbum · " + albums[i]["artist"].(bson.M)["name"].(string),
				"imageUrl":    albums[i]["albumCoverUrl"],
			})
		}

		musicPipeline := []bson.M{
			{"$match": searchRegex},
			{
				"$lookup": bson.M{
					"from":         "albums",
					"localField":   "albumId",
					"foreignField": "_id",
					"as":           "album",
				},
			},
			{"$unwind": "$album"},
			{
				"$lookup": bson.M{
					"from":         "artists",
					"localField":   "album.artistId",
					"foreignField": "_id",
					"as":           "artist",
				},
			},
			{"$unwind": "$artist"},
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
		for i := range musics {
			results = append(results, bson.M{
				"name":        musics[i]["name"],
				"type":        "music",
				"id":          musics[i]["_id"],
				"description": "Música · " + musics[i]["artist"].(bson.M)["name"].(string),
				"music":       musics[i],
				"imageUrl":    musics[i]["album"].(bson.M)["albumCoverUrl"].(string),
			})
		}

		sort.Slice(results, func(i, j int) bool {
			return results[i]["name"].(string) < results[j]["name"].(string)
		})

		c.JSON(http.StatusOK, gin.H{"results": results})
	}
}
