package controllers

import (
	"context"
	"encoding/json"
	"log"
	"math/rand"
	"net/http"
	"os"
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
	"go.mongodb.org/mongo-driver/mongo/options"
)

var musicJamCollection *mongo.Collection = database.OpenCollection(database.Client, "jams")

func resolveAvatarUrl(avatarUrl string) string {
	if strings.HasPrefix(avatarUrl, "/") {
		return os.Getenv("SERVER_URL") + avatarUrl
	}
	return avatarUrl
}

type WSMessage struct {
	Type    string          `json:"type"`
	Payload json.RawMessage `json:"payload"`
}

type PlayPayload struct {
	MusicId  string  `json:"musicId"`
	Position float64 `json:"position"`
}

type SeekPayload struct {
	Position float64 `json:"position"`
}

type QueuePayload struct {
	MusicId string `json:"musicId"`
}

type SyncPayload struct {
	MusicId      string              `json:"musicId"`
	Playing      bool                `json:"playing"`
	Position     float64             `json:"position"`
	Queue        []string            `json:"queue"`
	Participants []model.Participant `json:"participants"`
}

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
		userAvatar := resolveAvatarUrl(claims["AvatarUrl"].(string))

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

func GetMusicJam() gin.HandlerFunc {
	return func(c *gin.Context) {
		simpleId := c.Param("simpleId")

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		var jam model.MusicJam
		err := musicJamCollection.FindOne(ctx, bson.M{"simpleId": simpleId}).Decode(&jam)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Music Jam não encontrada"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"details": jam})
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
		userAvatar := resolveAvatarUrl(claims["AvatarUrl"].(string))

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

		opts := options.FindOneAndUpdate().SetReturnDocument(options.After)
		var updatedJam model.MusicJam
		err = musicJamCollection.FindOneAndUpdate(ctx, filter, update, opts).Decode(&updatedJam)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Music Jam não encontrada"})
			return
		}

		joinMsg, _ := json.Marshal(gin.H{
			"type": "user_joined",
			"payload": gin.H{
				"userId":       userId,
				"name":         userName,
				"avatarUrl":    userAvatar,
				"participants": updatedJam.Participants,
			},
		})
		websocketmanager.BroadcastToRoomAll(simpleId, joinMsg)

		c.JSON(http.StatusOK, gin.H{"message": "Entrou na Music Jam com sucesso", "details": updatedJam})
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
		} else {
			leaveMsg, _ := json.Marshal(gin.H{
				"type": "user_left",
				"payload": gin.H{
					"userId":       userId,
					"participants": musicJam.Participants,
				},
			})
			websocketmanager.BroadcastToRoomAll(simpleId, leaveMsg)
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
		userID := claims["UserId"].(string)

		conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Falha ao criar conexão WebSocket"})
			return
		}

		client := &websocketmanager.Client{
			Conn:     conn,
			Send:     make(chan []byte, 256),
			UserID:   userID,
			SimpleID: simpleID,
		}

		websocketmanager.ManagerInstance.Register <- client

		go client.ReadPump(handleJamMessage)
		go client.WritePump()

		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		var jam model.MusicJam
		err = musicJamCollection.FindOne(ctx, bson.M{"simpleId": simpleID}).Decode(&jam)
		if err == nil {
			queueStrs := make([]string, len(jam.Queue))
			for i, id := range jam.Queue {
				queueStrs[i] = id.Hex()
			}
			musicId := ""
			if jam.CurrentMusicId != nil {
				musicId = jam.CurrentMusicId.Hex()
			}
			syncMsg, _ := json.Marshal(gin.H{
				"type": "sync",
				"payload": SyncPayload{
					MusicId:      musicId,
					Playing:      jam.Playing,
					Position:     jam.TimeNow,
					Queue:        queueStrs,
					Participants: jam.Participants,
				},
			})
			client.Send <- syncMsg
		}
	}
}

func handleJamMessage(client *websocketmanager.Client, message []byte) {
	var msg WSMessage
	if err := json.Unmarshal(message, &msg); err != nil {
		log.Printf("Erro ao parsear mensagem WS: %v", err)
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	filter := bson.M{"simpleId": client.SimpleID}

	switch msg.Type {
	case "play":
		var payload PlayPayload
		if err := json.Unmarshal(msg.Payload, &payload); err != nil {
			return
		}

		update := bson.M{"$set": bson.M{
			"playing":   true,
			"timeNow":   payload.Position,
			"updatedAt": time.Now(),
		}}

		if payload.MusicId != "" {
			musicObjId, err := primitive.ObjectIDFromHex(payload.MusicId)
			if err == nil {
				update["$set"].(bson.M)["currentMusicId"] = musicObjId
			}
		}

		musicJamCollection.UpdateOne(ctx, filter, update)

		broadcast, _ := json.Marshal(gin.H{
			"type":    "play",
			"payload": payload,
			"userId":  client.UserID,
		})
		websocketmanager.BroadcastToRoom(client.SimpleID, broadcast, client)

	case "pause":
		var payload SeekPayload
		json.Unmarshal(msg.Payload, &payload)

		musicJamCollection.UpdateOne(ctx, filter, bson.M{"$set": bson.M{
			"playing":   false,
			"timeNow":   payload.Position,
			"updatedAt": time.Now(),
		}})

		broadcast, _ := json.Marshal(gin.H{
			"type":    "pause",
			"payload": payload,
			"userId":  client.UserID,
		})
		websocketmanager.BroadcastToRoom(client.SimpleID, broadcast, client)

	case "seek":
		var payload SeekPayload
		if err := json.Unmarshal(msg.Payload, &payload); err != nil {
			return
		}

		musicJamCollection.UpdateOne(ctx, filter, bson.M{"$set": bson.M{
			"timeNow":   payload.Position,
			"updatedAt": time.Now(),
		}})

		broadcast, _ := json.Marshal(gin.H{
			"type":    "seek",
			"payload": payload,
			"userId":  client.UserID,
		})
		websocketmanager.BroadcastToRoom(client.SimpleID, broadcast, client)

	case "skip_next":
		var jam model.MusicJam
		err := musicJamCollection.FindOne(ctx, filter).Decode(&jam)
		if err != nil || len(jam.Queue) == 0 {
			return
		}

		nextMusic := jam.Queue[0]
		newQueue := jam.Queue[1:]

		musicJamCollection.UpdateOne(ctx, filter, bson.M{"$set": bson.M{
			"currentMusicId": nextMusic,
			"queue":          newQueue,
			"timeNow":        0,
			"playing":        true,
			"updatedAt":      time.Now(),
		}})

		queueStrs := make([]string, len(newQueue))
		for i, id := range newQueue {
			queueStrs[i] = id.Hex()
		}

		broadcast, _ := json.Marshal(gin.H{
			"type": "skip_next",
			"payload": gin.H{
				"musicId": nextMusic.Hex(),
				"queue":   queueStrs,
			},
			"userId": client.UserID,
		})
		websocketmanager.BroadcastToRoomAll(client.SimpleID, broadcast)

	case "set_queue":
		broadcast, _ := json.Marshal(gin.H{
			"type":    "set_queue",
			"payload": json.RawMessage(msg.Payload),
		})
		websocketmanager.BroadcastToRoom(client.SimpleID, broadcast, client)

	case "sync_state":
		broadcast, _ := json.Marshal(gin.H{
			"type":    "sync_state",
			"payload": json.RawMessage(msg.Payload),
		})
		websocketmanager.BroadcastToRoom(client.SimpleID, broadcast, client)

	case "position_sync":
		var payload SeekPayload
		if err := json.Unmarshal(msg.Payload, &payload); err != nil {
			return
		}

		musicJamCollection.UpdateOne(ctx, filter, bson.M{"$set": bson.M{
			"timeNow":   payload.Position,
			"updatedAt": time.Now(),
		}})

		broadcast, _ := json.Marshal(gin.H{
			"type":    "position_sync",
			"payload": payload,
			"userId":  client.UserID,
		})
		websocketmanager.BroadcastToRoom(client.SimpleID, broadcast, client)

	case "skip_to":
		broadcast, _ := json.Marshal(gin.H{
			"type":    "skip_to",
			"payload": json.RawMessage(msg.Payload),
		})
		websocketmanager.BroadcastToRoom(client.SimpleID, broadcast, client)

	case "add_to_queue":
		var payload QueuePayload
		if err := json.Unmarshal(msg.Payload, &payload); err != nil {
			return
		}

		musicObjId, err := primitive.ObjectIDFromHex(payload.MusicId)
		if err != nil {
			return
		}

		musicJamCollection.UpdateOne(ctx, filter, bson.M{
			"$push": bson.M{"queue": musicObjId},
			"$set":  bson.M{"updatedAt": time.Now()},
		})

		var jam model.MusicJam
		musicJamCollection.FindOne(ctx, filter).Decode(&jam)

		queueStrs := make([]string, len(jam.Queue))
		for i, id := range jam.Queue {
			queueStrs[i] = id.Hex()
		}

		broadcast, _ := json.Marshal(gin.H{
			"type": "queue_updated",
			"payload": gin.H{
				"queue":  queueStrs,
				"added":  payload.MusicId,
				"userId": client.UserID,
			},
		})
		websocketmanager.BroadcastToRoomAll(client.SimpleID, broadcast)

	case "remove_from_queue":
		var payload QueuePayload
		if err := json.Unmarshal(msg.Payload, &payload); err != nil {
			return
		}

		musicObjId, err := primitive.ObjectIDFromHex(payload.MusicId)
		if err != nil {
			return
		}

		musicJamCollection.UpdateOne(ctx, filter, bson.M{
			"$pull": bson.M{"queue": musicObjId},
			"$set":  bson.M{"updatedAt": time.Now()},
		})

		var jam model.MusicJam
		musicJamCollection.FindOne(ctx, filter).Decode(&jam)

		queueStrs := make([]string, len(jam.Queue))
		for i, id := range jam.Queue {
			queueStrs[i] = id.Hex()
		}

		broadcast, _ := json.Marshal(gin.H{
			"type": "queue_updated",
			"payload": gin.H{
				"queue":   queueStrs,
				"removed": payload.MusicId,
				"userId":  client.UserID,
			},
		})
		websocketmanager.BroadcastToRoomAll(client.SimpleID, broadcast)
	}
}
