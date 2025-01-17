package controllers

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"
)

func DownloadAudio() gin.HandlerFunc {
	return func(c *gin.Context) {
		var request struct {
			URL string `json:"url" binding:"required"`
		}
		if err := c.ShouldBindJSON(&request); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "URL is required"})
			return
		}

		uploadDir := "./uploads/music"
		if _, err := os.Stat(uploadDir); os.IsNotExist(err) {
			err = os.MkdirAll(uploadDir, os.ModePerm)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create directory"})
				return
			}
		}

		outputPath := fmt.Sprintf("%s/%%(title)s.%%(ext)s", uploadDir)

		cmd := exec.Command("yt-dlp", "-f", "bestaudio[ext=m4a]", "-o", outputPath, request.URL)

		err := cmd.Run()
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Failed to download audio: %v", err)})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Audio downloaded successfully!"})
	}
}

func StreamAudio() gin.HandlerFunc {
	return func(c *gin.Context) {
		fileName := c.Param("fileName")
		filePath := fmt.Sprintf("./uploads/music/%s", fileName)

		file, err := os.Open(filePath)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "File not found"})
			return
		}
		defer file.Close()

		fileInfo, err := file.Stat()
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Unable to get file info"})
			return
		}

		rangeHeader := c.GetHeader("Range")
		if rangeHeader == "" {
			// Não há requisição de range, envie o arquivo completo
			c.Header("Content-Type", "audio/m4a")
			c.File(filePath)
			return
		}

		// Processa o cabeçalho "Range"
		rangeParts := strings.Split(strings.TrimPrefix(rangeHeader, "bytes="), "-")
		start, err := strconv.Atoi(rangeParts[0])
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid range"})
			return
		}

		var end int
		if len(rangeParts) > 1 && rangeParts[1] != "" {
			end, err = strconv.Atoi(rangeParts[1])
			if err != nil {
				c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid range"})
				return
			}
		} else {
			// Se o "end" não for fornecido, faz-se até o final do arquivo
			end = int(fileInfo.Size()) - 1
		}

		// Verifica se o intervalo solicitado está correto
		if start > int(fileInfo.Size()) || end > int(fileInfo.Size()) {
			c.JSON(http.StatusRequestedRangeNotSatisfiable, gin.H{"error": "Range not satisfiable"})
			return
		}

		contentRange := fmt.Sprintf("bytes %d-%d/%d", start, end, fileInfo.Size())
		c.Header("Content-Type", "audio/m4a")
		c.Header("Content-Range", contentRange)
		c.Header("Content-Length", strconv.Itoa(end-start+1))

		file.Seek(int64(start), io.SeekStart)

		_, err = io.CopyN(c.Writer, file, int64(end-start+1))
		if err != nil && err != io.EOF {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Error streaming file"})
			return
		}
	}
}
