package model

import (
	"time"

	"go.mongodb.org/mongo-driver/bson/primitive"
)

type RecommendationJob struct {
	ID            primitive.ObjectID `json:"_id" bson:"_id,omitempty"`
	Status        string             `json:"status" bson:"status"` // queued, running, completed, failed
	Trigger       string             `json:"trigger" bson:"trigger"`
	Message       string             `json:"message" bson:"message"`
	Progress      int                `json:"progress" bson:"progress"`
	Total         int                `json:"total" bson:"total"`
	Percent       int                `json:"percent" bson:"percent"`
	CatalogMusics int                `json:"catalogMusics" bson:"catalogMusics"`
	FeatureCount  int                `json:"featureCount" bson:"featureCount"`
	ReusedVectors int                `json:"reusedVectors" bson:"reusedVectors"`
	PlayEvents    int64              `json:"playEvents" bson:"playEvents"`
	Playlists     int64              `json:"playlists" bson:"playlists"`
	Error         string             `json:"error,omitempty" bson:"error,omitempty"`
	ModelVersion  string             `json:"modelVersion" bson:"modelVersion"`
	StartedAt     *time.Time         `json:"startedAt,omitempty" bson:"startedAt,omitempty"`
	CreatedAt     time.Time          `json:"createdAt" bson:"createdAt"`
	UpdatedAt     time.Time          `json:"updatedAt" bson:"updatedAt"`
	FinishedAt    *time.Time         `json:"finishedAt,omitempty" bson:"finishedAt,omitempty"`
}
