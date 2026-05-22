package controllers

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"strings"
	"time"

	model "server/src/models"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
)

func ToggleFavorite() gin.HandlerFunc {
	return func(c *gin.Context) {
		musicId := c.Param("musicId")
		musicObjectId, err := primitive.ObjectIDFromHex(musicId)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "ID de música inválido"})
			return
		}

		userClaims, exists := c.Get("user")
		if !exists {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Usuário não autenticado"})
			return
		}

		claims, ok := userClaims.(jwt.MapClaims)
		if !ok {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao processar token"})
			return
		}

		userId := claims["UserId"].(string)

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		var user struct {
			Favorites []primitive.ObjectID `bson:"favorites"`
		}
		err = userCollection.FindOne(ctx, bson.M{"uid": userId}).Decode(&user)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Usuário não encontrado"})
			return
		}

		isFavorite := false
		for _, fav := range user.Favorites {
			if fav == musicObjectId {
				isFavorite = true
				break
			}
		}

		var update bson.M
		if isFavorite {
			update = bson.M{"$pull": bson.M{"favorites": musicObjectId}, "$set": bson.M{"updatedAt": time.Now()}}
		} else {
			update = bson.M{"$addToSet": bson.M{"favorites": musicObjectId}, "$set": bson.M{"updatedAt": time.Now()}}
		}

		_, err = userCollection.UpdateOne(ctx, bson.M{"uid": userId}, update)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao atualizar favoritos"})
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"message":    "Favorito atualizado",
			"isFavorite": !isFavorite,
		})
	}
}

func GetFavorites() gin.HandlerFunc {
	return func(c *gin.Context) {
		userClaims, exists := c.Get("user")
		if !exists {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Usuário não autenticado"})
			return
		}

		claims, ok := userClaims.(jwt.MapClaims)
		if !ok {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao processar token"})
			return
		}

		userId := claims["UserId"].(string)
		serverURL := os.Getenv("SERVER_URL")

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		// 1. Get user favorites IDs
		var user struct {
			Favorites []primitive.ObjectID `bson:"favorites"`
		}
		err := userCollection.FindOne(ctx, bson.M{"uid": userId}).Decode(&user)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Usuário não encontrado"})
			return
		}

		if len(user.Favorites) == 0 {
			c.JSON(http.StatusOK, gin.H{"favorites": []gin.H{}})
			return
		}

		// 2. Fetch musics by IDs
		musicCursor, err := musicCollection.Find(ctx, bson.M{"_id": bson.M{"$in": user.Favorites}})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao buscar músicas"})
			return
		}
		var musics []model.Music
		if err := musicCursor.All(ctx, &musics); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao processar músicas"})
			return
		}

		// 3. Collect unique albumIds and artistIds
		albumIdSet := make(map[primitive.ObjectID]bool)
		artistIdSet := make(map[primitive.ObjectID]bool)
		for _, m := range musics {
			if !m.AlbumID.IsZero() {
				albumIdSet[m.AlbumID] = true
			}
			if !m.ArtistID.IsZero() {
				artistIdSet[m.ArtistID] = true
			}
		}

		// 4. Fetch albums
		albumMap := make(map[primitive.ObjectID]model.Album)
		if len(albumIdSet) > 0 {
			ids := make([]primitive.ObjectID, 0, len(albumIdSet))
			for id := range albumIdSet {
				ids = append(ids, id)
			}
			albumCtx, albumCancel := context.WithTimeout(context.Background(), 10*time.Second)
			defer albumCancel()
			albumCursor, err := albumCollection.Find(albumCtx, bson.M{"_id": bson.M{"$in": ids}})
			if err == nil {
				var albums []model.Album
				_ = albumCursor.All(albumCtx, &albums)
				for _, a := range albums {
					albumMap[a.ID] = a
				}
			}
		}

		// 5. Fetch artists
		artistMap := make(map[primitive.ObjectID]model.Artist)
		if len(artistIdSet) > 0 {
			ids := make([]primitive.ObjectID, 0, len(artistIdSet))
			for id := range artistIdSet {
				ids = append(ids, id)
			}
			artistCtx, artistCancel := context.WithTimeout(context.Background(), 10*time.Second)
			defer artistCancel()
			artistCursor, err := artistCollection.Find(artistCtx, bson.M{"_id": bson.M{"$in": ids}})
			if err == nil {
				var artists []model.Artist
				_ = artistCursor.All(artistCtx, &artists)
				for _, a := range artists {
					artistMap[a.ID] = a
				}
			}
		}

		// 6. Build enriched result
		enriched := make([]gin.H, 0, len(musics))
		for _, m := range musics {
			coverUrl := m.CoverUrl
			color := m.Color
			albumName := ""
			artistName := ""

			if a, ok := albumMap[m.AlbumID]; ok {
				albumName = a.Name
				if coverUrl == "" {
					coverUrl = a.AlbumCoverUrl
				}
				if color == "" {
					color = a.Color
				}
			}
			if coverUrl != "" && !strings.HasPrefix(coverUrl, "http") {
				coverUrl = serverURL + coverUrl
			}
			if ar, ok := artistMap[m.ArtistID]; ok {
				artistName = ar.Name
			}

			// Load lyrics if available
			var lyrics interface{}
			lyricsPath := fmt.Sprintf("./uploads/lyrics/%s.lrc", m.ID.Hex())
			if _, err := os.Stat(lyricsPath); err == nil {
				if parsed, err := parseLRC(lyricsPath); err == nil {
					lyrics = parsed
				}
			}

			enriched = append(enriched, gin.H{
				"_id":                m.ID,
				"url":                serverURL + m.Url,
				"name":               m.Name,
				"artistId":           m.ArtistID,
				"artistName":         artistName,
				"albumId":            m.AlbumID,
				"albumName":          albumName,
				"genre":              m.Genre,
				"coverUrl":           coverUrl,
				"color":              color,
				"spotifyId":          m.SpotifyID,
				"spotifyUrl":         m.SpotifyURL,
				"spotifyPopularity":  m.SpotifyPopularity,
				"spotifyDurationMs":  m.SpotifyDurationMs,
				"spotifyTrackNumber": m.SpotifyTrackNo,
				"spotifyDiscNumber":  m.SpotifyDiscNo,
				"spotifyExplicit":    m.SpotifyExplicit,
				"waveform":           m.Waveform,
				"lyrics":             lyrics,
				"createdAt":          m.CreatedAt,
				"updatedAt":          m.UpdatedAt,
			})
		}

		c.JSON(http.StatusOK, gin.H{"favorites": enriched})
	}
}

func ToggleFavoriteAlbum() gin.HandlerFunc {
	return func(c *gin.Context) {
		toggleFavoriteObject(c, "albumId", "favoriteAlbums", albumCollection)
	}
}

func ToggleFavoriteArtist() gin.HandlerFunc {
	return func(c *gin.Context) {
		toggleFavoriteObject(c, "artistId", "favoriteArtists", artistCollection)
	}
}

func toggleFavoriteObject(c *gin.Context, paramName, fieldName string, targetCollection *mongo.Collection) {
	targetID := c.Param(paramName)
	targetObjectID, err := primitive.ObjectIDFromHex(targetID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "ID inválido"})
		return
	}

	userClaims, exists := c.Get("user")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Usuário não autenticado"})
		return
	}

	claims, ok := userClaims.(jwt.MapClaims)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao processar token"})
		return
	}

	userId := claims["UserId"].(string)

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	count, err := targetCollection.CountDocuments(ctx, bson.M{"_id": targetObjectID})
	if err != nil || count == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Item não encontrado"})
		return
	}

	var user bson.M
	if err := userCollection.FindOne(ctx, bson.M{"uid": userId}).Decode(&user); err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Usuário não encontrado"})
		return
	}

	isFavorite := false
	if values, ok := user[fieldName].(primitive.A); ok {
		for _, value := range values {
			if oid, ok := value.(primitive.ObjectID); ok && oid == targetObjectID {
				isFavorite = true
				break
			}
		}
	}

	var update bson.M
	if isFavorite {
		update = bson.M{"$pull": bson.M{fieldName: targetObjectID}, "$set": bson.M{"updatedAt": time.Now()}}
	} else {
		update = bson.M{"$addToSet": bson.M{fieldName: targetObjectID}, "$set": bson.M{"updatedAt": time.Now()}}
	}

	_, err = userCollection.UpdateOne(ctx, bson.M{"uid": userId}, update)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao atualizar favoritos"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message":    "Favorito atualizado",
		"isFavorite": !isFavorite,
	})
}

func GetFavoriteAlbums() gin.HandlerFunc {
	return func(c *gin.Context) {
		userClaims, exists := c.Get("user")
		if !exists {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Usuário não autenticado"})
			return
		}

		claims, ok := userClaims.(jwt.MapClaims)
		if !ok {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao processar token"})
			return
		}

		userId := claims["UserId"].(string)
		serverURL := os.Getenv("SERVER_URL")

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		var user struct {
			FavoriteAlbums []primitive.ObjectID `bson:"favoriteAlbums"`
		}
		if err := userCollection.FindOne(ctx, bson.M{"uid": userId}).Decode(&user); err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Usuário não encontrado"})
			return
		}

		if len(user.FavoriteAlbums) == 0 {
			c.JSON(http.StatusOK, gin.H{"albums": []gin.H{}})
			return
		}

		cursor, err := albumCollection.Find(ctx, bson.M{"_id": bson.M{"$in": user.FavoriteAlbums}})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao buscar álbuns"})
			return
		}

		var albums []model.Album
		if err := cursor.All(ctx, &albums); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao processar álbuns"})
			return
		}

		artistIDs := make([]primitive.ObjectID, 0, len(albums))
		for _, album := range albums {
			if !album.ArtistID.IsZero() {
				artistIDs = append(artistIDs, album.ArtistID)
			}
		}

		artistMap := make(map[primitive.ObjectID]model.Artist)
		if len(artistIDs) > 0 {
			artistCursor, err := artistCollection.Find(ctx, bson.M{"_id": bson.M{"$in": artistIDs}})
			if err == nil {
				var artists []model.Artist
				if artistCursor.All(ctx, &artists) == nil {
					for _, artist := range artists {
						artistMap[artist.ID] = artist
					}
				}
			}
		}

		results := make([]gin.H, 0, len(albums))
		for _, album := range albums {
			coverUrl := album.AlbumCoverUrl
			if coverUrl != "" && !strings.HasPrefix(coverUrl, "http") {
				coverUrl = serverURL + coverUrl
			}
			musicCount, _ := musicCollection.CountDocuments(ctx, bson.M{"albumId": album.ID})

			artistName := ""
			if artist, ok := artistMap[album.ArtistID]; ok {
				artistName = artist.Name
			}

			results = append(results, gin.H{
				"_id":           album.ID,
				"name":          album.Name,
				"artistId":      album.ArtistID,
				"artistName":    artistName,
				"albumCoverUrl": coverUrl,
				"color":         album.Color,
				"musicCount":    musicCount,
				"spotifyId":     album.SpotifyID,
				"spotifyUrl":    album.SpotifyURL,
				"albumType":     album.AlbumType,
				"albumGroup":    album.AlbumGroup,
				"releaseDate":   album.ReleaseDate,
				"totalTracks":   album.TotalTracks,
				"createdAt":     album.CreatedAt,
				"updatedAt":     album.UpdatedAt,
			})
		}

		c.JSON(http.StatusOK, gin.H{"albums": results})
	}
}

func GetFavoriteArtists() gin.HandlerFunc {
	return func(c *gin.Context) {
		userClaims, exists := c.Get("user")
		if !exists {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Usuário não autenticado"})
			return
		}

		claims, ok := userClaims.(jwt.MapClaims)
		if !ok {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao processar token"})
			return
		}

		userId := claims["UserId"].(string)
		serverURL := os.Getenv("SERVER_URL")

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		var user struct {
			FavoriteArtists []primitive.ObjectID `bson:"favoriteArtists"`
		}
		if err := userCollection.FindOne(ctx, bson.M{"uid": userId}).Decode(&user); err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Usuário não encontrado"})
			return
		}

		if len(user.FavoriteArtists) == 0 {
			c.JSON(http.StatusOK, gin.H{"artists": []gin.H{}})
			return
		}

		cursor, err := artistCollection.Find(ctx, bson.M{"_id": bson.M{"$in": user.FavoriteArtists}})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao buscar artistas"})
			return
		}

		var artists []model.Artist
		if err := cursor.All(ctx, &artists); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao processar artistas"})
			return
		}

		results := make([]gin.H, 0, len(artists))
		for _, artist := range artists {
			avatarUrl := artist.AvatarUrl
			bannerUrl := artist.BannerUrl
			if avatarUrl != "" && !strings.HasPrefix(avatarUrl, "http") {
				avatarUrl = serverURL + avatarUrl
			}
			if bannerUrl != "" && !strings.HasPrefix(bannerUrl, "http") {
				bannerUrl = serverURL + bannerUrl
			}
			musicCount, _ := musicCollection.CountDocuments(ctx, bson.M{"artistId": artist.ID})
			albumCount, _ := albumCollection.CountDocuments(ctx, bson.M{"artistId": artist.ID})

			results = append(results, gin.H{
				"_id":               artist.ID,
				"name":              artist.Name,
				"avatarUrl":         avatarUrl,
				"bannerUrl":         bannerUrl,
				"bio":               artist.Bio,
				"color":             artist.Color,
				"genres":            artist.Genres,
				"musicCount":        musicCount,
				"albumCount":        albumCount,
				"spotifyId":         artist.SpotifyID,
				"spotifyUrl":        artist.SpotifyURL,
				"spotifyPopularity": artist.SpotifyPopularity,
				"spotifyFollowers":  artist.SpotifyFollowers,
				"createdAt":         artist.CreatedAt,
				"updatedAt":         artist.UpdatedAt,
			})
		}

		c.JSON(http.StatusOK, gin.H{"artists": results})
	}
}

func GetUserProfile() gin.HandlerFunc {
	return func(c *gin.Context) {
		userId := c.Param("userId")

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		serverURL := os.Getenv("SERVER_URL")

		pipeline := []bson.M{
			{"$match": bson.M{"uid": userId}},
			{"$lookup": bson.M{
				"from": "playlists",
				"let":  bson.M{"ownerId": "$_id"},
				"pipeline": []bson.M{
					{"$match": bson.M{"$expr": bson.M{"$eq": []interface{}{"$ownerId", "$$ownerId"}}}},
					{"$addFields": bson.M{
						"playlistCoverUrl": bson.M{"$concat": []interface{}{serverURL, "$playlistCoverUrl"}},
						"musicCount":       bson.M{"$size": bson.M{"$ifNull": []interface{}{"$musics", []interface{}{}}}},
					}},
					{"$project": bson.M{
						"_id":              1,
						"name":             1,
						"playlistCoverUrl": 1,
						"musicCount":       1,
					}},
				},
				"as": "playlists",
			}},
			{"$project": bson.M{
				"uid": 1, "name": 1, "bio": 1,
				"avatarUrl":     bson.M{"$concat": []interface{}{serverURL, "$avatarUrl"}},
				"playlists":     1,
				"favoriteCount": bson.M{"$size": bson.M{"$ifNull": []interface{}{"$favorites", []interface{}{}}}},
				"createdAt":     1,
			}},
		}

		cursor, err := userCollection.Aggregate(ctx, pipeline)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao buscar perfil"})
			return
		}

		var results []bson.M
		if err = cursor.All(ctx, &results); err != nil || len(results) == 0 {
			c.JSON(http.StatusNotFound, gin.H{"error": "Usuário não encontrado"})
			return
		}

		c.JSON(http.StatusOK, results[0])
	}
}
