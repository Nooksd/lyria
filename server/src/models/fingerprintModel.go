package models

import "go.mongodb.org/mongo-driver/bson/primitive"

type Fingerprint struct {
	ID      primitive.ObjectID `json:"_id,omitempty" bson:"_id,omitempty"`
	Hash    uint32             `json:"hash" bson:"hash"`
	MusicID primitive.ObjectID `json:"musicId" bson:"musicId"`
	Offset  uint32             `json:"offset" bson:"offset"`
}
