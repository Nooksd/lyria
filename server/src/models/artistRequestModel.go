package model

import (
	"time"

	"go.mongodb.org/mongo-driver/bson/primitive"
)

type ArtistRequest struct {
	ID              primitive.ObjectID `json:"_id" bson:"_id"`
	SpotifyUrl      string             `json:"spotifyUrl" bson:"spotifyUrl" validate:"required"`
	SpotifyArtistId string             `json:"spotifyArtistId" bson:"spotifyArtistId"`
	ArtistName      string             `json:"artistName" bson:"artistName"`
	AvatarUrl       string             `json:"avatarUrl" bson:"avatarUrl"`
	Status          string             `json:"status" bson:"status"` // pending, approved, rejected
	RequestedBy     string             `json:"requestedBy" bson:"requestedBy"`
	ReviewedAt      *time.Time         `json:"reviewedAt,omitempty" bson:"reviewedAt,omitempty"`
	CreatedAt       time.Time          `json:"createdAt" bson:"createdAt"`
}
