package controllers

import (
	"context"
	"net/http"
	"os"
	"time"

	database "server/src/db"
	helper "server/src/helpers"
	model "server/src/models"

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
)

var albumCollection *mongo.Collection = database.OpenCollection(database.Client, "albums")

func CreateAlbum() gin.HandlerFunc {
	return func(c *gin.Context) {
		if ok, _, _ := helper.CheckAdminOrUidPermission(c, ""); !ok {
			return
		}

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		var album model.Album

		if err := c.BindJSON(&album); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		count, err := albumCollection.CountDocuments(ctx, bson.M{"name": album.Name, "artistId": album.ArtistID})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		if count > 0 {
			c.JSON(http.StatusConflict, gin.H{"error": "album já cadastrado"})
			return
		}

		album.ID = primitive.NewObjectID()
		album.AlbumCoverUrl = os.Getenv("SERVER_URL") + "/image/cover/" + album.ID.Hex()
		album.CreatedAt = time.Now()
		album.UpdatedAt = album.CreatedAt

		if validationErr := validate.Struct(&album); validationErr != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": validationErr.Error()})
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

		albumID := c.Param("albumId")
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

		var musics []model.Music
		cursor, err := musicCollection.Find(ctx, bson.M{"albumId": objectID})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao buscar músicas"})
			return
		}
		if err := cursor.All(ctx, &musics); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao processar músicas"})
			return
		}

		response := gin.H{
			"album":  album,
			"musics": musics,
		}

		c.JSON(http.StatusOK, response)
	}
}

func UpdateAlbum() gin.HandlerFunc {
	return func(c *gin.Context) {
		if ok, _, _ := helper.CheckAdminOrUidPermission(c, ""); !ok {
			return
		}

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		albumID := c.Param("albumId")

		objectID, err := primitive.ObjectIDFromHex(albumID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "ID inválido"})
			return
		}

		var updateData model.Album

		if err := c.ShouldBindJSON(&updateData); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		var currentAlbum model.Album

		err = albumCollection.FindOne(ctx, bson.M{"_id": objectID}).Decode(&currentAlbum)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Álbum não encontrado"})
			return
		}

		if updateData.Name != "" {
			currentAlbum.Name = updateData.Name
		}
		if !updateData.ArtistID.IsZero() {
			currentAlbum.ArtistID = updateData.ArtistID
		}
		if updateData.AlbumCoverUrl != "" {
			currentAlbum.AlbumCoverUrl = updateData.AlbumCoverUrl
		}

		currentAlbum.UpdatedAt = time.Now()

		_, err = albumCollection.ReplaceOne(ctx, bson.M{"_id": objectID}, currentAlbum)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao atualizar álbum"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Álbum atualizado com sucesso"})
	}
}

func DeleteAlbum() gin.HandlerFunc {
	return func(c *gin.Context) {
		if ok, _, _ := helper.CheckAdminOrUidPermission(c, ""); !ok {
			return
		}

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		albumID := c.Param("albumId")

		objectID, err := primitive.ObjectIDFromHex(albumID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "ID inválido"})
			return
		}

		var album model.Album

		err = artistCollection.FindOne(ctx, bson.M{"_id": objectID}).Decode(&album)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao buscar artista"})
			return
		}

		_, err = musicCollection.DeleteMany(ctx, bson.M{"albumId": objectID})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao deletar álbuns"})
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
