package model

import (
	"time"

	"go.mongodb.org/mongo-driver/bson/primitive"
)

type User struct {
	ID        primitive.ObjectID   `json:"_id" bson:"_id,omitempty"`
	Uid       string               `json:"uid" bson:"uid" validate:"required"`
	Name      string               `json:"name" bson:"name" validate:"required"`
	AvatarUrl string               `bson:"avatarUrl" json:"avatarUrl" validate:"required"`
	Email     string               `json:"email" bson:"email" validate:"required"`
	Password  string               `json:"password" bson:"password" validate:"required"`
	UserType  string               `bson:"userType" json:"userType" validate:"required"`
	Favorites []primitive.ObjectID `bson:"favorites" json:"favorites"`
	CreatedAt time.Time            `bson:"createdAt" json:"createdAt" validate:"required"`
	UpdatedAt time.Time            `bson:"updatedAt" json:"updatedAt" validate:"required"`
}
