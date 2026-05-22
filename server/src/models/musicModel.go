package model

import (
	"time"

	"go.mongodb.org/mongo-driver/bson/primitive"
)

type Music struct {
	ID                primitive.ObjectID `json:"_id" bson:"_id"`
	Url               string             `json:"url" bson:"url" validate:"required"`
	Name              string             `json:"name" bson:"name" validate:"required"`
	ArtistID          primitive.ObjectID `json:"artistId" bson:"artistId" validate:"required"`
	AlbumID           primitive.ObjectID `json:"albumId" bson:"albumId"`
	Genre             string             `json:"genre" bson:"genre"`
	CoverUrl          string             `json:"coverUrl,omitempty" bson:"coverUrl,omitempty"`
	Color             string             `json:"color,omitempty" bson:"color,omitempty"`
	Waveform          []float64          `json:"waveform" bson:"waveform"`
	SpotifyID         string             `json:"spotifyId,omitempty" bson:"spotifyId,omitempty"`
	SpotifyURL        string             `json:"spotifyUrl,omitempty" bson:"spotifyUrl,omitempty"`
	SpotifyPopularity int                `json:"spotifyPopularity,omitempty" bson:"spotifyPopularity,omitempty"`
	SpotifyDurationMs int                `json:"spotifyDurationMs,omitempty" bson:"spotifyDurationMs,omitempty"`
	SpotifyTrackNo    int                `json:"spotifyTrackNumber,omitempty" bson:"spotifyTrackNumber,omitempty"`
	SpotifyDiscNo     int                `json:"spotifyDiscNumber,omitempty" bson:"spotifyDiscNumber,omitempty"`
	SpotifyExplicit   bool               `json:"spotifyExplicit,omitempty" bson:"spotifyExplicit,omitempty"`
	CreatedAt         time.Time          `json:"createdAt" bson:"createdAt"`
	UpdatedAt         time.Time          `json:"updatedAt" bson:"updatedAt"`
}
