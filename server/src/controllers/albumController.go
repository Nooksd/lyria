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

var albumCollection *mongo.Collection = database.OpenCollection(database.Client, "albums")

func CreateAlbum() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		var album model.Album

		if err := c.BindJSON(&album); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		count, err := albumCollection.CountDocuments(ctx, bson.M{"name": album.Name})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		if count > 0 {
			c.JSON(http.StatusConflict, gin.H{"error": "album já cadastrado"})
			return
		}

		album.ID = primitive.NewObjectID()
		album.CreatedAt = time.Now()
		album.UpdatedAt = album.CreatedAt

		if validationErr := validate.Struct(&album); validationErr != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": validationErr.Error()})
			return
		}

		artistFolderPath := filepath.Join("uploads", "music", album.ArtistName, album.Name)
		err = os.MkdirAll(artistFolderPath, os.ModePerm)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao criar diretório"})
			return
		}

		_, err = albumCollection.InsertOne(ctx, album)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao criar álbum"})
			return
		}

		c.JSON(http.StatusCreated, album)
	}
}

func GetAlbum() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		albumID := c.Param("id")
		objectID, err := primitive.ObjectIDFromHex(albumID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "ID inválido"})
			return
		}

		var album model.Album
		err = albumCollection.FindOne(ctx, bson.M{"_id": objectID}).Decode(&album)
		if err != nil {
			if err == mongo.ErrNoDocuments {
				c.JSON(http.StatusNotFound, gin.H{"error": "Álbum não encontrado"})
			} else {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao buscar álbum"})
			}
			return
		}

		c.JSON(http.StatusOK, album)
	}
}

func UpdateAlbum() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		albumID := c.Param("id")
		objectID, err := primitive.ObjectIDFromHex(albumID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "ID inválido"})
			return
		}

		var updatedAlbum model.Album
		if err := c.BindJSON(&updatedAlbum); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		updatedAlbum.UpdatedAt = time.Now()

		update := bson.M{
			"$set": bson.M{
				"name":          updatedAlbum.Name,
				"artistId":      updatedAlbum.ArtistID,
				"albumCoverUrl": updatedAlbum.AlbumCoverUrl,
				"updatedAt":     updatedAlbum.UpdatedAt,
			},
		}

		result, err := albumCollection.UpdateOne(ctx, bson.M{"_id": objectID}, update)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao atualizar álbum"})
			return
		}

		if result.MatchedCount == 0 {
			c.JSON(http.StatusNotFound, gin.H{"error": "Álbum não encontrado"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Álbum atualizado com sucesso"})
	}
}

func DeleteAlbum() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		albumID := c.Param("id")
		objectID, err := primitive.ObjectIDFromHex(albumID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "ID inválido"})
			return
		}

		result, err := albumCollection.DeleteOne(ctx, bson.M{"_id": objectID})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao deletar álbum"})
			return
		}

		if result.DeletedCount == 0 {
			c.JSON(http.StatusNotFound, gin.H{"error": "Álbum não encontrado"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Álbum deletado com sucesso"})
	}
}
