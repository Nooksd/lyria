package model

import (
	"time"

	"go.mongodb.org/mongo-driver/bson/primitive"
)

type Artist struct {
	ID        primitive.ObjectID `json:"_id" bson:"_id,omitempty"`
	Name      string             `json:"name" bson:"name" validate:"required"`
	Genres    []string           `json:"genres" bson:"genres"`
	AvatarUrl string             `json:"avatarUrl" bson:"avatarUrl" validate:"required"`
	CreatedAt time.Time          `json:"createdAt" bson:"createdAt" validate:"required"`
	UpdatedAt time.Time          `json:"updatedAt" bson:"updatedAt" validate:"required"`
}
