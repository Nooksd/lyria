package controllers

import (
	"context"
	"net/http"
	"time"

	database "server/src/db"
	helper "server/src/helpers"
	model "server/src/models"

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

var artistCollection *mongo.Collection = database.OpenCollection(database.Client, "artists")

func CreateArtist() gin.HandlerFunc {
	return func(c *gin.Context) {
		if ok, _, _ := helper.CheckAdminOrUidPermission(c, ""); !ok {
			return
		}

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
		artist.AvatarUrl = "http://192.168.1.68:9000/avatar/" + artist.ID.Hex()
		artist.UpdatedAt = artist.CreatedAt

		if validationErr := validate.Struct(&artist); validationErr != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": validationErr.Error()})
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
			c.JSON(http.StatusNotFound, gin.H{"error": "Artista não encontrado"})
			return
		}

		var albums []model.Album

		albumCursor, err := albumCollection.Find(ctx, bson.M{"artistId": objectID})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao buscar álbuns"})
			return
		}
		if err := albumCursor.All(ctx, &albums); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao processar álbuns"})
			return
		}

		var musics []model.Music

		musicCursor, err := musicCollection.Find(
			ctx,
			bson.M{"artistId": objectID},
			options.Find().SetSort(bson.M{"createdAt": -1}).SetLimit(5),
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao buscar músicas"})
			return
		}
		if err := musicCursor.All(ctx, &musics); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao processar músicas"})
			return
		}

		response := gin.H{
			"artist": artist,
			"albums": albums,
			"musics": musics,
		}

		c.JSON(http.StatusOK, response)
	}
}

func UpdateArtist() gin.HandlerFunc {
	return func(c *gin.Context) {
		if ok, _, _ := helper.CheckAdminOrUidPermission(c, ""); !ok {
			return
		}

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		artistID := c.Param("artistId")
		objectID, err := primitive.ObjectIDFromHex(artistID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "ID inválido"})
			return
		}

		var updateData model.Artist

		if err := c.ShouldBindJSON(&updateData); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		var currentArtist model.Artist

		err = artistCollection.FindOne(ctx, bson.M{"_id": objectID}).Decode(&currentArtist)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Artista não encontrado"})
			return
		}

		if updateData.Name != "" {
			currentArtist.Name = updateData.Name
		}
		if len(updateData.Genres) > 0 {
			currentArtist.Genres = updateData.Genres
		}
		if updateData.AvatarUrl != "" {
			currentArtist.AvatarUrl = updateData.AvatarUrl
		}

		currentArtist.UpdatedAt = time.Now()

		_, err = artistCollection.ReplaceOne(ctx, bson.M{"_id": objectID}, currentArtist)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao atualizar artista"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Artista atualizado com sucesso"})
	}
}

func DeleteArtist() gin.HandlerFunc {
	return func(c *gin.Context) {
		if ok, _, _ := helper.CheckAdminOrUidPermission(c, ""); !ok {
			return
		}

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
