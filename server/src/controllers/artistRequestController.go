package controllers

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"regexp"
	"strings"
	"time"

	database "server/src/db"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

var artistRequestCollection *mongo.Collection = database.OpenCollection(database.Client, "artist_requests")

var spotifyArtistURLRegex = regexp.MustCompile(`open\.spotify\.com/artist/([a-zA-Z0-9]+)`)

func CreateArtistRequest() gin.HandlerFunc {
	return func(c *gin.Context) {
		userClaims, exists := c.Get("user")
		if !exists {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Não autenticado"})
			return
		}
		claims := userClaims.(jwt.MapClaims)
		userId := claims["UserId"].(string)

		var body struct {
			SpotifyUrl      string `json:"spotifyUrl"`
			SpotifyArtistId string `json:"spotifyArtistId"`
		}
		if err := c.ShouldBindJSON(&body); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Artista do Spotify é obrigatório"})
			return
		}

		spotifyArtistId := strings.TrimSpace(body.SpotifyArtistId)
		if spotifyArtistId == "" {
			matches := spotifyArtistURLRegex.FindStringSubmatch(body.SpotifyUrl)
			if len(matches) >= 2 {
				spotifyArtistId = matches[1]
			}
		}
		if spotifyArtistId == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Artista do Spotify inválido"})
			return
		}
		spotifyUrl := strings.TrimSpace(body.SpotifyUrl)
		if spotifyUrl == "" {
			spotifyUrl = "https://open.spotify.com/artist/" + spotifyArtistId
		}

		ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
		defer cancel()

		// Check if already requested (pending)
		count, _ := artistRequestCollection.CountDocuments(ctx, bson.M{
			"spotifyArtistId": spotifyArtistId,
			"status":          "pending",
		})
		if count > 0 {
			c.JSON(http.StatusConflict, gin.H{"error": "Este artista já foi solicitado e está aguardando aprovação"})
			return
		}

		// Check if artist already exists in system (by spotifyArtistId in name or direct lookup)
		// Fetch Spotify artist info to get the name
		token, err := getSpotifyTokenWithContext(c.Request.Context())
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao validar artista no Spotify"})
			return
		}

		spotifyURL := fmt.Sprintf("https://api.spotify.com/v1/artists/%s", spotifyArtistId)
		data, err := spotifyGetWithContext(c.Request.Context(), token, spotifyURL)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Artista não encontrado no Spotify"})
			return
		}

		var spotifyArtist struct {
			Name   string `json:"name"`
			Images []struct {
				URL string `json:"url"`
			} `json:"images"`
		}
		if err := json.Unmarshal(data, &spotifyArtist); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao processar dados do Spotify"})
			return
		}

		// Check if artist already exists in our system by Spotify ID or name (case-insensitive)
		existingCount, _ := artistCollection.CountDocuments(ctx, bson.M{
			"$or": []bson.M{
				{"spotifyId": spotifyArtistId},
				{"name": bson.M{"$regex": fmt.Sprintf("^%s$", regexp.QuoteMeta(spotifyArtist.Name)), "$options": "i"}},
			},
		})
		if existingCount > 0 {
			c.JSON(http.StatusConflict, gin.H{"error": "Este artista já existe no sistema"})
			return
		}

		avatarUrl := ""
		if len(spotifyArtist.Images) > 0 {
			avatarUrl = spotifyArtist.Images[0].URL
		}

		request := bson.M{
			"_id":             primitive.NewObjectID(),
			"spotifyUrl":      spotifyUrl,
			"spotifyArtistId": spotifyArtistId,
			"artistName":      spotifyArtist.Name,
			"avatarUrl":       avatarUrl,
			"status":          "pending",
			"requestedBy":     userId,
			"createdAt":       time.Now(),
		}

		_, err = artistRequestCollection.InsertOne(ctx, request)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao criar solicitação"})
			return
		}

		c.JSON(http.StatusCreated, gin.H{"message": "Solicitação enviada com sucesso"})
	}
}

func SearchSpotifyArtistsForRequest() gin.HandlerFunc {
	return func(c *gin.Context) {
		query := strings.TrimSpace(c.Query("query"))
		if len(query) < 2 {
			c.JSON(http.StatusOK, gin.H{"artists": []gin.H{}})
			return
		}

		ctx, cancel := context.WithTimeout(c.Request.Context(), 30*time.Second)
		defer cancel()

		token, err := getSpotifyTokenWithContext(ctx)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao consultar Spotify"})
			return
		}

		apiURL := fmt.Sprintf("https://api.spotify.com/v1/search?q=%s&type=artist&market=BR&limit=20", url.QueryEscape(query))
		data, err := spotifyGetWithContext(ctx, token, apiURL)
		if err != nil {
			c.JSON(http.StatusBadGateway, gin.H{"error": "Erro ao buscar artistas no Spotify"})
			return
		}

		var resp spotifySearchArtistsResponse
		if err := json.Unmarshal(data, &resp); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao processar resposta do Spotify"})
			return
		}

		spotifyIDs := make([]string, 0, len(resp.Artists.Items))
		names := make([]string, 0, len(resp.Artists.Items))
		for _, artist := range resp.Artists.Items {
			if artist.ID == "" || artist.Name == "" {
				continue
			}
			spotifyIDs = append(spotifyIDs, artist.ID)
			names = append(names, artist.Name)
		}

		existingSpotifyIDs := map[string]bool{}
		existingNames := map[string]bool{}
		if len(spotifyIDs) > 0 {
			filter := bson.M{"$or": []bson.M{
				{"spotifyId": bson.M{"$in": spotifyIDs}},
				{"name": bson.M{"$in": names}},
			}}
			cursor, err := artistCollection.Find(ctx, filter)
			if err == nil {
				var existing []bson.M
				if cursor.All(ctx, &existing) == nil {
					for _, item := range existing {
						if id, ok := item["spotifyId"].(string); ok && id != "" {
							existingSpotifyIDs[id] = true
						}
						if name, ok := item["name"].(string); ok && name != "" {
							existingNames[strings.ToLower(name)] = true
						}
					}
				}
			}

			reqCursor, err := artistRequestCollection.Find(ctx, bson.M{
				"spotifyArtistId": bson.M{"$in": spotifyIDs},
				"status":          "pending",
			})
			if err == nil {
				var requests []bson.M
				if reqCursor.All(ctx, &requests) == nil {
					for _, item := range requests {
						if id, ok := item["spotifyArtistId"].(string); ok && id != "" {
							existingSpotifyIDs[id] = true
						}
					}
				}
			}
		}

		results := make([]gin.H, 0, len(resp.Artists.Items))
		for _, artist := range resp.Artists.Items {
			if artist.ID == "" || artist.Name == "" {
				continue
			}
			if existingSpotifyIDs[artist.ID] || existingNames[strings.ToLower(artist.Name)] {
				continue
			}

			avatarUrl := ""
			if len(artist.Images) > 0 {
				avatarUrl = artist.Images[0].URL
			}
			results = append(results, gin.H{
				"spotifyArtistId": artist.ID,
				"spotifyUrl":      "https://open.spotify.com/artist/" + artist.ID,
				"name":            artist.Name,
				"avatarUrl":       avatarUrl,
				"genres":          artist.Genres,
			})
		}

		c.JSON(http.StatusOK, gin.H{"artists": results})
	}
}

func ListArtistRequests() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		status := c.DefaultQuery("status", "")

		filter := bson.M{}
		if status != "" {
			filter["status"] = status
		}

		cursor, err := artistRequestCollection.Find(ctx, filter,
			options.Find().SetSort(bson.M{"createdAt": -1}),
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao buscar solicitações"})
			return
		}
		defer cursor.Close(ctx)

		var requests []bson.M
		if err := cursor.All(ctx, &requests); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao processar solicitações"})
			return
		}

		// Enrich with user names
		for i, req := range requests {
			userId, ok := req["requestedBy"].(string)
			if !ok {
				continue
			}
			var user struct {
				Name string `bson:"name"`
			}
			userObjId, err := primitive.ObjectIDFromHex(userId)
			if err == nil {
				userCollection.FindOne(ctx, bson.M{"_id": userObjId}).Decode(&user)
				requests[i]["requestedByName"] = user.Name
			}
		}

		if requests == nil {
			requests = []bson.M{}
		}

		c.JSON(http.StatusOK, gin.H{"requests": requests})
	}
}

func ApproveArtistRequest() gin.HandlerFunc {
	return func(c *gin.Context) {
		requestId := c.Param("id")
		objectId, err := primitive.ObjectIDFromHex(requestId)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "ID inválido"})
			return
		}

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		var request bson.M
		err = artistRequestCollection.FindOne(ctx, bson.M{"_id": objectId, "status": "pending"}).Decode(&request)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Solicitação não encontrada ou já processada"})
			return
		}

		now := time.Now()
		artistRequestCollection.UpdateOne(ctx, bson.M{"_id": objectId}, bson.M{
			"$set": bson.M{"status": "approved", "reviewedAt": now},
		})

		// Create import job for this artist
		spotifyUrl, _ := request["spotifyUrl"].(string)
		if spotifyUrl == "" {
			c.JSON(http.StatusOK, gin.H{"message": "Aprovada, mas sem URL para importar"})
			return
		}

		// Extract artist ID and use Spotify URL directly
		matches := spotifyArtistURLRegex.FindStringSubmatch(spotifyUrl)
		if len(matches) < 2 {
			c.JSON(http.StatusOK, gin.H{"message": "Aprovada, mas URL inválida para importação"})
			return
		}

		// Use the import queue to import
		urls := []string{strings.TrimSpace(spotifyUrl)}
		jobs := createImportJobsFromURLs(urls)

		if len(jobs) > 0 {
			c.JSON(http.StatusOK, gin.H{"message": "Solicitação aprovada e importação iniciada", "jobs": len(jobs)})
		} else {
			c.JSON(http.StatusOK, gin.H{"message": "Solicitação aprovada"})
		}
	}
}

func RejectArtistRequest() gin.HandlerFunc {
	return func(c *gin.Context) {
		requestId := c.Param("id")
		objectId, err := primitive.ObjectIDFromHex(requestId)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "ID inválido"})
			return
		}

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		now := time.Now()
		result, err := artistRequestCollection.UpdateOne(ctx,
			bson.M{"_id": objectId, "status": "pending"},
			bson.M{"$set": bson.M{"status": "rejected", "reviewedAt": now}},
		)
		if err != nil || result.MatchedCount == 0 {
			c.JSON(http.StatusNotFound, gin.H{"error": "Solicitação não encontrada ou já processada"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Solicitação rejeitada"})
	}
}
