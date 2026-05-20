package controllers

import (
	"bufio"
	"context"
	"fmt"
	"net/http"
	"os"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo/options"
)

type LyricLine struct {
	Time    string `json:"time"`
	Content string `json:"content"`
}

func parseLRC(filePath string) ([]LyricLine, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return nil, fmt.Errorf("erro ao abrir arquivo: %v", err)
	}
	defer file.Close()

	var lyrics []LyricLine
	scanner := bufio.NewScanner(file)

	lyricLinePattern := regexp.MustCompile(`\[(\d{2}:\d{2}\.\d{2,3})\](.*)`)

	for scanner.Scan() {
		line := scanner.Text()
		if matches := lyricLinePattern.FindStringSubmatch(line); matches != nil {
			lyrics = append(lyrics, LyricLine{
				Time:    matches[1],
				Content: strings.TrimSpace(matches[2]),
			})
		}
	}

	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("erro na leitura do arquivo: %v", err)
	}

	return lyrics, nil
}

func GeneralSearch() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		searchQuery := strings.TrimSpace(c.Query("query"))
		if searchQuery == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Parâmetro de pesquisa 'query' é obrigatório"})
			return
		}

		pageInt := parsePositiveQueryInt(c.DefaultQuery("page", "1"), 1, 100)
		limitInt := parsePositiveQueryInt(c.DefaultQuery("limit", "20"), 20, 50)
		skip := (pageInt - 1) * limitInt
		queryWindow := skip + limitInt
		if queryWindow > 150 {
			queryWindow = 150
		}
		includeLyrics := c.Query("includeLyrics") == "true"
		includeWaveform := c.Query("includeWaveform") == "true"

		musicParam := c.Query("music")
		artistParam := c.Query("artist")
		albumParam := c.Query("album")

		searchMusic := (musicParam == "true")
		searchArtist := (artistParam == "true")
		searchAlbum := (albumParam == "true")

		if !searchMusic && !searchArtist && !searchAlbum {
			searchMusic = true
			searchArtist = true
			searchAlbum = true
		}

		var results []bson.M

		serverURL := os.Getenv("SERVER_URL")
		searchRegex := bson.M{"name": bson.M{"$regex": regexp.QuoteMeta(searchQuery), "$options": "i"}}
		totalResults := int64(0)

		if searchArtist {
			if count, err := artistCollection.CountDocuments(ctx, searchRegex); err == nil {
				totalResults += count
			}
			findOpts := options.Find().
				SetSort(bson.M{"name": 1}).
				SetLimit(int64(queryWindow)).
				SetProjection(bson.M{"name": 1, "avatarUrl": 1})
			artistCursor, err := artistCollection.Find(ctx, searchRegex, findOpts)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao buscar artistas"})
				return
			}
			var artists []bson.M
			if err := artistCursor.All(ctx, &artists); err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao processar artistas"})
				return
			}
			for i := range artists {
				avatarUrl, _ := artists[i]["avatarUrl"].(string)
				results = append(results, bson.M{
					"name":        artists[i]["name"],
					"type":        "artist",
					"id":          artists[i]["_id"],
					"description": "Artista",
					"imageUrl":    serverURL + avatarUrl,
				})
			}
		}

		if searchAlbum {
			if count, err := albumCollection.CountDocuments(ctx, searchRegex); err == nil {
				totalResults += count
			}
			albumPipeline := []bson.M{
				{"$match": searchRegex},
				{"$sort": bson.M{"name": 1}},
				{"$limit": queryWindow},
				{
					"$lookup": bson.M{
						"from":         "artists",
						"localField":   "artistId",
						"foreignField": "_id",
						"as":           "artist",
					},
				},
				{"$unwind": "$artist"},
			}

			albumCursor, err := albumCollection.Aggregate(ctx, albumPipeline)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao buscar álbuns"})
				return
			}
			var albums []bson.M
			if err := albumCursor.All(ctx, &albums); err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao processar álbuns"})
				return
			}
			for i := range albums {
				artistName := ""
				if artist, ok := albums[i]["artist"].(bson.M); ok {
					artistName, _ = artist["name"].(string)
				}
				coverUrl, _ := albums[i]["albumCoverUrl"].(string)
				results = append(results, bson.M{
					"name":        albums[i]["name"],
					"type":        "album",
					"id":          albums[i]["_id"],
					"description": "Álbum · " + artistName,
					"imageUrl":    serverURL + coverUrl,
				})
			}
		}

		if searchMusic {
			if count, err := musicCollection.CountDocuments(ctx, searchRegex); err == nil {
				totalResults += count
			}
			project := bson.M{
				"_id":       1,
				"url":       1,
				"name":      1,
				"artistId":  1,
				"albumId":   1,
				"genre":     1,
				"coverUrl":  1,
				"color":     1,
				"createdAt": 1,
				"updatedAt": 1,
			}
			if includeWaveform {
				project["waveform"] = 1
			}
			musicPipeline := []bson.M{
				{"$match": searchRegex},
				{"$sort": bson.M{"name": 1}},
				{"$limit": queryWindow},
				{"$project": project},
				{
					"$lookup": bson.M{
						"from":         "albums",
						"localField":   "albumId",
						"foreignField": "_id",
						"as":           "album",
					},
				},
				{"$unwind": bson.M{"path": "$album", "preserveNullAndEmptyArrays": true}},
				{
					"$lookup": bson.M{
						"from":         "artists",
						"localField":   "artistId",
						"foreignField": "_id",
						"as":           "artist",
					},
				},
				{"$unwind": bson.M{"path": "$artist", "preserveNullAndEmptyArrays": true}},
			}

			musicCursor, err := musicCollection.Aggregate(ctx, musicPipeline)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao buscar músicas"})
				return
			}
			var musics []bson.M
			if err := musicCursor.All(ctx, &musics); err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao processar músicas"})
				return
			}
			for i := range musics {
				musicData := musics[i]

				// Cover URL: music's own → album's → empty
				coverUrl := ""
				if mc, ok := musicData["coverUrl"].(string); ok && mc != "" {
					if strings.HasPrefix(mc, "http") {
						coverUrl = mc
					} else {
						coverUrl = os.Getenv("SERVER_URL") + mc
					}
				} else if album, ok := musicData["album"].(bson.M); ok {
					if ac, ok := album["albumCoverUrl"].(string); ok && ac != "" {
						coverUrl = os.Getenv("SERVER_URL") + ac
					}
				}
				musicData["coverUrl"] = coverUrl

				// Color: music's own → album's
				if mc, ok := musicData["color"].(string); !ok || mc == "" {
					if album, ok := musicData["album"].(bson.M); ok {
						if ac, ok := album["color"].(string); ok {
							musicData["color"] = ac
						}
					}
				}

				// Artist/Album names
				artistName := ""
				if artist, ok := musicData["artist"].(bson.M); ok {
					if n, ok := artist["name"].(string); ok {
						artistName = n
					}
				}
				musicData["artistName"] = artistName

				albumName := ""
				if album, ok := musicData["album"].(bson.M); ok {
					if n, ok := album["name"].(string); ok {
						albumName = n
					}
				}
				musicData["albumName"] = albumName

				musicData["url"] = os.Getenv("SERVER_URL") + musics[i]["url"].(string)

				if includeLyrics {
					lyricsPath := fmt.Sprintf("./uploads/lyrics/%s.lrc", musics[i]["_id"].(primitive.ObjectID).Hex())

					if _, err := os.Stat(lyricsPath); err == nil {
						lyrics, err := parseLRC(lyricsPath)
						if err != nil {
							fmt.Println("Erro ao ler o arquivo LRC:", err)
						} else {
							musicData["lyrics"] = lyrics
						}
					}
				}

				delete(musicData, "album")
				delete(musicData, "artist")

				results = append(results, bson.M{
					"name":        musics[i]["name"],
					"type":        "music",
					"id":          musics[i]["_id"],
					"description": "Música · " + artistName,
					"music":       musicData,
					"imageUrl":    coverUrl,
				})
			}
		}

		sort.Slice(results, func(i, j int) bool {
			return results[i]["name"].(string) < results[j]["name"].(string)
		})

		if skip >= len(results) {
			results = []bson.M{}
		} else {
			end := skip + limitInt
			if end > len(results) {
				end = len(results)
			}
			results = results[skip:end]
		}

		c.JSON(http.StatusOK, gin.H{
			"results": results,
			"pagination": gin.H{
				"page":    pageInt,
				"limit":   limitInt,
				"total":   totalResults,
				"hasMore": int64(skip+len(results)) < totalResults,
			},
		})
	}
}

func parsePositiveQueryInt(raw string, fallback, max int) int {
	value, err := strconv.Atoi(raw)
	if err != nil || value < 1 {
		return fallback
	}
	if value > max {
		return max
	}
	return value
}
