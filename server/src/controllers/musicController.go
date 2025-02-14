package controllers

import (
	"bytes"
	"context"
	"encoding/binary"
	"fmt"
	"math"
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

		waveForm, err := GetWaveform("uploads/music/" + music.ID.Hex() + ".m4a")
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao gerar o waveform"})
			return
		}

		music.Waveform = waveForm
		music.Url = os.Getenv("SERVER_URL") + "/stream/" + music.ID.Hex()
		music.CreatedAt = time.Now()
		music.UpdatedAt = music.CreatedAt

		_, err = musicCollection.InsertOne(ctx, music)
		if err != nil {
			os.Remove(fmt.Sprintf("./uploads/music/%s.m4a", music.ID.Hex()))

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

	cmd := exec.Command("yt-dlp.exe", "-f", "bestaudio[ext=m4a]", "-o", outputPath, url)

	err := cmd.Run()

	return err == nil
}

func GetWaveform(audioPath string) ([]float64, error) {
	tmpfile, err := os.CreateTemp("", "audio-*.raw")
	if err != nil {
		return nil, fmt.Errorf("erro ao criar arquivo temporário: %v", err)
	}
	defer os.Remove(tmpfile.Name())
	defer tmpfile.Close()

	cmd := exec.Command(
		"ffmpeg",
		"-i", audioPath,
		"-ac", "1",
		"-ar", "44100",
		"-f", "s16le",
		"-acodec", "pcm_s16le",
		"-y",
		tmpfile.Name(),
	)

	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		return nil, fmt.Errorf("erro no ffmpeg: %v\nSaída de erro: %s", err, stderr.String())
	}

	data, err := os.ReadFile(tmpfile.Name())
	if err != nil {
		return nil, fmt.Errorf("erro ao ler arquivo PCM: %v", err)
	}

	if len(data)%2 != 0 {
		return nil, fmt.Errorf("tamanho inválido de dados PCM")
	}

	samples := make([]int16, len(data)/2)
	for i := range samples {
		samples[i] = int16(binary.LittleEndian.Uint16(data[2*i : 2*(i+1)]))
	}

	var globalMax int16 = 0
	for _, sample := range samples {
		abs := sample
		if abs < 0 {
			abs = -abs
		}
		if abs > globalMax {
			globalMax = abs
		}
	}

	if globalMax == 0 {
		return make([]float64, 70), nil
	}

	const (
		floor    = 0.1
		curve    = 2.5
		emphasis = 0.15
	)

	const numSegments = 70
	waveform := make([]float64, numSegments)
	totalSamples := len(samples)

	for i := 0; i < numSegments; i++ {
		start := (i * totalSamples) / numSegments
		end := ((i + 1) * totalSamples) / numSegments

		if start >= end {
			continue
		}

		max := int16(0)
		for _, sample := range samples[start:end] {
			abs := sample
			if abs < 0 {
				abs = -abs
			}
			if abs > max {
				max = abs
			}
		}

		normalized := float64(max) / float64(globalMax)

		compressed := math.Pow(normalized, curve)

		finalValue := (emphasis * normalized) + ((1 - emphasis) * compressed)

		if finalValue < floor {
			finalValue = 0
		} else {
			finalValue = (finalValue - floor) / (1 - floor)
		}

		waveform[i] = math.Round(finalValue*100) / 100
	}

	return waveform, nil
}
