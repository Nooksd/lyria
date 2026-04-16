package controllers

import (
	"io"
	"net/http"
	"os"
	"path/filepath"
	"time"

	"github.com/gin-gonic/gin"
)

const cookiesFilePath = "/opt/lyria/server/cookies.txt"

// GetCookies returns the current cookies.txt content and metadata
func GetCookies() gin.HandlerFunc {
	return func(c *gin.Context) {
		info, err := os.Stat(cookiesFilePath)
		if err != nil {
			if os.IsNotExist(err) {
				c.JSON(http.StatusOK, gin.H{
					"exists":  false,
					"content": "",
					"size":    0,
				})
				return
			}
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao verificar arquivo: " + err.Error()})
			return
		}

		content, err := os.ReadFile(cookiesFilePath)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao ler arquivo: " + err.Error()})
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"exists":     true,
			"content":    string(content),
			"size":       info.Size(),
			"modifiedAt": info.ModTime().Format(time.RFC3339),
		})
	}
}

// UploadCookies replaces the cookies.txt file with uploaded content
func UploadCookies() gin.HandlerFunc {
	return func(c *gin.Context) {
		// Try multipart file upload first
		file, _, err := c.Request.FormFile("file")
		if err == nil {
			defer file.Close()
			content, err := io.ReadAll(file)
			if err != nil {
				c.JSON(http.StatusBadRequest, gin.H{"error": "Erro ao ler arquivo enviado"})
				return
			}
			if err := writeCookiesFile(content); err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
				return
			}
			c.JSON(http.StatusOK, gin.H{"message": "Cookies atualizados com sucesso", "size": len(content)})
			return
		}

		// Fallback: JSON body with content field
		var body struct {
			Content string `json:"content" binding:"required"`
		}
		if err := c.ShouldBindJSON(&body); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Envie o arquivo ou o conteúdo dos cookies"})
			return
		}
		if err := writeCookiesFile([]byte(body.Content)); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusOK, gin.H{"message": "Cookies atualizados com sucesso", "size": len(body.Content)})
	}
}

// DeleteCookies removes the cookies.txt file
func DeleteCookies() gin.HandlerFunc {
	return func(c *gin.Context) {
		if _, err := os.Stat(cookiesFilePath); os.IsNotExist(err) {
			c.JSON(http.StatusOK, gin.H{"message": "Arquivo já não existe"})
			return
		}
		if err := os.Remove(cookiesFilePath); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao remover arquivo: " + err.Error()})
			return
		}
		c.JSON(http.StatusOK, gin.H{"message": "Cookies removidos com sucesso"})
	}
}

func writeCookiesFile(content []byte) error {
	dir := filepath.Dir(cookiesFilePath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return err
	}
	return os.WriteFile(cookiesFilePath, content, 0644)
}
