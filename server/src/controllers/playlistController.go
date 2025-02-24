package controllers

import (
	"context"
	"net/http"
	"os"
	database "server/src/db"
	model "server/src/models"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
)

var playlistCollection *mongo.Collection = database.OpenCollection(database.Client, "playlists")

func CreatePlaylist() gin.HandlerFunc {
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

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		var playlist model.Playlist

		if err := c.BindJSON(&playlist); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Dados inválidos"})
			return
		}

		ownerID, err := primitive.ObjectIDFromHex(userId)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "ID inválido"})
			return
		}

		playlist.ID = primitive.NewObjectID()
		playlist.OwnerID = ownerID
		playlist.PlaylistCoverUrl = "/image/playlist/" + playlist.ID.Hex()
		playlist.IsPublic = false
		playlist.CreatedAt = time.Now()
		playlist.UpdatedAt = time.Now()

		validationErrors := validate.Struct(playlist)
		if validationErrors != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": validationErrors.Error()})
			return
		}

		_, err = playlistCollection.InsertOne(ctx, playlist)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao criar a playlist"})
			return
		}

		newPlaylist := playlist
		newPlaylist.PlaylistCoverUrl = os.Getenv("SERVER_URL") + playlist.PlaylistCoverUrl
		newPlaylist.ID = playlist.ID

		c.JSON(http.StatusCreated, gin.H{"message": "Playlist criada com sucesso", "playlist": newPlaylist})
	}
}

func GetPlaylist() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		playlistId := c.Param("playlistId")
		objectId, err := primitive.ObjectIDFromHex(playlistId)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "ID inválido"})
			return
		}

		pipeline := []bson.M{
			{"$match": bson.M{"_id": objectId}},
			{"$lookup": bson.M{
				"from":         "musics",
				"localField":   "musics",
				"foreignField": "_id",
				"as":           "musics",
			}},
			{"$project": bson.M{
				"musics":           1,
				"name":             1,
				"ownerId":          1,
				"isPublic":         1,
				"playlistCoverUrl": 1,
				"createdAt":        1,
				"updatedAt":        1,
			}},
		}

		cursor, err := playlistCollection.Aggregate(ctx, pipeline)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao buscar playlist"})
			return
		}

		var results []bson.M
		if err = cursor.All(ctx, &results); err != nil || len(results) == 0 {
			c.JSON(http.StatusNotFound, gin.H{"error": "Playlist não encontrada"})
			return
		}

		c.JSON(http.StatusOK, results[0])
	}
}

func UpdatePlaylist() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		playlistId := c.Param("playlistId")
		objectId, err := primitive.ObjectIDFromHex(playlistId)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "ID inválido da playlist"})
			return
		}

		type RawUpdateData struct {
			Musics   []string `json:"musics,omitempty"`
			Name     string   `json:"name,omitempty"`
			IsPublic *bool    `json:"isPublic,omitempty"`
		}

		var rawData RawUpdateData
		if err := c.BindJSON(&rawData); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Dados inválidos: " + err.Error()})
			return
		}

		var musicIDs []primitive.ObjectID
		for _, idStr := range rawData.Musics {
			id, err := primitive.ObjectIDFromHex(idStr)
			if err != nil {
				c.JSON(http.StatusBadRequest, gin.H{"error": "ID de música inválido: " + idStr})
				return
			}
			musicIDs = append(musicIDs, id)
		}

		updateData := bson.M{
			"updatedAt": time.Now(),
		}

		if len(musicIDs) > 0 {
			updateData["musics"] = musicIDs
		}
		if rawData.Name != "" {
			updateData["name"] = rawData.Name
		}
		if rawData.IsPublic != nil {
			updateData["isPublic"] = *rawData.IsPublic
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

		userId, err := primitive.ObjectIDFromHex(claims["UserId"].(string))
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "ID de usuário inválido"})
			return
		}

		result, err := playlistCollection.UpdateOne(
			ctx,
			bson.M{
				"_id":     objectId,
				"ownerId": userId,
			},
			bson.M{"$set": updateData},
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao atualizar a playlist"})
			return
		}

		if result.MatchedCount == 0 {
			c.JSON(http.StatusNotFound, gin.H{"error": "Playlist não encontrada ou permissão negada"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Playlist atualizada com sucesso"})
	}
}

func DeletePlaylist() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		playlistId := c.Param("playlistId")
		objectId, err := primitive.ObjectIDFromHex(playlistId)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "ID inválido"})
			return
		}

		_, err = playlistCollection.DeleteOne(ctx, bson.M{"_id": objectId})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao deletar a playlist"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Playlist deletada com sucesso"})
	}
}

func GetOwnPlaylists() gin.HandlerFunc {
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

		ownerId := claims["UserId"].(string)

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		objectId, err := primitive.ObjectIDFromHex(ownerId)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "ID inválido"})
			return
		}

		serverURL := os.Getenv("SERVER_URL")

		pipeline := []bson.M{
			{"$match": bson.M{"ownerId": objectId}},
			{"$lookup": bson.M{
				"from":         "musics",
				"localField":   "musics",
				"foreignField": "_id",
				"as":           "musics",
				"pipeline": []bson.M{
					{
						"$lookup": bson.M{
							"from":         "albums",
							"localField":   "albumId",
							"foreignField": "_id",
							"as":           "album",
						},
					},
					{"$unwind": bson.M{"path": "$album", "preserveNullAndEmptyArrays": true}},
					{
						"$lookup": bson.M{
							"from":         "artists",
							"localField":   "album.artistId",
							"foreignField": "_id",
							"as":           "artist",
						},
					},
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
			{"$addFields": bson.M{
				"playlistCoverUrl": bson.M{"$concat": []interface{}{serverURL, "$playlistCoverUrl"}},
			}},
			{"$project": bson.M{
				"musics":           1,
				"name":             1,
				"ownerId":          1,
				"isPublic":         1,
				"playlistCoverUrl": 1,
				"createdAt":        1,
				"updatedAt":        1,
			}},
		}

		cursor, err := playlistCollection.Aggregate(ctx, pipeline)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao buscar playlists"})
			return
		}

		var playlists []bson.M
		if err := cursor.All(ctx, &playlists); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao processar playlists"})
			return
		}

		c.JSON(http.StatusOK, playlists)
	}
}
