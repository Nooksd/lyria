package controllers

import (
	"context"
	"net/http"
	"os"
	"strconv"
	"time"

	model "server/src/models"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo/options"
)

func AdminLogin() gin.HandlerFunc {
	return func(c *gin.Context) {
		var loginData struct {
			Secret string `json:"secret" binding:"required"`
		}

		if err := c.ShouldBindJSON(&loginData); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Secret é obrigatório"})
			return
		}

		adminSecret := os.Getenv("ADMIN_SECRET")
		if adminSecret == "" {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Admin não configurado"})
			return
		}

		if loginData.Secret != adminSecret {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Secret inválido"})
			return
		}

		claims := jwt.MapClaims{
			"role": "admin_panel",
			"exp":  time.Now().Add(24 * time.Hour).Unix(),
			"iat":  time.Now().Unix(),
		}

		token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
		tokenString, err := token.SignedString([]byte(os.Getenv("SECRET_KEY")))
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao gerar token"})
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"token": tokenString,
		})
	}
}

func AdminAuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Token não fornecido"})
			c.Abort()
			return
		}

		token, err := jwt.Parse(authHeader, func(token *jwt.Token) (interface{}, error) {
			if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, jwt.ErrTokenMalformed
			}
			return []byte(os.Getenv("SECRET_KEY")), nil
		})

		if err != nil || !token.Valid {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Token inválido"})
			c.Abort()
			return
		}

		claims, ok := token.Claims.(jwt.MapClaims)
		if !ok {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Token inválido"})
			c.Abort()
			return
		}

		role, ok := claims["role"].(string)
		if !ok || role != "admin_panel" {
			c.JSON(http.StatusForbidden, gin.H{"error": "Acesso negado"})
			c.Abort()
			return
		}

		c.Next()
	}
}

func ListArtists() gin.HandlerFunc {
	return func(c *gin.Context) {
		page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
		limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
		if page < 1 {
			page = 1
		}
		skip := int64((page - 1) * limit)

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		opts := options.Find().SetSkip(skip).SetLimit(int64(limit)).SetSort(bson.D{{Key: "name", Value: 1}})
		cursor, err := artistCollection.Find(ctx, bson.M{}, opts)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao buscar artistas"})
			return
		}

		var artists []model.Artist
		if err := cursor.All(ctx, &artists); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao decodificar artistas"})
			return
		}

		total, _ := artistCollection.CountDocuments(ctx, bson.M{})

		c.JSON(http.StatusOK, gin.H{"artists": artists, "total": total, "page": page})
	}
}

func ListAlbums() gin.HandlerFunc {
	return func(c *gin.Context) {
		page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
		limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
		if page < 1 {
			page = 1
		}
		skip := int64((page - 1) * limit)

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		opts := options.Find().SetSkip(skip).SetLimit(int64(limit)).SetSort(bson.D{{Key: "name", Value: 1}})
		cursor, err := albumCollection.Find(ctx, bson.M{}, opts)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao buscar álbuns"})
			return
		}

		var albums []model.Album
		if err := cursor.All(ctx, &albums); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao decodificar álbuns"})
			return
		}

		total, _ := albumCollection.CountDocuments(ctx, bson.M{})

		c.JSON(http.StatusOK, gin.H{"albums": albums, "total": total, "page": page})
	}
}

func ListMusics() gin.HandlerFunc {
	return func(c *gin.Context) {
		page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
		limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
		if page < 1 {
			page = 1
		}
		skip := int64((page - 1) * limit)

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		opts := options.Find().SetSkip(skip).SetLimit(int64(limit)).SetSort(bson.D{{Key: "name", Value: 1}})
		cursor, err := musicCollection.Find(ctx, bson.M{}, opts)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao buscar músicas"})
			return
		}

		var musics []model.Music
		if err := cursor.All(ctx, &musics); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao decodificar músicas"})
			return
		}

		total, _ := musicCollection.CountDocuments(ctx, bson.M{})

		c.JSON(http.StatusOK, gin.H{"musics": musics, "total": total, "page": page})
	}
}
