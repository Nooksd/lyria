package model

import (
	"time"

	"go.mongodb.org/mongo-driver/bson/primitive"
)

type ImportJob struct {
	ID          primitive.ObjectID `json:"_id" bson:"_id,omitempty"`
	SpotifyUrl  string             `json:"spotifyUrl" bson:"spotifyUrl"`
	ArtistName  string             `json:"artistName" bson:"artistName"`
	Status      string             `json:"status" bson:"status"` // queued, running, completed, failed, cancelled
	Progress    int                `json:"progress" bson:"progress"`
	Total       int                `json:"total" bson:"total"`
	Albums      int                `json:"albums" bson:"albums"`
	Musics      int                `json:"musics" bson:"musics"`
	Failed      int                `json:"failed" bson:"failed"`
	Logs        []ImportLog        `json:"logs" bson:"logs"`
	FailedItems []ImportFailedItem `json:"failedItems" bson:"failedItems"`
	ArtistID    string             `json:"artistId,omitempty" bson:"artistId,omitempty"`
	CreatedAt   time.Time          `json:"createdAt" bson:"createdAt"`
	UpdatedAt   time.Time          `json:"updatedAt" bson:"updatedAt"`
	FinishedAt  *time.Time         `json:"finishedAt,omitempty" bson:"finishedAt,omitempty"`
}

type ImportLog struct {
	Type    string    `json:"type" bson:"type"` // progress, error, done
	Message string    `json:"message" bson:"message"`
	Time    time.Time `json:"time" bson:"time"`
}

type ImportFailedItem struct {
	TrackName string `json:"trackName" bson:"trackName"`
	Reason    string `json:"reason" bson:"reason"`
}
