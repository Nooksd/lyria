package model

import (
	"time"

	"go.mongodb.org/mongo-driver/bson/primitive"
)

type Music struct {
	ID        primitive.ObjectID `json:"id" bson:"_id,omitempty"`
	Url       string             `json:"url" bson:"url,omitempty"`
	Name      string             `json:"name" bson:"name" validate:"required"`
	ArtistID  primitive.ObjectID `json:"artistId" bson:"artistId" validate:"required"`
	AlbumID   primitive.ObjectID `json:"albumId" bson:"albumId" validate:"required"`
	Genre     string             `json:"genre" bson:"genre"`
	CreatedAt time.Time          `json:"createdAt" bson:"createdAt"`
	UpdatedAt time.Time          `json:"updatedAt" bson:"updatedAt"`
}
