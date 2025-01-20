package model

import (
	"time"

	"go.mongodb.org/mongo-driver/bson/primitive"
)

type Music struct {
	ID         primitive.ObjectID `json:"id" bson:"_id,omitempty"`
	Name       string             `json:"name" bson:"name" validate:"required"`
	ArtistID   primitive.ObjectID `json:"artistId" bson:"artistId" validate:"required"`
	ArtistName string             `json:"artistName" bson:"artistName" validate:"required"`
	AlbumID    primitive.ObjectID `json:"albumId" bson:"albumId" validate:"required"`
	AlbumName  string             `json:"albumName" bson:"albumName" validate:"required"`
	AudioPath  string             `json:"audioPath" bson:"audioPath"`
	Genre      string             `json:"genre" bson:"genre,omitempty"`
	CreatedAt  time.Time          `json:"createdAt" bson:"createdAt"`
	UpdatedAt  time.Time          `json:"updatedAt" bson:"updatedAt"`
}
