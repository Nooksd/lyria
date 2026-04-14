package controllers

import (
	"context"
	"net/http"
	"os"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
)

func ToggleFavorite() gin.HandlerFunc {
	return func(c *gin.Context) {
		musicId := c.Param("musicId")
		musicObjectId, err := primitive.ObjectIDFromHex(musicId)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "ID de música inválido"})
			return
		}

		userClaims, exists := c.Get("user")
		if !exists {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Usuário não autenticado"})
			return
		}

		claims, ok := userClaims.(jwt.MapClaims)
		if !ok {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao processar token"})
			return
		}

		userId := claims["UserId"].(string)

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		var user struct {
			Favorites []primitive.ObjectID `bson:"favorites"`
		}
		err = userCollection.FindOne(ctx, bson.M{"uid": userId}).Decode(&user)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Usuário não encontrado"})
			return
		}

		isFavorite := false
		for _, fav := range user.Favorites {
			if fav == musicObjectId {
				isFavorite = true
				break
			}
		}

		var update bson.M
		if isFavorite {
			update = bson.M{"$pull": bson.M{"favorites": musicObjectId}, "$set": bson.M{"updatedAt": time.Now()}}
		} else {
			update = bson.M{"$addToSet": bson.M{"favorites": musicObjectId}, "$set": bson.M{"updatedAt": time.Now()}}
		}

		_, err = userCollection.UpdateOne(ctx, bson.M{"uid": userId}, update)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao atualizar favoritos"})
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"message":    "Favorito atualizado",
			"isFavorite": !isFavorite,
		})
	}
}

func GetFavorites() gin.HandlerFunc {
	return func(c *gin.Context) {
		userClaims, exists := c.Get("user")
		if !exists {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Usuário não autenticado"})
			return
		}

		claims, ok := userClaims.(jwt.MapClaims)
		if !ok {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao processar token"})
			return
		}

		userId := claims["UserId"].(string)
		serverURL := os.Getenv("SERVER_URL")

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		pipeline := []bson.M{
			{"$match": bson.M{"uid": userId}},
			{"$lookup": bson.M{
				"from":         "musics",
				"localField":   "favorites",
				"foreignField": "_id",
				"as":           "favoriteMusics",
				"pipeline": []bson.M{
					{"$lookup": bson.M{"from": "albums", "localField": "albumId", "foreignField": "_id", "as": "album"}},
					{"$unwind": bson.M{"path": "$album", "preserveNullAndEmptyArrays": true}},
					{"$lookup": bson.M{"from": "artists", "localField": "album.artistId", "foreignField": "_id", "as": "artist"}},
					{"$unwind": bson.M{"path": "$artist", "preserveNullAndEmptyArrays": true}},
					{"$addFields": bson.M{
						"coverUrl":   bson.M{"$concat": []interface{}{serverURL, "$album.albumCoverUrl"}},
						"artistName": "$artist.name",
						"albumName":  "$album.name",
						"color":      "$album.color",
						"url":        bson.M{"$concat": []interface{}{serverURL, "$url"}},
					}},
				},
			}},
			{"$project": bson.M{"favoriteMusics": 1}},
		}

		cursor, err := userCollection.Aggregate(ctx, pipeline)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao buscar favoritos"})
			return
		}

		var results []bson.M
		if err = cursor.All(ctx, &results); err != nil || len(results) == 0 {
			c.JSON(http.StatusOK, gin.H{"favorites": []bson.M{}})
			return
		}

		c.JSON(http.StatusOK, gin.H{"favorites": results[0]["favoriteMusics"]})
	}
}

func GetUserProfile() gin.HandlerFunc {
	return func(c *gin.Context) {
		userId := c.Param("userId")

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		serverURL := os.Getenv("SERVER_URL")

		pipeline := []bson.M{
			{"$match": bson.M{"uid": userId}},
			{"$lookup": bson.M{
				"from": "playlists",
				"let":  bson.M{"ownerId": "$_id"},
				"pipeline": []bson.M{
					{"$match": bson.M{"$expr": bson.M{"$eq": []interface{}{"$ownerId", "$$ownerId"}}}},
					{"$addFields": bson.M{
						"playlistCoverUrl": bson.M{"$concat": []interface{}{serverURL, "$playlistCoverUrl"}},
						"musicCount":       bson.M{"$size": bson.M{"$ifNull": []interface{}{"$musics", []interface{}{}}}},
					}},
					{"$project": bson.M{
						"_id":              1,
						"name":             1,
						"playlistCoverUrl": 1,
						"musicCount":       1,
					}},
				},
				"as": "playlists",
			}},
			{"$project": bson.M{
				"uid": 1, "name": 1, "bio": 1,
				"avatarUrl":     bson.M{"$concat": []interface{}{serverURL, "$avatarUrl"}},
				"playlists":     1,
				"favoriteCount": bson.M{"$size": bson.M{"$ifNull": []interface{}{"$favorites", []interface{}{}}}},
				"createdAt":     1,
			}},
		}

		cursor, err := userCollection.Aggregate(ctx, pipeline)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao buscar perfil"})
			return
		}

		var results []bson.M
		if err = cursor.All(ctx, &results); err != nil || len(results) == 0 {
			c.JSON(http.StatusNotFound, gin.H{"error": "Usuário não encontrado"})
			return
		}

		c.JSON(http.StatusOK, results[0])
	}
}
