package controllers

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	database "server/src/db"
	helper "server/src/helpers"
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
		if ok, _, _ := helper.CheckAdminOrUidPermission(c, ""); !ok {
			return
		}
		var music model.Music

		var ctx, cancel = context.WithTimeout(context.Background(), 100*time.Second)
		defer cancel()

		if err := c.ShouldBindJSON(&music); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Campos necessários em falta", "details": err.Error()})
			return
		}

		music.ID = primitive.NewObjectID()

		downloadResult := downloadMusic(music.Url, music.ID.Hex())
		if !downloadResult {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao baixar a música"})
			return
		}

		music.Url = ""
		music.CreatedAt = time.Now()
		music.UpdatedAt = music.CreatedAt

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
		if ok, _, _ := helper.CheckAdminOrUidPermission(c, ""); !ok {
			return
		}

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
		if ok, _, _ := helper.CheckAdminOrUidPermission(c, ""); !ok {
			return
		}

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

		err = os.Remove("./uploads/music/" + music.ID.Hex() + ".m4a")
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

func StreamMusic() gin.HandlerFunc {
	return func(c *gin.Context) {
		musicId := c.Param("musicId")

		filePath := "uploads/music/" + musicId + ".m4a"

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

func downloadMusic(url string, id string) bool {
	outputPath := fmt.Sprintf("./uploads/music/%s.%%(ext)s", id)

	cmd := exec.Command("./cmd/yt-dlp.exe", "-f", "bestaudio[ext=m4a]", "-o", outputPath, url)

	err := cmd.Run()

	return err == nil
}
