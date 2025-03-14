package model

import (
	"time"

	"go.mongodb.org/mongo-driver/bson/primitive"
)

type Album struct {
	ID            primitive.ObjectID `json:"_id" bson:"_id,omitempty"`
	Name          string             `json:"name" bson:"name" validate:"required"`
	ArtistID      primitive.ObjectID `json:"artistId" bson:"artistId" validate:"required"`
	AlbumCoverUrl string             `json:"albumCoverUrl" bson:"albumCoverUrl" validate:"required"`
	Color         string             `json:"color" bson:"color" validate:"required"`
	CreatedAt     time.Time          `json:"createdAt" bson:"createdAt" validate:"required"`
	UpdatedAt     time.Time          `json:"updatedAt" bson:"updatedAt" validate:"required"`
}
