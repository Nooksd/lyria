package controllers

import (
	"bytes"
	"context"
	"fmt"
	"log"
	"math"
	"math/cmplx"
	"net/http"
	"os"
	"os/exec"
	"sync"
	"time"

	database "server/src/db"

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
	"gonum.org/v1/gonum/dsp/fourier"
)

// ──────────────────────────────────────────────
// Constants — based on Wang 2003 (Shazam paper)
// ──────────────────────────────────────────────

const (
	fpSampleRate = 8000  // Hz – phone-quality, sufficient for fingerprinting
	fftSize      = 1024  // samples per window → 128 ms at 8 kHz
	hopSize      = 256   // 75 % overlap → 32 ms advance per frame
	maxFreqBin   = 512   // Nyquist bin index for 1024-point real FFT
	peaksPerBand = 3     // max peaks extracted per frequency band per frame
	fanOut       = 15    // target points paired with each anchor
	targetStart  = 2     // frames ahead — start of target zone
	targetEnd    = 50    // frames ahead — end of target zone
	matchThresh  = 8     // minimum aligned hashes to declare a match
)

// Frequency bands for peak detection (bin ranges at 8 kHz / 1024-pt FFT ≈ 7.8 Hz/bin)
var freqBands = [][2]int{
	{1, 10},    // ~8 – 78 Hz
	{10, 25},   // ~78 – 195 Hz
	{25, 50},   // ~195 – 390 Hz
	{50, 100},  // ~390 – 781 Hz
	{100, 200}, // ~781 – 1562 Hz
	{200, 512}, // ~1562 – 4000 Hz
}

var fingerprintCollection *mongo.Collection

func init() {
	fingerprintCollection = database.OpenCollection(database.Client, "fingerprints")

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// Compound index on hash for fast lookups
	fingerprintCollection.Indexes().CreateOne(ctx, mongo.IndexModel{
		Keys:    bson.D{{Key: "hash", Value: 1}},
		Options: options.Index().SetBackground(true),
	})

	// Index on musicId for deletion / re-generation
	fingerprintCollection.Indexes().CreateOne(ctx, mongo.IndexModel{
		Keys:    bson.D{{Key: "musicId", Value: 1}},
		Options: options.Index().SetBackground(true),
	})
}

// ──────────────────────────────────────────────
// DSP helpers
// ──────────────────────────────────────────────

// hanningWindow pre-computes a Hanning window of length n.
func hanningWindow(n int) []float64 {
	w := make([]float64, n)
	for i := range w {
		w[i] = 0.5 * (1 - math.Cos(2*math.Pi*float64(i)/float64(n-1)))
	}
	return w
}

// peak represents a spectrogram peak (time frame + frequency bin).
type peak struct {
	frame int
	bin   int
}

// extractPCM8k uses ffmpeg to decode any audio file into raw PCM: 8 kHz, mono, s16le.
func extractPCM8k(audioPath string) ([]float64, error) {
	cmd := exec.Command("/usr/bin/ffmpeg",
		"-i", audioPath,
		"-ar", "8000",
		"-ac", "1",
		"-f", "s16le",
		"-acodec", "pcm_s16le",
		"-",
	)
	var out bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = nil // discard ffmpeg logs
	if err := cmd.Run(); err != nil {
		return nil, fmt.Errorf("ffmpeg PCM extraction failed: %w", err)
	}

	raw := out.Bytes()
	samples := make([]float64, len(raw)/2)
	for i := 0; i < len(raw)-1; i += 2 {
		sample := int16(raw[i]) | int16(raw[i+1])<<8
		samples[i/2] = float64(sample) / 32768.0
	}
	return samples, nil
}

// computeSpectrogram runs STFT and returns magnitude spectrogram (frames × freqBins).
func computeSpectrogram(samples []float64) [][]float64 {
	window := hanningWindow(fftSize)
	fft := fourier.NewFFT(fftSize)
	numBins := fftSize/2 + 1

	numFrames := 0
	if len(samples) > fftSize {
		numFrames = (len(samples)-fftSize)/hopSize + 1
	}
	if numFrames == 0 {
		return nil
	}

	spectrogram := make([][]float64, numFrames)
	frame := make([]float64, fftSize)

	for i := 0; i < numFrames; i++ {
		start := i * hopSize
		// Apply Hanning window
		for j := 0; j < fftSize; j++ {
			frame[j] = samples[start+j] * window[j]
		}
		coeffs := fft.Coefficients(nil, frame)
		mag := make([]float64, numBins)
		for k := 0; k < numBins; k++ {
			mag[k] = cmplx.Abs(coeffs[k])
		}
		spectrogram[i] = mag
	}
	return spectrogram
}

// findPeaks extracts constellation-map peaks from a spectrogram.
func findPeaks(spectrogram [][]float64) []peak {
	numFrames := len(spectrogram)
	if numFrames == 0 {
		return nil
	}

	var peaks []peak

	for f := 0; f < numFrames; f++ {
		mag := spectrogram[f]

		for _, band := range freqBands {
			lo, hi := band[0], band[1]
			if hi > len(mag) {
				hi = len(mag)
			}
			if lo >= hi {
				continue
			}

			// Collect local maxima in this band
			type candidate struct {
				bin int
				val float64
			}
			var cands []candidate

			for b := lo; b < hi; b++ {
				val := mag[b]
				if val < 1e-6 {
					continue
				}
				// Must be a local max in frequency dimension
				if b > lo && mag[b-1] >= val {
					continue
				}
				if b < hi-1 && mag[b+1] >= val {
					continue
				}
				// Must be a local max in time dimension (±1 frame)
				if f > 0 && spectrogram[f-1][b] >= val {
					continue
				}
				if f < numFrames-1 && spectrogram[f+1][b] >= val {
					continue
				}
				cands = append(cands, candidate{bin: b, val: val})
			}

			// Keep top peaksPerBand candidates
			for n := 0; n < peaksPerBand && n < len(cands); n++ {
				best := n
				for m := n + 1; m < len(cands); m++ {
					if cands[m].val > cands[best].val {
						best = m
					}
				}
				cands[n], cands[best] = cands[best], cands[n]
				peaks = append(peaks, peak{frame: f, bin: cands[n].bin})
			}
		}
	}
	return peaks
}

// hashPeaks creates combinatorial hashes from a constellation map.
// Hash packing: bits [29:20] = f_anchor, [19:10] = f_target, [9:0] = delta_t
func hashPeaks(peaks []peak) []struct {
	hash   uint32
	offset uint32
} {
	type entry struct {
		hash   uint32
		offset uint32 // anchor frame
	}
	var hashes []entry

	for i := 0; i < len(peaks); i++ {
		anchor := peaks[i]
		paired := 0
		for j := i + 1; j < len(peaks) && paired < fanOut; j++ {
			target := peaks[j]
			dt := target.frame - anchor.frame
			if dt < targetStart {
				continue
			}
			if dt > targetEnd {
				break
			}
			h := uint32(anchor.bin&0x3FF)<<20 | uint32(target.bin&0x3FF)<<10 | uint32(dt&0x3FF)
			hashes = append(hashes, entry{hash: h, offset: uint32(anchor.frame)})
			paired++
		}
	}
	return hashes
}

// ──────────────────────────────────────────────
// Public API
// ──────────────────────────────────────────────

// GenerateFingerprints extracts audio fingerprints from a music file
// and stores them in MongoDB. Safe to call multiple times — deletes old
// fingerprints for the same musicID first.
func GenerateFingerprints(audioPath string, musicID primitive.ObjectID) error {
	samples, err := extractPCM8k(audioPath)
	if err != nil {
		return fmt.Errorf("PCM extraction: %w", err)
	}
	if len(samples) < fftSize {
		return fmt.Errorf("audio too short for fingerprinting (%d samples)", len(samples))
	}

	spectrogram := computeSpectrogram(samples)
	peaks := findPeaks(spectrogram)
	hashes := hashPeaks(peaks)

	if len(hashes) == 0 {
		return fmt.Errorf("no fingerprint hashes generated")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	// Remove old fingerprints for this music
	fingerprintCollection.DeleteMany(ctx, bson.M{"musicId": musicID})

	// Batch insert
	const batchSize = 5000
	docs := make([]interface{}, 0, batchSize)
	for _, h := range hashes {
		docs = append(docs, bson.M{
			"hash":    h.hash,
			"musicId": musicID,
			"offset":  h.offset,
		})
		if len(docs) >= batchSize {
			if _, err := fingerprintCollection.InsertMany(ctx, docs); err != nil {
				return fmt.Errorf("batch insert: %w", err)
			}
			docs = docs[:0]
		}
	}
	if len(docs) > 0 {
		if _, err := fingerprintCollection.InsertMany(ctx, docs); err != nil {
			return fmt.Errorf("final batch insert: %w", err)
		}
	}

	log.Printf("[Fingerprint] Generated %d hashes for music %s", len(hashes), musicID.Hex())
	return nil
}

// ──────────────────────────────────────────────
// Identify endpoint — POST /music/identify
// ──────────────────────────────────────────────

func IdentifyMusic() gin.HandlerFunc {
	return func(c *gin.Context) {
		file, err := c.FormFile("audio")
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Arquivo de áudio necessário"})
			return
		}

		// Save to temp file
		tmpFile, err := os.CreateTemp("", "identify-*.wav")
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Falha ao criar arquivo temporário"})
			return
		}
		tmpPath := tmpFile.Name()
		tmpFile.Close()
		defer os.Remove(tmpPath)

		if err := c.SaveUploadedFile(file, tmpPath); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Falha ao salvar áudio"})
			return
		}

		// Extract PCM and fingerprint the sample
		samples, err := extractPCM8k(tmpPath)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Falha ao processar áudio: " + err.Error()})
			return
		}
		if len(samples) < fftSize {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Áudio muito curto para identificação"})
			return
		}

		spectrogram := computeSpectrogram(samples)
		peaks := findPeaks(spectrogram)
		sampleHashes := hashPeaks(peaks)

		if len(sampleHashes) == 0 {
			c.JSON(http.StatusNotFound, gin.H{"error": "Nenhuma impressão digital extraída do áudio"})
			return
		}

		// Collect unique hashes for DB lookup
		hashSet := make(map[uint32]bool)
		for _, h := range sampleHashes {
			hashSet[h.hash] = true
		}
		hashList := make([]uint32, 0, len(hashSet))
		for h := range hashSet {
			hashList = append(hashList, h)
		}

		ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
		defer cancel()

		// Bulk lookup
		cursor, err := fingerprintCollection.Find(ctx, bson.M{
			"hash": bson.M{"$in": hashList},
		})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Falha na busca de impressões digitais"})
			return
		}
		defer cursor.Close(ctx)

		// Build map: hash → sample offsets
		sampleOffsets := make(map[uint32][]uint32)
		for _, h := range sampleHashes {
			sampleOffsets[h.hash] = append(sampleOffsets[h.hash], h.offset)
		}

		// Histogram matching: for each (musicId, delta) count aligned hashes
		type matchKey struct {
			musicID primitive.ObjectID
			delta   int32
		}
		histogram := make(map[matchKey]int)
		musicBest := make(map[primitive.ObjectID]int) // best score per music

		for cursor.Next(ctx) {
			var fp struct {
				Hash    uint32             `bson:"hash"`
				MusicID primitive.ObjectID `bson:"musicId"`
				Offset  uint32             `bson:"offset"`
			}
			if err := cursor.Decode(&fp); err != nil {
				continue
			}

			offsets, ok := sampleOffsets[fp.Hash]
			if !ok {
				continue
			}
			for _, sOff := range offsets {
				delta := int32(fp.Offset) - int32(sOff)
				key := matchKey{musicID: fp.MusicID, delta: delta}
				histogram[key]++
				if histogram[key] > musicBest[fp.MusicID] {
					musicBest[fp.MusicID] = histogram[key]
				}
			}
		}

		// Find best match
		var bestMusicID primitive.ObjectID
		bestScore := 0
		for mid, score := range musicBest {
			if score > bestScore {
				bestScore = score
				bestMusicID = mid
			}
		}

		if bestScore < matchThresh {
			c.JSON(http.StatusNotFound, gin.H{
				"error":   "Música não identificada",
				"score":   bestScore,
				"message": "Nenhuma correspondência encontrada. Tente novamente com menos ruído.",
			})
			return
		}

		// Load full music document with artist/album info
		musicResult, err := loadMusicWithDetails(ctx, bestMusicID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Falha ao carregar dados da música"})
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"music": musicResult,
			"score": bestScore,
		})
	}
}

// loadMusicWithDetails fetches a music document and enriches it with artist/album names,
// matching the same format the search endpoint returns.
func loadMusicWithDetails(ctx context.Context, musicID primitive.ObjectID) (bson.M, error) {
	pipeline := []bson.M{
		{"$match": bson.M{"_id": musicID}},
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

	cursor, err := musicCollection.Aggregate(ctx, pipeline)
	if err != nil {
		return nil, err
	}
	defer cursor.Close(ctx)

	if !cursor.Next(ctx) {
		return nil, fmt.Errorf("music not found")
	}

	var musicData bson.M
	if err := cursor.Decode(&musicData); err != nil {
		return nil, err
	}

	// Cover URL
	coverUrl := ""
	if mc, ok := musicData["coverUrl"].(string); ok && mc != "" {
		if len(mc) > 4 && mc[:4] == "http" {
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

	// Color fallback to album
	if mc, ok := musicData["color"].(string); !ok || mc == "" {
		if album, ok := musicData["album"].(bson.M); ok {
			if ac, ok := album["color"].(string); ok {
				musicData["color"] = ac
			}
		}
	}

	// Artist name
	artistName := ""
	if artist, ok := musicData["artist"].(bson.M); ok {
		if n, ok := artist["name"].(string); ok {
			artistName = n
		}
	}
	musicData["artistName"] = artistName

	// Album name
	albumName := ""
	if album, ok := musicData["album"].(bson.M); ok {
		if n, ok := album["name"].(string); ok {
			albumName = n
		}
	}
	musicData["albumName"] = albumName

	musicData["url"] = os.Getenv("SERVER_URL") + musicData["url"].(string)

	// Lyrics
	lyricsPath := fmt.Sprintf("./uploads/lyrics/%s.lrc", musicID.Hex())
	if _, err := os.Stat(lyricsPath); err == nil {
		lyrics, err := parseLRC(lyricsPath)
		if err == nil {
			musicData["lyrics"] = lyrics
		}
	}

	delete(musicData, "album")
	delete(musicData, "artist")

	return musicData, nil
}

// ──────────────────────────────────────────────
// Admin: generate fingerprints for ALL existing music
// ──────────────────────────────────────────────

var fingerprintAllRunning bool
var fingerprintAllMu sync.Mutex
var fingerprintAllProgress struct {
	Total     int `json:"total"`
	Processed int `json:"processed"`
	Failed    int `json:"failed"`
	Running   bool `json:"running"`
}

func GenerateAllFingerprints() gin.HandlerFunc {
	return func(c *gin.Context) {
		fingerprintAllMu.Lock()
		if fingerprintAllRunning {
			fingerprintAllMu.Unlock()
			c.JSON(http.StatusConflict, gin.H{"error": "Geração de fingerprints já em andamento", "progress": fingerprintAllProgress})
			return
		}
		fingerprintAllRunning = true
		fingerprintAllMu.Unlock()

		go func() {
			defer func() {
				fingerprintAllMu.Lock()
				fingerprintAllRunning = false
				fingerprintAllProgress.Running = false
				fingerprintAllMu.Unlock()
			}()

			ctx := context.Background()

			// Count all music
			cursor, err := musicCollection.Find(ctx, bson.M{})
			if err != nil {
				log.Printf("[Fingerprint] Failed to list music: %v", err)
				return
			}
			var musics []bson.M
			if err := cursor.All(ctx, &musics); err != nil {
				log.Printf("[Fingerprint] Failed to decode music list: %v", err)
				return
			}

			fingerprintAllMu.Lock()
			fingerprintAllProgress = struct {
				Total     int `json:"total"`
				Processed int `json:"processed"`
				Failed    int `json:"failed"`
				Running   bool `json:"running"`
			}{Total: len(musics), Processed: 0, Failed: 0, Running: true}
			fingerprintAllMu.Unlock()

			for _, m := range musics {
				musicID := m["_id"].(primitive.ObjectID)

				// Check if fingerprints already exist
				count, _ := fingerprintCollection.CountDocuments(ctx, bson.M{"musicId": musicID})
				if count > 0 {
					fingerprintAllMu.Lock()
					fingerprintAllProgress.Processed++
					fingerprintAllMu.Unlock()
					continue
				}

				// Build audio path from URL field
				urlStr, ok := m["url"].(string)
				if !ok {
					fingerprintAllMu.Lock()
					fingerprintAllProgress.Failed++
					fingerprintAllProgress.Processed++
					fingerprintAllMu.Unlock()
					continue
				}
				// URL is like "/uploads/musics/<id>.m4a"
				audioPath := "." + urlStr

				if _, err := os.Stat(audioPath); os.IsNotExist(err) {
					log.Printf("[Fingerprint] File not found: %s", audioPath)
					fingerprintAllMu.Lock()
					fingerprintAllProgress.Failed++
					fingerprintAllProgress.Processed++
					fingerprintAllMu.Unlock()
					continue
				}

				if err := GenerateFingerprints(audioPath, musicID); err != nil {
					log.Printf("[Fingerprint] Failed for %s: %v", musicID.Hex(), err)
					fingerprintAllMu.Lock()
					fingerprintAllProgress.Failed++
					fingerprintAllMu.Unlock()
				}

				fingerprintAllMu.Lock()
				fingerprintAllProgress.Processed++
				fingerprintAllMu.Unlock()
			}

			log.Printf("[Fingerprint] Finished generating fingerprints for all music. Total: %d, Failed: %d",
				fingerprintAllProgress.Total, fingerprintAllProgress.Failed)
		}()

		c.JSON(http.StatusOK, gin.H{
			"message": "Geração de fingerprints iniciada em background",
			"total":   fingerprintAllProgress.Total,
		})
	}
}

func GetFingerprintStatus() gin.HandlerFunc {
	return func(c *gin.Context) {
		fingerprintAllMu.Lock()
		progress := fingerprintAllProgress
		fingerprintAllMu.Unlock()

		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		totalFP, _ := fingerprintCollection.CountDocuments(ctx, bson.M{})

		// Count distinct musicIds
		distinctMusics, _ := fingerprintCollection.Distinct(ctx, "musicId", bson.M{})

		c.JSON(http.StatusOK, gin.H{
			"progress":            progress,
			"totalFingerprints":   totalFP,
			"musicsFingerprinted": len(distinctMusics),
		})
	}
}
