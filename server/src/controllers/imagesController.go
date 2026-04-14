package controllers

import (
	"fmt"
	"net/http"
	"os"
	"path/filepath"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
)

func UploadAvatar() gin.HandlerFunc {
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

		userId := claims["UserId"].(string)
		handleFileUpload(c, userId, "avatar", "png")
	}
}

func UploadCover() gin.HandlerFunc {
	return func(c *gin.Context) {
		albumId := c.Param("albumId")
		if albumId == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "ID não fornecido"})
			return
		}

		handleFileUpload(c, albumId, "cover", "png")
	}
}

func UploadPlaylistCover() gin.HandlerFunc {
	return func(c *gin.Context) {
		playlistId := c.Param("playlistId")
		if playlistId == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "ID não fornecido"})
			return
		}

		handleFileUpload(c, playlistId, "playlist", "png")
	}
}

func GetAvatar() gin.HandlerFunc {
	return func(c *gin.Context) {
		getImage(c, "avatar")
	}
}

func GetCover() gin.HandlerFunc {
	return func(c *gin.Context) {
		getImage(c, "cover")
	}
}

func GetPlaylistCover() gin.HandlerFunc {
	return func(c *gin.Context) {
		getImage(c, "playlist")
	}
}

func UploadArtistAvatar() gin.HandlerFunc {
	return func(c *gin.Context) {
		artistId := c.Param("artistId")
		if artistId == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "ID não fornecido"})
			return
		}

		handleFileUpload(c, artistId, "avatar", "png")
	}
}

func UploadArtistBanner() gin.HandlerFunc {
	return func(c *gin.Context) {
		artistId := c.Param("artistId")
		if artistId == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "ID não fornecido"})
			return
		}

		handleFileUpload(c, artistId, "banner", "png")
	}
}

func GetBanner() gin.HandlerFunc {
	return func(c *gin.Context) {
		getImage(c, "banner")
	}
}

func handleFileUpload(c *gin.Context, id string, subDir string, fileExtension string) {
	err := c.Request.ParseMultipartForm(10 << 20)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Erro ao processar o arquivo"})
		return
	}

	file, _, err := c.Request.FormFile(subDir)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Nenhum arquivo enviado"})
		return
	}
	defer file.Close()

	filename := fmt.Sprintf("%s.%s", id, fileExtension)
	filePath := filepath.Join("uploads", "image", subDir, filename)

	err = os.MkdirAll(filepath.Dir(filePath), os.ModePerm)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao criar diretório"})
		return
	}

	dst, err := os.Create(filePath)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao salvar o arquivo"})
		return
	}
	defer dst.Close()

	_, err = dst.ReadFrom(file)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao escrever o arquivo"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Arquivo enviado com sucesso!", "filePath": filePath})
}

func getImage(c *gin.Context, subDir string) {
	id := c.Param("id")
	filename := fmt.Sprintf("%s.png", id)
	filePath := filepath.Join("uploads", "image", subDir, filename)

	if _, err := os.Stat(filePath); os.IsNotExist(err) {
		filePath = filepath.Join("uploads", "image", subDir, "default.png")
	}

	fileInfo, err := os.Stat(filePath)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Imagem não encontrada"})
		return
	}

	etag := fmt.Sprintf("%s-%d", id, fileInfo.ModTime().Unix())

	if match := c.GetHeader("If-None-Match"); match == etag {
		c.Status(http.StatusNotModified)
		return
	}

	c.Header("Cache-Control", "public, max-age=60, must-revalidate")
	c.Header("ETag", etag)
	c.File(filePath)
}
