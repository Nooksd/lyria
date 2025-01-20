package controllers

import (
	"context"
	"net/http"
	"os"
	"path/filepath"
	"time"

	database "server/src/db"
	model "server/src/models"

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
)

var artistCollection *mongo.Collection = database.OpenCollection(database.Client, "artists")

func CreateArtist() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		var artist model.Artist

		if err := c.BindJSON(&artist); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		count, err := artistCollection.CountDocuments(ctx, bson.M{"name": artist.Name})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		if count > 0 {
			c.JSON(http.StatusConflict, gin.H{"error": "artista já cadastrado"})
			return
		}

		artist.ID = primitive.NewObjectID()
		artist.CreatedAt = time.Now()
		artist.UpdatedAt = artist.CreatedAt

		if validationErr := validate.Struct(&artist); validationErr != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": validationErr.Error()})
			return
		}

		artistFolderPath := filepath.Join("uploads", "music", artist.Name)
		err = os.MkdirAll(artistFolderPath, os.ModePerm)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao criar diretório"})
			return
		}

		_, err = artistCollection.InsertOne(ctx, artist)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao criar artista"})
			return
		}

		c.JSON(http.StatusCreated, artist)
	}
}

func GetArtist() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		artistID := c.Param("artistId")
		objectID, err := primitive.ObjectIDFromHex(artistID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "ID inválido"})
			return
		}

		var artist model.Artist

		err = artistCollection.FindOne(ctx, bson.M{"_id": objectID}).Decode(&artist)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao buscar artista"})

			return
		}

		c.JSON(http.StatusOK, artist)
	}
}

func UpdateArtist() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		artistID := c.Param("artistId")
		objectID, err := primitive.ObjectIDFromHex(artistID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "ID inválido"})
			return
		}

		var updatedArtist model.Artist

		if err := c.BindJSON(&updatedArtist); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		updatedArtist.UpdatedAt = time.Now()

		update := bson.M{
			"$set": bson.M{
				"name":        updatedArtist.Name,
				"avatarUrl":   updatedArtist.AvatarUrl,
				"genres":      updatedArtist.Genres,
				"description": updatedArtist.Description,
				"updatedAt":   updatedArtist.UpdatedAt,
			},
		}

		result, err := artistCollection.UpdateOne(ctx, bson.M{"_id": objectID}, update)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao atualizar artista"})
			return
		}

		if result.MatchedCount == 0 {
			c.JSON(http.StatusNotFound, gin.H{"error": "Artista não encontrado"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Artista atualizado com sucesso"})
	}
}

func DeleteArtist() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		artistID := c.Param("artistId")

		objectID, err := primitive.ObjectIDFromHex(artistID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "ID inválido"})
			return
		}

		var artist model.Artist

		err = artistCollection.FindOne(ctx, bson.M{"_id": objectID}).Decode(&artist)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao buscar artista"})
			return
		}

		_, err = albumCollection.DeleteMany(ctx, bson.M{"artistId": objectID})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao deletar álbuns"})
			return
		}

		artistFolderPath := filepath.Join("uploads", "music", artist.Name)
		err = os.RemoveAll(artistFolderPath)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao apagar diretório"})
			return
		}

		result, err := artistCollection.DeleteOne(ctx, bson.M{"_id": objectID})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao deletar artista"})
			return
		}

		if result.DeletedCount == 0 {
			c.JSON(http.StatusNotFound, gin.H{"error": "Artista não encontrado"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Artista deletado com sucesso"})
	}
}
