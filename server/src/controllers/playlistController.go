package controllers

import (
	"context"
	"net/http"
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

		userId := claims["Uid"].(string)

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
		playlist.PlaylistCoverUrl = "http://192.168.1.68:9000/cover/" + playlist.ID.Hex()
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

		c.JSON(http.StatusCreated, gin.H{"message": "Playlist criada com sucesso", "playlist": playlist})
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

		var playlist model.Playlist

		err = playlistCollection.FindOne(ctx, bson.M{"_id": objectId}).Decode(&playlist)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Playlist não encontrada"})
			return
		}

		aggregatePipeline := []bson.M{
			{
				"$match": bson.M{"_id": bson.M{"$in": playlist.Musics}},
			},
			{
				"$project": bson.M{
					"_id":           1,
					"artistId":      1,
					"albumId":       1,
					"genre":         1,
					"numOfSaves":    1,
					"audioFileName": 1,
				},
			},
		}

		cursor, err := musicCollection.Aggregate(ctx, aggregatePipeline)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao buscar músicas"})
			return
		}

		var musics []model.Music

		if err := cursor.All(ctx, &musics); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao processar músicas"})
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"playlist": playlist,
			"musics":   musics,
		})
	}
}

func UpdatePlaylist() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		playlistId := c.Param("playlistId")

		objectId, err := primitive.ObjectIDFromHex(playlistId)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "ID inválido"})
			return
		}

		var updateData bson.M

		if err := c.BindJSON(&updateData); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Dados inválidos"})
			return
		}

		updateData["updatedAt"] = time.Now()

		_, err = playlistCollection.UpdateOne(ctx, bson.M{"_id": objectId}, bson.M{"$set": updateData})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao atualizar a playlist"})
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

		ownerId := claims["Uid"].(string)

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		objectId, err := primitive.ObjectIDFromHex(ownerId)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "ID inválido"})
			return
		}

		var playlists []model.Playlist

		cursor, err := playlistCollection.Find(ctx, bson.M{"ownerId": objectId})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao buscar playlists"})
			return
		}
		if err := cursor.All(ctx, &playlists); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao processar playlists"})
			return
		}

		c.JSON(http.StatusOK, playlists)
	}
}
