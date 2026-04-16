package model

import (
	"time"

	"go.mongodb.org/mongo-driver/bson/primitive"
)

type PlayEvent struct {
	ID        primitive.ObjectID `json:"_id" bson:"_id"`
	MusicID   primitive.ObjectID `json:"musicId" bson:"musicId"`
	UserID    string             `json:"userId" bson:"userId"`
	CreatedAt time.Time          `json:"createdAt" bson:"createdAt"`
}
