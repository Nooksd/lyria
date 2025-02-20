package controllers

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"strings"
	"time"

	helper "server/src/helpers"
	model "server/src/models"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"go.mongodb.org/mongo-driver/bson"
	"golang.org/x/crypto/bcrypt"
)

func VerifyPassword(providedPassword string, storedHash string) error {
	err := bcrypt.CompareHashAndPassword([]byte(storedHash), []byte(providedPassword))
	if err != nil {
		return fmt.Errorf("email ou senha incorretos")
	}
	return nil
}

func LoginUser() gin.HandlerFunc {
	return func(c *gin.Context) {
		var loginData struct {
			Email        string `json:"email"`
			Password     string `json:"password"`
			KeepLoggedIn bool   `json:"keepConnection"`
		}

		if err := c.ShouldBindJSON(&loginData); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"message": "Todos os campos são obrigatórios", "status": false})
			return
		}

		var user model.User

		err := userCollection.FindOne(context.Background(), bson.M{"email": loginData.Email}).Decode(&user)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"message": "Email ou senha inválidos 1", "status": false})
			return
		}

		err = VerifyPassword(loginData.Password, user.Password)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"message": "Email ou senha inválidos 2", "status": false})
			return
		}

		accessToken, refreshToken, _ := helper.GenerateTokens(user.Email, user.Name, user.AvatarUrl, user.Uid, user.UserType, true)

		http.SetCookie(c.Writer, &http.Cookie{
			Name:     "accessToken",
			Value:    accessToken,
			Path:     "/",
			Domain:   os.Getenv("DOMAIN"),
			Expires:  time.Now().Add(24 * time.Hour),
			HttpOnly: true,
			Secure:   os.Getenv("ENVIRONMENT") == "production",
			SameSite: http.SameSiteNoneMode,
		})

		if loginData.KeepLoggedIn {
			http.SetCookie(c.Writer, &http.Cookie{
				Name:     "refreshToken",
				Value:    refreshToken,
				Path:     "/",
				Domain:   os.Getenv("DOMAIN"),
				Expires:  time.Now().Add(7 * 24 * time.Hour),
				HttpOnly: true,
				Secure:   os.Getenv("ENVIRONMENT") == "production",
				SameSite: http.SameSiteNoneMode,
			})
		}

		userCopy := user
		userCopy.Password = ""
		userCopy.Email = strings.Split(user.Email, "@")[0][:5] + "****" + "@" + strings.Split(user.Email, "@")[1]
		userCopy.AvatarUrl = os.Getenv("SERVER_URL") + userCopy.AvatarUrl

		c.JSON(http.StatusOK, gin.H{
			"accessToken":  accessToken,
			"refreshToken": refreshToken,
			"user":         userCopy,
			"type":         user.UserType,
		})
	}
}

func RefreshToken() gin.HandlerFunc {
	return func(c *gin.Context) {
		refreshToken := c.GetHeader("Authorization")
		if refreshToken == "" {
			refreshToken, _ = c.Cookie("refreshToken")
			if refreshToken == "" {
				c.JSON(http.StatusBadRequest, gin.H{"error": "Token não fornecido"})
				return
			}
		}

		token, err := jwt.Parse(refreshToken, func(token *jwt.Token) (interface{}, error) {
			return []byte(os.Getenv("SECRET_KEY")), nil
		})
		if err != nil || !token.Valid {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Token inválido"})
			return
		}

		claims, ok := token.Claims.(jwt.MapClaims)
		if !ok {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao processar token"})
			return
		}

		email := claims["Email"].(string)
		name := claims["Name"].(string)
		avatarUrl := claims["AvatarUrl"].(string)
		userType := claims["UserType"].(string)
		userId := claims["Uid"].(string)

		newAccessToken, _, err := helper.GenerateTokens(email, name, avatarUrl, userId, userType, false)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao gerar novo token"})
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"accessToken": newAccessToken,
		})
	}
}

func LogoutUser() gin.HandlerFunc {
	return func(c *gin.Context) {
		http.SetCookie(c.Writer, &http.Cookie{
			Name:     "accessToken",
			Value:    "",
			Path:     "/",
			Domain:   os.Getenv("DOMAIN"),
			Expires:  time.Now(),
			HttpOnly: true,
			Secure:   os.Getenv("ENVIRONMENT") == "production",
			SameSite: http.SameSiteNoneMode,
		})

		http.SetCookie(c.Writer, &http.Cookie{
			Name:     "refreshToken",
			Value:    "",
			Path:     "/",
			Domain:   os.Getenv("DOMAIN"),
			Expires:  time.Now(),
			HttpOnly: true,
			Secure:   os.Getenv("ENVIRONMENT") == "production",
			SameSite: http.SameSiteNoneMode,
		})

		c.JSON(http.StatusOK, gin.H{"message": "Sessão encerrada com sucesso"})
	}
}
