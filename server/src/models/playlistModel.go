package model

import (
	"time"

	"go.mongodb.org/mongo-driver/bson/primitive"
)

type Playlist struct {
	ID               primitive.ObjectID   `json:"id" bson:"_id,omitempty"`
	Name             string               `json:"name" bson:"name" validate:"required"`
	OwnerID          primitive.ObjectID   `json:"ownerId" bson:"ownerId" validate:"required"`
	PlaylistCoverUrl string               `json:"playlistCoverUrl" bson:"playlistCoverUrl" validate:"required"`
	Musics           []primitive.ObjectID `json:"musics" bson:"musics" validate:"required"`
	IsPublic         bool                 `json:"isPublic" bson:"isPublic" validate:"required"`
	CreatedAt        time.Time            `json:"createdAt" bson:"createdAt" validate:"required"`
	UpdatedAt        time.Time            `json:"updatedAt" bson:"updatedAt" validate:"required"`
}
