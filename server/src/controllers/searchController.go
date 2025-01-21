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
			artists[i]["category"] = "artist"
		}

		albumCursor, err := albumCollection.Find(ctx, searchRegex)
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
			albums[i]["category"] = "album"
		}

		musicCursor, err := musicCollection.Find(ctx, searchRegex)
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
			musics[i]["category"] = "music"
		}

		results = append(results, artists...)
		results = append(results, albums...)
		results = append(results, musics...)

		sort.Slice(results, func(i, j int) bool {
			return results[i]["name"].(string) < results[j]["name"].(string)
		})

		c.JSON(http.StatusOK, gin.H{"results": results})
	}
}
