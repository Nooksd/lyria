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
	"strings"
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

const (
	fpSampleRate   = 8000
	fpFFTSize      = 1024
	fpHopSize      = 512
	fpTargetZone   = 5
	fpMaxFreqBits  = 9
	fpMaxDeltaBits = 14
	fpFreqScale    = 10.0
	fpOffsetBucket = 100
	fpMatchThresh  = 4
)

var fpBands = [][2]int{
	{0, 10},
	{10, 20},
	{20, 40},
	{40, 80},
	{80, 160},
	{160, 512},
}

var fingerprintCollection *mongo.Collection

func init() {
	fingerprintCollection = database.OpenCollection(database.Client, "fingerprints")
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	fingerprintCollection.Indexes().CreateOne(ctx, mongo.IndexModel{
		Keys:    bson.D{{Key: "hash", Value: 1}},
		Options: options.Index().SetBackground(true),
	})
	fingerprintCollection.Indexes().CreateOne(ctx, mongo.IndexModel{
		Keys:    bson.D{{Key: "musicId", Value: 1}},
		Options: options.Index().SetBackground(true),
	})
}

type fpPeak struct {
	FreqHz float64
	TimeMs float64
}

type fpHash struct {
	Address uint32
	TimeMs  uint32
}

func extractPCM8k(audioPath string) ([]float64, error) {
	cmd := exec.Command("ffmpeg",
		"-i", audioPath,
		"-ar", "8000",
		"-ac", "1",
		"-f", "s16le",
		"-acodec", "pcm_s16le",
		"-",
	)
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		return nil, fmt.Errorf("ffmpeg failed: %w - %s", err, stderr.String())
	}
	raw := stdout.Bytes()
	if len(raw) < 2 {
		return nil, fmt.Errorf("ffmpeg produced no audio data")
	}
	samples := make([]float64, len(raw)/2)
	for i := 0; i < len(raw)-1; i += 2 {
		sample := int16(raw[i]) | int16(raw[i+1])<<8
		samples[i/2] = float64(sample) / 32768.0
	}
	return samples, nil
}

func fpComputeSpectrogram(samples []float64) [][]float64 {
	window := make([]float64, fpFFTSize)
	for i := range window {
		window[i] = 0.5 * (1 - math.Cos(2*math.Pi*float64(i)/float64(fpFFTSize-1)))
	}
	fft := fourier.NewFFT(fpFFTSize)
	numBins := fpFFTSize / 2
	numFrames := 0
	if len(samples) >= fpFFTSize {
		numFrames = (len(samples)-fpFFTSize)/fpHopSize + 1
	}
	if numFrames == 0 {
		return nil
	}
	spectrogram := make([][]float64, numFrames)
	frame := make([]float64, fpFFTSize)
	for i := 0; i < numFrames; i++ {
		start := i * fpHopSize
		for j := 0; j < fpFFTSize; j++ {
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

func fpExtractPeaks(spectrogram [][]float64) []fpPeak {
	if len(spectrogram) == 0 {
		return nil
	}
	freqResolution := float64(fpSampleRate) / float64(fpFFTSize)
	frameDurationMs := float64(fpHopSize) * 1000.0 / float64(fpSampleRate)
	var peaks []fpPeak
	for frameIdx, frame := range spectrogram {
		type bandMax struct {
			mag    float64
			binIdx int
		}
		var bandMaxes []bandMax
		for _, band := range fpBands {
			lo, hi := band[0], band[1]
			if hi > len(frame) {
				hi = len(frame)
			}
			if lo >= hi {
				continue
			}
			best := bandMax{mag: -1, binIdx: lo}
			for b := lo; b < hi; b++ {
				if frame[b] > best.mag {
					best.mag = frame[b]
					best.binIdx = b
				}
			}
			if best.mag > 0 {
				bandMaxes = append(bandMaxes, best)
			}
		}
		if len(bandMaxes) == 0 {
			continue
		}
		avgMag := 0.0
		for _, bm := range bandMaxes {
			avgMag += bm.mag
		}
		avgMag /= float64(len(bandMaxes))
		for _, bm := range bandMaxes {
			if bm.mag > avgMag {
				peaks = append(peaks, fpPeak{
					FreqHz: float64(bm.binIdx) * freqResolution,
					TimeMs: float64(frameIdx) * frameDurationMs,
				})
			}
		}
	}
	return peaks
}

func fpCreateAddress(anchor, target fpPeak) uint32 {
	anchorFreqBin := uint32(anchor.FreqHz / fpFreqScale)
	targetFreqBin := uint32(target.FreqHz / fpFreqScale)
	deltaMs := uint32(target.TimeMs - anchor.TimeMs)
	anchorBits := anchorFreqBin & ((1 << fpMaxFreqBits) - 1)
	targetBits := targetFreqBin & ((1 << fpMaxFreqBits) - 1)
	deltaBits := deltaMs & ((1 << fpMaxDeltaBits) - 1)
	return (anchorBits << (fpMaxFreqBits + fpMaxDeltaBits)) | (targetBits << fpMaxDeltaBits) | deltaBits
}

func fpFingerprint(peaks []fpPeak) []fpHash {
	var hashes []fpHash
	for i, anchor := range peaks {
		limit := i + 1 + fpTargetZone
		if limit > len(peaks) {
			limit = len(peaks)
		}
		for j := i + 1; j < limit; j++ {
			target := peaks[j]
			address := fpCreateAddress(anchor, target)
			hashes = append(hashes, fpHash{
				Address: address,
				TimeMs:  uint32(anchor.TimeMs),
			})
		}
	}
	return hashes
}

func GenerateFingerprints(audioPath string, musicID primitive.ObjectID) error {
	samples, err := extractPCM8k(audioPath)
	if err != nil {
		return fmt.Errorf("PCM extraction: %w", err)
	}
	if len(samples) < fpFFTSize {
		return fmt.Errorf("audio too short (%d samples)", len(samples))
	}
	spectrogram := fpComputeSpectrogram(samples)
	peaks := fpExtractPeaks(spectrogram)
	hashes := fpFingerprint(peaks)
	if len(hashes) == 0 {
		return fmt.Errorf("no hashes generated (peaks: %d)", len(peaks))
	}
	ctx, cancel := context.WithTimeout(context.Background(), 120*time.Second)
	defer cancel()
	fingerprintCollection.DeleteMany(ctx, bson.M{"musicId": musicID})
	const batchSize = 5000
	docs := make([]interface{}, 0, batchSize)
	for _, h := range hashes {
		docs = append(docs, bson.M{
			"hash":    h.Address,
			"musicId": musicID,
			"offset":  h.TimeMs,
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
			return fmt.Errorf("final insert: %w", err)
		}
	}
	log.Printf("[Fingerprint] %d hashes (%d peaks) for %s", len(hashes), len(peaks), musicID.Hex())
	return nil
}

func IdentifyMusic() gin.HandlerFunc {
	return func(c *gin.Context) {
		file, err := c.FormFile("audio")
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Arquivo de audio necessario"})
			return
		}
		tmpFile, err := os.CreateTemp("", "identify-*.wav")
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Falha ao criar arquivo temporario"})
			return
		}
		tmpPath := tmpFile.Name()
		tmpFile.Close()
		defer os.Remove(tmpPath)
		if err := c.SaveUploadedFile(file, tmpPath); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Falha ao salvar audio"})
			return
		}
		samples, err := extractPCM8k(tmpPath)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Falha ao processar audio: " + err.Error()})
			return
		}
		if len(samples) < fpFFTSize {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Audio muito curto"})
			return
		}
		spectrogram := fpComputeSpectrogram(samples)
		peaks := fpExtractPeaks(spectrogram)
		sampleHashes := fpFingerprint(peaks)
		if len(sampleHashes) == 0 {
			c.JSON(http.StatusNotFound, gin.H{"error": "Nenhuma impressao digital extraida"})
			return
		}
		log.Printf("[Identify] Sample: %d samples, %d peaks, %d hashes", len(samples), len(peaks), len(sampleHashes))
		sampleFP := make(map[uint32]uint32)
		for _, h := range sampleHashes {
			sampleFP[h.Address] = h.TimeMs
		}
		addressList := make([]uint32, 0, len(sampleFP))
		for addr := range sampleFP {
			addressList = append(addressList, addr)
		}
		log.Printf("[Identify] Looking up %d unique addresses", len(addressList))
		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()
		const chunkSize = 10000
		type dbFP struct {
			Hash    uint32             `bson:"hash"`
			MusicID primitive.ObjectID `bson:"musicId"`
			Offset  uint32             `bson:"offset"`
		}
		histogram := make(map[primitive.ObjectID]map[int32]int)
		totalDBMatches := 0
		for start := 0; start < len(addressList); start += chunkSize {
			end := start + chunkSize
			if end > len(addressList) {
				end = len(addressList)
			}
			chunk := addressList[start:end]
			cursor, err := fingerprintCollection.Find(ctx, bson.M{"hash": bson.M{"$in": chunk}})
			if err != nil {
				log.Printf("[Identify] DB error: %v", err)
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Falha na busca"})
				return
			}
			for cursor.Next(ctx) {
				var fp dbFP
				if err := cursor.Decode(&fp); err != nil {
					continue
				}
				sampleTime, ok := sampleFP[fp.Hash]
				if !ok {
					continue
				}
				totalDBMatches++
				delta := int32(fp.Offset) - int32(sampleTime)
				bucket := delta / int32(fpOffsetBucket)
				if histogram[fp.MusicID] == nil {
					histogram[fp.MusicID] = make(map[int32]int)
				}
				histogram[fp.MusicID][bucket]++
			}
			cursor.Close(ctx)
		}
		log.Printf("[Identify] DB matches: %d, candidates: %d", totalDBMatches, len(histogram))
		var bestMusicID primitive.ObjectID
		bestScore := 0
		for musicID, buckets := range histogram {
			for _, count := range buckets {
				if count > bestScore {
					bestScore = count
					bestMusicID = musicID
				}
			}
		}
		log.Printf("[Identify] Best score: %d (thresh: %d), music: %s", bestScore, fpMatchThresh, bestMusicID.Hex())
		if bestScore < fpMatchThresh {
			c.JSON(http.StatusNotFound, gin.H{
				"error":   "Musica nao identificada",
				"score":   bestScore,
				"message": "Nenhuma correspondencia encontrada.",
			})
			return
		}
		musicResult, err := loadMusicWithDetails(ctx, bestMusicID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Falha ao carregar musica"})
			return
		}
		c.JSON(http.StatusOK, gin.H{"music": musicResult, "score": bestScore})
	}
}

func loadMusicWithDetails(ctx context.Context, musicID primitive.ObjectID) (bson.M, error) {
	pipeline := []bson.M{
		{"$match": bson.M{"_id": musicID}},
		{"$lookup": bson.M{"from": "albums", "localField": "albumId", "foreignField": "_id", "as": "album"}},
		{"$unwind": bson.M{"path": "$album", "preserveNullAndEmptyArrays": true}},
		{"$lookup": bson.M{"from": "artists", "localField": "artistId", "foreignField": "_id", "as": "artist"}},
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
	if mc, ok := musicData["color"].(string); !ok || mc == "" {
		if album, ok := musicData["album"].(bson.M); ok {
			if ac, ok := album["color"].(string); ok {
				musicData["color"] = ac
			}
		}
	}
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
	musicData["url"] = os.Getenv("SERVER_URL") + musicData["url"].(string)
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

var fingerprintAllRunning bool
var fingerprintAllMu sync.Mutex
var fingerprintAllProgress struct {
	Total     int  `json:"total"`
	Processed int  `json:"processed"`
	Failed    int  `json:"failed"`
	Running   bool `json:"running"`
}

func GenerateAllFingerprints() gin.HandlerFunc {
	return func(c *gin.Context) {
		fingerprintAllMu.Lock()
		if fingerprintAllRunning {
			fingerprintAllMu.Unlock()
			c.JSON(http.StatusConflict, gin.H{"error": "Ja em andamento", "progress": fingerprintAllProgress})
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
			cursor, err := musicCollection.Find(ctx, bson.M{})
			if err != nil {
				log.Printf("[Fingerprint] Failed to list music: %v", err)
				return
			}
			var musics []bson.M
			if err := cursor.All(ctx, &musics); err != nil {
				log.Printf("[Fingerprint] Failed to decode: %v", err)
				return
			}
			fingerprintAllMu.Lock()
			fingerprintAllProgress = struct {
				Total     int  `json:"total"`
				Processed int  `json:"processed"`
				Failed    int  `json:"failed"`
				Running   bool `json:"running"`
			}{Total: len(musics), Processed: 0, Failed: 0, Running: true}
			fingerprintAllMu.Unlock()
			for _, m := range musics {
				musicID := m["_id"].(primitive.ObjectID)
				urlStr, ok := m["url"].(string)
				if !ok {
					fingerprintAllMu.Lock()
					fingerprintAllProgress.Failed++
					fingerprintAllProgress.Processed++
					fingerprintAllMu.Unlock()
					continue
				}
				audioPath := "." + urlStr
				if _, err := os.Stat(audioPath); os.IsNotExist(err) {
					log.Printf("[Fingerprint] Not found: %s", audioPath)
					fingerprintAllMu.Lock()
					fingerprintAllProgress.Failed++
					fingerprintAllProgress.Processed++
					fingerprintAllMu.Unlock()
					continue
				}
				if err := GenerateFingerprints(audioPath, musicID); err != nil {
					log.Printf("[Fingerprint] Failed %s: %v", musicID.Hex(), err)
					fingerprintAllMu.Lock()
					fingerprintAllProgress.Failed++
					fingerprintAllMu.Unlock()
				}
				fingerprintAllMu.Lock()
				fingerprintAllProgress.Processed++
				fingerprintAllMu.Unlock()
			}
			log.Printf("[Fingerprint] Done. Total: %d, Failed: %d", fingerprintAllProgress.Total, fingerprintAllProgress.Failed)
		}()
		c.JSON(http.StatusOK, gin.H{"message": "Geracao iniciada", "total": fingerprintAllProgress.Total})
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
		distinctMusics, _ := fingerprintCollection.Distinct(ctx, "musicId", bson.M{})
		c.JSON(http.StatusOK, gin.H{
			"progress":            progress,
			"totalFingerprints":   totalFP,
			"musicsFingerprinted": len(distinctMusics),
		})
	}
}
