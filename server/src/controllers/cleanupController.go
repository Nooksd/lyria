package controllers

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	database "server/src/db"

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo/options"
)

type orphanFile struct {
	Path     string `json:"path"`
	Category string `json:"category"`
	Size     int64  `json:"size"`
}

type cleanupScanResult struct {
	Orphans    []orphanFile `json:"orphans"`
	TotalSize  int64        `json:"totalSize"`
	TotalFiles int          `json:"totalFiles"`
	ByCategory map[string]struct {
		Files int   `json:"files"`
		Size  int64 `json:"size"`
	} `json:"byCategory"`
}

// ScanOrphanFiles scans upload directories for files that have no matching DB object.
func ScanOrphanFiles() gin.HandlerFunc {
	return func(c *gin.Context) {
		result, err := scanOrphans()
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusOK, result)
	}
}

// CleanOrphanFiles deletes orphan files found by the scan.
func CleanOrphanFiles() gin.HandlerFunc {
	return func(c *gin.Context) {
		result, err := scanOrphans()
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao escanear: " + err.Error()})
			return
		}

		deleted := 0
		freedBytes := int64(0)
		var errors []string

		for _, o := range result.Orphans {
			if err := os.Remove(o.Path); err != nil {
				errors = append(errors, fmt.Sprintf("%s: %s", o.Path, err.Error()))
			} else {
				deleted++
				freedBytes += o.Size
			}
		}

		c.JSON(http.StatusOK, gin.H{
			"deleted":    deleted,
			"freedBytes": freedBytes,
			"errors":     errors,
		})
	}
}

func scanOrphans() (*cleanupScanResult, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Load all known IDs from DB
	musicIDs, err := loadIDSet(ctx, "musics")
	if err != nil {
		return nil, fmt.Errorf("erro ao carregar músicas: %w", err)
	}
	artistIDs, err := loadIDSet(ctx, "artists")
	if err != nil {
		return nil, fmt.Errorf("erro ao carregar artistas: %w", err)
	}
	albumIDs, err := loadIDSet(ctx, "albums")
	if err != nil {
		return nil, fmt.Errorf("erro ao carregar álbuns: %w", err)
	}

	var orphans []orphanFile

	// Define scan rules: directory → category → which ID set to check
	type scanRule struct {
		dir      string
		category string
		ids      map[string]bool
	}

	rules := []scanRule{
		{"uploads/music", "music", musicIDs},
		{"uploads/image/avatar", "avatar", artistIDs},
		{"uploads/image/banner", "banner", artistIDs},
		{"uploads/image/cover", "cover", albumIDs},
		{"uploads/image/music_cover", "music_cover", musicIDs},
		{"uploads/lyrics", "lyrics", musicIDs},
	}

	for _, rule := range rules {
		entries, err := os.ReadDir(rule.dir)
		if err != nil {
			if os.IsNotExist(err) {
				continue
			}
			return nil, fmt.Errorf("erro ao ler %s: %w", rule.dir, err)
		}

		for _, entry := range entries {
			if entry.IsDir() {
				continue
			}

			name := entry.Name()
			ext := filepath.Ext(name)
			hexID := strings.TrimSuffix(name, ext)

			// Validate it looks like a hex ObjectID
			if _, err := primitive.ObjectIDFromHex(hexID); err != nil {
				continue // Not an ObjectID-named file, skip
			}

			if !rule.ids[hexID] {
				info, err := entry.Info()
				if err != nil {
					continue
				}
				orphans = append(orphans, orphanFile{
					Path:     filepath.Join(rule.dir, name),
					Category: rule.category,
					Size:     info.Size(),
				})
			}
		}
	}

	// Build summary
	result := &cleanupScanResult{
		Orphans:    orphans,
		TotalFiles: len(orphans),
		ByCategory: make(map[string]struct {
			Files int   `json:"files"`
			Size  int64 `json:"size"`
		}),
	}

	for _, o := range orphans {
		result.TotalSize += o.Size
		cat := result.ByCategory[o.Category]
		cat.Files++
		cat.Size += o.Size
		result.ByCategory[o.Category] = cat
	}

	if result.Orphans == nil {
		result.Orphans = []orphanFile{}
	}

	return result, nil
}

func loadIDSet(ctx context.Context, collectionName string) (map[string]bool, error) {
	col := database.OpenCollection(database.Client, collectionName)
	cursor, err := col.Find(ctx, bson.M{}, options.Find().SetProjection(bson.M{"_id": 1}))
	if err != nil {
		return nil, err
	}
	defer cursor.Close(ctx)

	ids := make(map[string]bool)
	for cursor.Next(ctx) {
		var doc struct {
			ID primitive.ObjectID `bson:"_id"`
		}
		if cursor.Decode(&doc) == nil {
			ids[doc.ID.Hex()] = true
		}
	}
	return ids, nil
}
