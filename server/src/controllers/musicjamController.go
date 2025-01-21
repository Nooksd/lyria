package controllers

import (
	"context"
	"math/rand"
	"net/http"
	database "server/src/db"
	model "server/src/models"
	websocketmanager "server/src/websocket"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/gorilla/websocket"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
)

var musicJamCollection *mongo.Collection = database.OpenCollection(database.Client, "jams")

func generateSimpleID() string {
	const charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	rand.New(rand.NewSource(time.Now().UnixNano()))
	b := make([]byte, 5)
	for i := range b {
		b[i] = charset[rand.Intn(len(charset))]
	}
	return strings.ToLower(string(b))
}

func CreateMusicJam() gin.HandlerFunc {
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
		userName := claims["Name"].(string)
		userAvatar := claims["AvatarUrl"].(string)

		ownerID, err := primitive.ObjectIDFromHex(userId)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "ID inválido"})
			return
		}

		simpleID := generateSimpleID()

		musicJam := model.MusicJam{
			ID:       primitive.NewObjectID(),
			SimpleID: simpleID,
			OwnerID:  ownerID,
			Participants: []model.Participant{
				{
					ID:        ownerID,
					Name:      userName,
					AvatarUrl: userAvatar,
				},
			},
			Queue:     []primitive.ObjectID{},
			Playing:   false,
			TimeNow:   0,
			CreatedAt: time.Now(),
			UpdatedAt: time.Now(),
		}

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		_, err = musicJamCollection.InsertOne(ctx, musicJam)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao criar Music Jam"})
			return
		}

		c.JSON(http.StatusCreated, gin.H{"message": "Music Jam criada com sucesso", "details": musicJam})
	}
}

func JoinMusicJam() gin.HandlerFunc {
	return func(c *gin.Context) {
		simpleId := c.Param("simpleId")

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
		userName := claims["Name"].(string)
		userAvatar := claims["AvatarUrl"].(string)

		userObjectID, err := primitive.ObjectIDFromHex(userId)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "ID inválido"})
			return
		}

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		filter := bson.M{"simpleId": simpleId}
		update := bson.M{
			"$addToSet": bson.M{
				"participants": model.Participant{
					ID:        userObjectID,
					Name:      userName,
					AvatarUrl: userAvatar,
				},
			},
			"$set": bson.M{"updatedAt": time.Now()},
		}

		result := musicJamCollection.FindOneAndUpdate(ctx, filter, update)
		if result.Err() != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Music Jam não encontrada"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Entrou na Music Jam com sucesso", "details": result})
	}
}

func LeaveMusicJam() gin.HandlerFunc {
	return func(c *gin.Context) {
		simpleId := c.Param("simpleId")

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

		userObjectID, err := primitive.ObjectIDFromHex(userId)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "ID inválido"})
			return
		}

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		filter := bson.M{"simpleId": simpleId}
		update := bson.M{
			"$pull": bson.M{"participants": bson.M{"id": userObjectID}},
			"$set":  bson.M{"updatedAt": time.Now()},
		}

		result := musicJamCollection.FindOneAndUpdate(ctx, filter, update)
		if result.Err() != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Music Jam não encontrada"})
			return
		}

		var musicJam model.MusicJam
		musicJamCollection.FindOne(ctx, filter).Decode(&musicJam)
		if len(musicJam.Participants) == 0 {
			musicJamCollection.DeleteOne(ctx, filter)
		}

		c.JSON(http.StatusOK, gin.H{"message": "Saiu da Music Jam com sucesso"})
	}
}

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}

func MusicJamWebSocket() gin.HandlerFunc {
	return func(c *gin.Context) {
		simpleID := c.Param("simpleId")
		userID := c.Query("userId")

		conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Falha ao criar conexão WebSocket"})
			return
		}

		client := &websocketmanager.Client{
			Conn:     conn,
			Send:     make(chan []byte),
			UserID:   userID,
			SimpleID: simpleID,
		}

		websocketmanager.ManagerInstance.Register <- client

		go client.ReadPump()
		go client.WritePump()
	}
}
