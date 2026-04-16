package model

import (
	"time"

	"go.mongodb.org/mongo-driver/bson/primitive"
)

type Artist struct {
	ID        primitive.ObjectID `json:"_id" bson:"_id,omitempty"`
	Name      string             `json:"name" bson:"name" validate:"required"`
	SpotifyID string             `json:"spotifyId,omitempty" bson:"spotifyId,omitempty"`
	Genres    []string           `json:"genres" bson:"genres"`
	AvatarUrl string             `json:"avatarUrl" bson:"avatarUrl" validate:"required"`
	BannerUrl string             `json:"bannerUrl" bson:"bannerUrl"`
	Bio       string             `json:"bio" bson:"bio"`
	Color     string             `json:"color" bson:"color"`
	CreatedAt time.Time          `json:"createdAt" bson:"createdAt" validate:"required"`
	UpdatedAt time.Time          `json:"updatedAt" bson:"updatedAt" validate:"required"`
}
