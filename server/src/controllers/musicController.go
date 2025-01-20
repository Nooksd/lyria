package controllers

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	database "server/src/db"
	model "server/src/models"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
)

var musicCollection *mongo.Collection = database.OpenCollection(database.Client, "musics")

func CreateMusic() gin.HandlerFunc {
	return func(c *gin.Context) {
		var request struct {
			Url        string   `json:"url" binding:"required"`
			Name       string   `json:"name" binding:"required"`
			ArtistID   string   `json:"artistId" binding:"required"`
			ArtistName string   `json:"artistName" binding:"required"`
			AlbumID    string   `json:"albumId" binding:"required"`
			AlbumName  string   `json:"albumName" binding:"required"`
			Genre      []string `json:"genre"`
		}

		var ctx, cancel = context.WithTimeout(context.Background(), 100*time.Second)
		defer cancel()

		if err := c.ShouldBindJSON(&request); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Campos necessários em falta", "details": err.Error()})
			return
		}

		uploadDir := "./uploads/music/" + request.ArtistName + "/" + request.AlbumName
		if _, err := os.Stat(uploadDir); os.IsNotExist(err) {
			c.JSON(http.StatusBadRequest, gin.H{"error": "A pasta do álbum não existe"})
			return
		}

		music := model.Music{
			ID:         primitive.NewObjectID(),
			Name:       request.Name,
			ArtistID:   primitive.NilObjectID,
			ArtistName: request.ArtistName,
			AlbumID:    primitive.NilObjectID,
			AlbumName:  request.AlbumName,
			Genre:      strings.Join(request.Genre, ", "),
			AudioPath:  "",
			CreatedAt:  time.Now(),
			UpdatedAt:  time.Now(),
		}

		downloadResult := downloadMusic(request.Url, request.Name, uploadDir)
		if !downloadResult {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao baixar a música"})
			return
		}

		music.AudioPath = request.ArtistName + "/" + request.AlbumName + "/" + request.Name

		_, err := musicCollection.InsertOne(ctx, music)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao salvar no banco de dados"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Música criada com sucesso", "music": music})
	}
}

func UpdateMusic() gin.HandlerFunc {
	return func(c *gin.Context) {
		musicId := c.Param("musicId")

		id, err := primitive.ObjectIDFromHex(musicId)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "ID inválido"})
			return
		}

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		var updateData model.Music

		if err := c.ShouldBindJSON(&updateData); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Dados inválidos"})
			return
		}

		updateData.UpdatedAt = time.Now()

		_, err = musicCollection.UpdateOne(
			ctx,
			bson.M{"_id": id},
			bson.M{"$set": updateData},
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao atualizar a música"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Música atualizada com sucesso"})
	}
}

func DeleteMusic() gin.HandlerFunc {
	return func(c *gin.Context) {
		musicId := c.Param("musicId")

		id, err := primitive.ObjectIDFromHex(musicId)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "ID inválido"})
			return
		}

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		var music model.Music

		err = musicCollection.FindOne(ctx, bson.M{"_id": id}).Decode(&music)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Música não encontrada"})
			return
		}

		err = os.Remove("./uploads/music/" + music.AudioPath)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao deletar o arquivo"})
			return
		}

		_, err = musicCollection.DeleteOne(ctx, bson.M{"_id": id})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao remover a música do banco"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Música removida com sucesso"})
	}
}

func GetAllMusics() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		var musics []model.Music
		cursor, err := musicCollection.Find(ctx, bson.M{})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao buscar músicas"})
			return
		}
		defer cursor.Close(ctx)

		if err = cursor.All(ctx, &musics); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao decodificar músicas"})
			return
		}

		c.JSON(http.StatusOK, musics)
	}
}

func StreamMusic() gin.HandlerFunc {
	return func(c *gin.Context) {
		artistName := c.Param("artistName")
		albumName := c.Param("albumName")
		musicName := c.Param("musicName")

		filePath := "uploads/music/" + artistName + "/" + albumName + "/" + musicName + ".m4a"

		file, err := os.Open(filePath)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "File not found"})
			return
		}
		defer file.Close()

		fileStat, _ := file.Stat()
		fileSize := fileStat.Size()

		rangeHeader := c.GetHeader("Range")
		if rangeHeader == "" {
			c.Header("Content-Length", strconv.FormatInt(fileSize, 10))
			c.Header("Content-Type", "audio/mp4")
			c.File(filePath)
			return
		}

		rangeParts := strings.Split(strings.TrimPrefix(rangeHeader, "bytes="), "-")
		start, _ := strconv.ParseInt(rangeParts[0], 10, 64)
		end := fileSize - 1
		if len(rangeParts) > 1 && rangeParts[1] != "" {
			end, _ = strconv.ParseInt(rangeParts[1], 10, 64)
		}

		if start > end || start < 0 || end >= fileSize {
			c.Status(http.StatusRequestedRangeNotSatisfiable)
			return
		}

		chunkSize := end - start + 1
		c.Header("Content-Range", "bytes "+strconv.FormatInt(start, 10)+"-"+strconv.FormatInt(end, 10)+"/"+strconv.FormatInt(fileSize, 10))
		c.Header("Accept-Ranges", "bytes")
		c.Header("Content-Length", strconv.FormatInt(chunkSize, 10))
		c.Header("Content-Type", "audio/mp4")
		c.Status(http.StatusPartialContent)

		file.Seek(start, 0)
		buffer := make([]byte, chunkSize)
		file.Read(buffer)
		c.Writer.Write(buffer)

	}
}

func downloadMusic(url string, name string, uploadDir string) bool {
	if _, err := os.Stat(uploadDir); os.IsNotExist(err) {
		err = os.MkdirAll(uploadDir, os.ModePerm)
		if err != nil {
			return false
		}
	}

	outputPath := fmt.Sprintf("%s/%s.%%(ext)s", uploadDir, name)

	cmd := exec.Command("yt-dlp", "-f", "bestaudio[ext=m4a]", "-o", outputPath, url)

	err := cmd.Run()

	return err == nil
}
