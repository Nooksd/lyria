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
		targetUserId := c.Param("userId")

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

		userType := claims["UserType"].(string)
		userId := claims["Uid"].(string)

		if userType != "ADMIN" && userId != targetUserId {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Você não tem permissão para atualizar este usuário"})
			return
		}

		err := c.Request.ParseMultipartForm(10 << 20)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Erro ao processar o arquivo"})
			return
		}

		file, _, err := c.Request.FormFile("avatar")
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Nenhum arquivo enviado"})
			return
		}
		defer file.Close()

		filename := fmt.Sprintf("%s.png", targetUserId)

		filePath := filepath.Join("uploads", "avatar", filename)

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

		c.JSON(http.StatusOK, gin.H{"message": "Avatar enviado com sucesso!", "url": "http://192.168.1.68:9000/avatar/get/" + filename})
	}
}

func GetAvatar() gin.HandlerFunc {
	return func(c *gin.Context) {
		userId := c.Param("userId")
		filename := fmt.Sprintf("%s.png", userId)

		filePath := filepath.Join("uploads", "avatar", filename)

		if _, err := os.Stat(filePath); os.IsNotExist(err) {
			filePath := filepath.Join("uploads", "avatar", "default.png")

			c.File(filePath)
			return
		}

		c.File(filePath)
	}
}
