package controllers

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"strings"
	"time"

	database "server/src/db"
	helper "server/src/helpers"
	model "server/src/models"

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

var artistCollection *mongo.Collection = database.OpenCollection(database.Client, "artists")

func CreateArtist() gin.HandlerFunc {
	return func(c *gin.Context) {
		if ok, _, _ := helper.CheckAdminOrUidPermission(c, ""); !ok {
			return
		}

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		var artist model.Artist

		if err := c.BindJSON(&artist); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		count, err := artistCollection.CountDocuments(ctx, bson.M{"name": artist.Name})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		if count > 0 {
			c.JSON(http.StatusConflict, gin.H{"error": "artista já cadastrado"})
			return
		}

		artist.ID = primitive.NewObjectID()
		artist.AvatarUrl = "/image/avatar/" + artist.ID.Hex()
		artist.BannerUrl = "/image/banner/" + artist.ID.Hex()
		artist.CreatedAt = time.Now()
		artist.UpdatedAt = artist.CreatedAt

		if validationErr := validate.Struct(&artist); validationErr != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": validationErr.Error()})
			return
		}

		_, err = artistCollection.InsertOne(ctx, artist)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao criar artista"})
			return
		}

		c.JSON(http.StatusCreated, artist)
	}
}

func GetArtist() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		artistID := c.Param("artistId")
		objectID, err := primitive.ObjectIDFromHex(artistID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "ID inválido"})
			return
		}

		var artist model.Artist
		err = artistCollection.FindOne(ctx, bson.M{"_id": objectID}).Decode(&artist)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Artista não encontrado"})
			return
		}

		serverURL := os.Getenv("SERVER_URL")
		if artist.AvatarUrl != "" {
			artist.AvatarUrl = serverURL + artist.AvatarUrl
		}
		if artist.BannerUrl != "" {
			artist.BannerUrl = serverURL + artist.BannerUrl
		}

		var albums []model.Album

		albumCursor, err := albumCollection.Find(ctx, bson.M{"artistId": objectID})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao buscar álbuns"})
			return
		}
		if err := albumCursor.All(ctx, &albums); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao processar álbuns"})
			return
		}

		// Build album lookup map for enriching musics
		albumMap := make(map[primitive.ObjectID]model.Album)
		for i, a := range albums {
			albumMap[a.ID] = a
			albums[i].AlbumCoverUrl = serverURL + a.AlbumCoverUrl
		}

		var musics []model.Music

		// Try to get top 5 by play count first
		topMusicIDs := GetTopMusicsByArtist(ctx, objectID, 5)

		if len(topMusicIDs) > 0 {
			// Fetch musics in play-count order
			for _, mid := range topMusicIDs {
				var m model.Music
				err := musicCollection.FindOne(ctx, bson.M{"_id": mid}).Decode(&m)
				if err == nil {
					musics = append(musics, m)
				}
			}
			// If we got fewer than 5 from plays, fill with newest that aren't already included
			if len(musics) < 5 {
				excludeIDs := make([]primitive.ObjectID, len(musics))
				for i, m := range musics {
					excludeIDs[i] = m.ID
				}
				fillCursor, err := musicCollection.Find(
					ctx,
					bson.M{"artistId": objectID, "_id": bson.M{"$nin": excludeIDs}},
					options.Find().SetSort(bson.M{"createdAt": -1}).SetLimit(int64(5-len(musics))),
				)
				if err == nil {
					var fillMusics []model.Music
					fillCursor.All(ctx, &fillMusics)
					musics = append(musics, fillMusics...)
				}
			}
		} else {
			// No play data yet — fall back to newest
			musicCursor, err := musicCollection.Find(
				ctx,
				bson.M{"artistId": objectID},
				options.Find().SetSort(bson.M{"createdAt": -1}).SetLimit(5),
			)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao buscar músicas"})
				return
			}
			if err := musicCursor.All(ctx, &musics); err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao processar músicas"})
				return
			}
		}

		// Helper to enrich a music slice
		enrichMusic := func(musicList []model.Music) []gin.H {
			result := make([]gin.H, len(musicList))
			for i, m := range musicList {
				coverUrl := m.CoverUrl
				color := m.Color
				albumName := ""
				if a, ok := albumMap[m.AlbumID]; ok {
					albumName = a.Name
					if coverUrl == "" {
						coverUrl = serverURL + a.AlbumCoverUrl
					}
					if color == "" {
						color = a.Color
					}
				}
				if coverUrl == "" {
					coverUrl = serverURL + "/image/cover/" + m.ID.Hex()
				}
				if m.CoverUrl != "" && !strings.HasPrefix(m.CoverUrl, "http") {
					coverUrl = serverURL + m.CoverUrl
				}

				var lyrics interface{}
				lyricsPath := fmt.Sprintf("./uploads/lyrics/%s.lrc", m.ID.Hex())
				if _, err := os.Stat(lyricsPath); err == nil {
					if parsed, err := parseLRC(lyricsPath); err == nil {
						lyrics = parsed
					}
				}

				result[i] = gin.H{
					"_id":        m.ID,
					"url":        serverURL + m.Url,
					"name":       m.Name,
					"artistId":   m.ArtistID,
					"artistName": artist.Name,
					"albumId":    m.AlbumID,
					"albumName":  albumName,
					"genre":      m.Genre,
					"coverUrl":   coverUrl,
					"color":      color,
					"waveform":   m.Waveform,
					"lyrics":     lyrics,
					"createdAt":  m.CreatedAt,
					"updatedAt":  m.UpdatedAt,
				}
			}
			return result
		}

		enrichedMusics := enrichMusic(musics)

		// Fetch singles (musics without album)
		var singles []model.Music
		singlesCursor, err := musicCollection.Find(
			ctx,
			bson.M{"artistId": objectID, "albumId": primitive.NilObjectID},
			options.Find().SetSort(bson.M{"createdAt": -1}),
		)
		if err == nil {
			singlesCursor.All(ctx, &singles)
		}
		enrichedSingles := enrichMusic(singles)

		response := gin.H{
			"artist":  artist,
			"albums":  albums,
			"musics":  enrichedMusics,
			"singles": enrichedSingles,
		}

		c.JSON(http.StatusOK, response)
	}
}

func UpdateArtist() gin.HandlerFunc {
	return func(c *gin.Context) {
		if ok, _, _ := helper.CheckAdminOrUidPermission(c, ""); !ok {
			return
		}

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		artistID := c.Param("artistId")
		objectID, err := primitive.ObjectIDFromHex(artistID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "ID inválido"})
			return
		}

		var updateData model.Artist

		if err := c.ShouldBindJSON(&updateData); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		var currentArtist model.Artist

		err = artistCollection.FindOne(ctx, bson.M{"_id": objectID}).Decode(&currentArtist)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Artista não encontrado"})
			return
		}

		if updateData.Name != "" {
			currentArtist.Name = updateData.Name
		}
		if len(updateData.Genres) > 0 {
			currentArtist.Genres = updateData.Genres
		}
		if updateData.AvatarUrl != "" {
			currentArtist.AvatarUrl = updateData.AvatarUrl
		}
		if updateData.BannerUrl != "" {
			currentArtist.BannerUrl = updateData.BannerUrl
		}
		if updateData.Bio != "" {
			currentArtist.Bio = updateData.Bio
		}
		if updateData.Color != "" {
			currentArtist.Color = updateData.Color
		}

		currentArtist.UpdatedAt = time.Now()

		_, err = artistCollection.ReplaceOne(ctx, bson.M{"_id": objectID}, currentArtist)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao atualizar artista"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Artista atualizado com sucesso"})
	}
}

func DeleteArtist() gin.HandlerFunc {
	return func(c *gin.Context) {
		if ok, _, _ := helper.CheckAdminOrUidPermission(c, ""); !ok {
			return
		}

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		artistID := c.Param("artistId")

		objectID, err := primitive.ObjectIDFromHex(artistID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "ID inválido"})
			return
		}

		var artist model.Artist

		err = artistCollection.FindOne(ctx, bson.M{"_id": objectID}).Decode(&artist)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao buscar artista"})
			return
		}

		// Delete all music files for this artist
		cursor, err := musicCollection.Find(ctx, bson.M{"artistId": objectID})
		if err == nil {
			var musics []model.Music
			if err := cursor.All(ctx, &musics); err == nil {
				for _, m := range musics {
					os.Remove("./uploads/music/" + m.ID.Hex() + ".m4a")
					os.Remove("./uploads/lyrics/" + m.ID.Hex() + ".lrc")
					os.Remove("./uploads/image/music_cover/" + m.ID.Hex() + ".png")
				}
			}
		}

		_, err = musicCollection.DeleteMany(ctx, bson.M{"artistId": objectID})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao deletar músicas"})
			return
		}

		// Delete all album cover files
		albumCursor, err := albumCollection.Find(ctx, bson.M{"artistId": objectID})
		if err == nil {
			var albums []model.Album
			if err := albumCursor.All(ctx, &albums); err == nil {
				for _, a := range albums {
					os.Remove("./uploads/image/cover/" + a.ID.Hex() + ".png")
				}
			}
		}

		_, err = albumCollection.DeleteMany(ctx, bson.M{"artistId": objectID})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao deletar álbuns"})
			return
		}

		// Delete artist image files
		os.Remove("./uploads/image/avatar/" + objectID.Hex() + ".png")
		os.Remove("./uploads/image/banner/" + objectID.Hex() + ".png")

		result, err := artistCollection.DeleteOne(ctx, bson.M{"_id": objectID})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao deletar artista"})
			return
		}

		if result.DeletedCount == 0 {
			c.JSON(http.StatusNotFound, gin.H{"error": "Artista não encontrado"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Artista deletado com sucesso"})
	}
}
