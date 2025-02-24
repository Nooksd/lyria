package model

import (
	"time"

	"go.mongodb.org/mongo-driver/bson/primitive"
)

type Participant struct {
	ID        primitive.ObjectID `json:"_id" bson:"id"`
	Name      string             `json:"name" bson:"name"`
	AvatarUrl string             `json:"avatarUrl" bson:"avatarUrl"`
}

type MusicJam struct {
	ID           primitive.ObjectID   `json:"_id" bson:"_id,omitempty"`
	SimpleID     string               `json:"simpleId" bson:"simpleId" validate:"required"`
	OwnerID      primitive.ObjectID   `json:"ownerId" bson:"ownerId" validate:"required"`
	Participants []Participant        `json:"participants" bson:"participants"`
	Queue        []primitive.ObjectID `json:"queue" bson:"queue"`
	Playing      bool                 `json:"playing" bson:"playing"`
	TimeNow      int64                `json:"timeNow" bson:"timeNow"`
	CreatedAt    time.Time            `json:"createdAt" bson:"createdAt"`
	UpdatedAt    time.Time            `json:"updatedAt" bson:"updatedAt"`
}
