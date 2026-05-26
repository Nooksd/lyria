package controllers

import (
	"context"
	"math"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"sync"
	"time"

	database "server/src/db"
	model "server/src/models"

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

const (
	recommendationModelVersion = "hybrid-v2"
	recommendationNeighborCap  = 80
)

var recommendationVectorsCollection *mongo.Collection = database.OpenCollection(database.Client, "recommendation_vectors")
var recommendationModelsCollection *mongo.Collection = database.OpenCollection(database.Client, "recommendation_models")
var recommendationJobsCollection *mongo.Collection = database.OpenCollection(database.Client, "recommendation_jobs")

type recommendationQueue struct {
	queue chan primitive.ObjectID
}

var (
	recommendationWorker     = &recommendationQueue{queue: make(chan primitive.ObjectID, 20)}
	recommendationEnqueueMu  sync.Mutex
	recommendationTrainingMu sync.Mutex
)

type recommendationRequest struct {
	Queue      []string `json:"queue"`
	Exclude    []string `json:"exclude"`
	PlaylistID string   `json:"playlistId"`
	Limit      int      `json:"limit"`
}

type recommendationCandidate struct {
	Music     bson.M
	Feature   map[string]float64
	Neighbors map[string]float64
	Norm      float64
	Score     float64
	ArtistID  string
	PlayCount int
}

type recommendationNeighbor struct {
	MusicID string  `bson:"musicId" json:"musicId"`
	Score   float64 `bson:"score" json:"score"`
}

func StartRecommendationWorker() {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	now := time.Now()
	recommendationJobsCollection.UpdateMany(
		ctx,
		bson.M{"status": "running"},
		bson.M{"$set": bson.M{
			"status":    "queued",
			"message":   "Servidor reiniciado; treino voltou para a fila.",
			"updatedAt": now,
		}},
	)

	cursor, err := recommendationJobsCollection.Find(
		ctx,
		bson.M{"status": "queued"},
		options.Find().SetSort(bson.M{"createdAt": 1}),
	)
	if err == nil {
		var jobs []model.RecommendationJob
		if cursor.All(ctx, &jobs) == nil {
			for _, job := range jobs {
				recommendationWorker.enqueue(job.ID)
			}
		}
	}

	go recommendationWorker.run()
}

func (q *recommendationQueue) enqueue(jobID primitive.ObjectID) {
	select {
	case q.queue <- jobID:
	default:
		go func() { q.queue <- jobID }()
	}
}

func (q *recommendationQueue) run() {
	for jobID := range q.queue {
		q.process(jobID)
	}
}

func (q *recommendationQueue) process(jobID primitive.ObjectID) {
	recommendationTrainingMu.Lock()
	defer recommendationTrainingMu.Unlock()

	ctx := context.Background()
	now := time.Now()
	_, err := recommendationJobsCollection.UpdateOne(
		ctx,
		bson.M{"_id": jobID, "status": "queued"},
		bson.M{"$set": bson.M{
			"status":    "running",
			"message":   "Iniciando treino do modelo.",
			"progress":  0,
			"total":     100,
			"percent":   0,
			"startedAt": now,
			"updatedAt": now,
		}},
	)
	if err != nil {
		return
	}

	stats, err := trainRecommendationModel(ctx, func(progress, total int, message string) {
		if total <= 0 {
			total = 100
		}
		if progress < 0 {
			progress = 0
		}
		if progress > total {
			progress = total
		}
		percent := int(math.Round((float64(progress) / float64(total)) * 100))
		update := bson.M{
			"progress":  progress,
			"total":     total,
			"percent":   percent,
			"updatedAt": time.Now(),
		}
		if message != "" {
			update["message"] = message
		}
		progressCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		recommendationJobsCollection.UpdateOne(progressCtx, bson.M{"_id": jobID}, bson.M{"$set": update})
		cancel()
	})

	finishedAt := time.Now()
	if err != nil {
		recommendationJobsCollection.UpdateOne(
			ctx,
			bson.M{"_id": jobID},
			bson.M{"$set": bson.M{
				"status":     "failed",
				"message":    "Treino falhou.",
				"error":      err.Error(),
				"updatedAt":  finishedAt,
				"finishedAt": finishedAt,
			}},
		)
		return
	}

	recommendationJobsCollection.UpdateOne(
		ctx,
		bson.M{"_id": jobID},
		bson.M{"$set": bson.M{
			"status":        "completed",
			"message":       "Modelo treinado com sucesso.",
			"progress":      100,
			"total":         100,
			"percent":       100,
			"catalogMusics": stats["catalogMusics"],
			"featureCount":  stats["featureCount"],
			"reusedVectors": stats["reusedVectors"],
			"playEvents":    stats["playEvents"],
			"playlists":     stats["playlists"],
			"modelVersion":  recommendationModelVersion,
			"updatedAt":     finishedAt,
			"finishedAt":    finishedAt,
		}},
	)
}

func enqueueRecommendationTraining(trigger string) (*model.RecommendationJob, error) {
	recommendationEnqueueMu.Lock()
	defer recommendationEnqueueMu.Unlock()

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	var existing model.RecommendationJob
	err := recommendationJobsCollection.FindOne(
		ctx,
		bson.M{"status": "queued"},
		options.FindOne().SetSort(bson.M{"createdAt": -1}),
	).Decode(&existing)
	if err == nil {
		return &existing, nil
	}

	err = recommendationJobsCollection.FindOne(
		ctx,
		bson.M{"status": "running"},
		options.FindOne().SetSort(bson.M{"createdAt": -1}),
	).Decode(&existing)
	if err == nil && trigger == "manual" {
		return &existing, nil
	}

	now := time.Now()
	job := model.RecommendationJob{
		ID:           primitive.NewObjectID(),
		Status:       "queued",
		Trigger:      trigger,
		Message:      "Aguardando treino.",
		Progress:     0,
		Total:        100,
		Percent:      0,
		ModelVersion: recommendationModelVersion,
		CreatedAt:    now,
		UpdatedAt:    now,
	}
	if _, err := recommendationJobsCollection.InsertOne(ctx, job); err != nil {
		return nil, err
	}
	recommendationWorker.enqueue(job.ID)
	return &job, nil
}

func enqueueRecommendationTrainingIfCatalogChanged(trigger string) {
	go func() {
		if _, err := enqueueRecommendationTraining(trigger); err != nil {
			return
		}
	}()
}

func RecommendNextMusic() gin.HandlerFunc {
	return func(c *gin.Context) {
		var body recommendationRequest
		if err := c.ShouldBindJSON(&body); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Dados invalidos"})
			return
		}

		musics, err := recommendMusics(c.Request.Context(), body.Queue, body.Exclude, 1)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao recomendar musica"})
			return
		}
		if len(musics) == 0 {
			c.JSON(http.StatusNotFound, gin.H{"error": "Nenhuma musica recomendada"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"music": musics[0]})
	}
}

func RecommendPlaylistMusics() gin.HandlerFunc {
	return func(c *gin.Context) {
		var body recommendationRequest
		if err := c.ShouldBindJSON(&body); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Dados invalidos"})
			return
		}

		queue := body.Queue
		if len(queue) == 0 && body.PlaylistID != "" {
			ids, err := getPlaylistMusicIDs(c.Request.Context(), body.PlaylistID)
			if err != nil {
				c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
				return
			}
			queue = ids
		}

		limit := body.Limit
		if limit <= 0 || limit > 30 {
			limit = 12
		}

		musics, err := recommendMusics(c.Request.Context(), queue, body.Exclude, limit)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao recomendar musicas"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"musics": musics})
	}
}

func RebuildRecommendationIndex() gin.HandlerFunc {
	return func(c *gin.Context) {
		job, err := enqueueRecommendationTraining("manual")
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Erro ao enfileirar treino"})
			return
		}

		c.JSON(http.StatusAccepted, gin.H{"job": job})
	}
}

func GetLatestRecommendationJob() gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(c.Request.Context(), 5*time.Second)
		defer cancel()

		var job model.RecommendationJob
		err := recommendationJobsCollection.FindOne(
			ctx,
			bson.M{},
			options.FindOne().SetSort(bson.M{"createdAt": -1}),
		).Decode(&job)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{"job": nil})
			return
		}
		c.JSON(http.StatusOK, gin.H{"job": job})
	}
}

func GetRecommendationJob() gin.HandlerFunc {
	return func(c *gin.Context) {
		id, err := primitive.ObjectIDFromHex(c.Param("jobId"))
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "ID invalido"})
			return
		}

		ctx, cancel := context.WithTimeout(c.Request.Context(), 5*time.Second)
		defer cancel()

		var job model.RecommendationJob
		if err := recommendationJobsCollection.FindOne(ctx, bson.M{"_id": id}).Decode(&job); err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Job nao encontrado"})
			return
		}
		c.JSON(http.StatusOK, gin.H{"job": job})
	}
}

func getPlaylistMusicIDs(ctx context.Context, playlistID string) ([]string, error) {
	objectID, err := primitive.ObjectIDFromHex(playlistID)
	if err != nil {
		return nil, err
	}

	dbCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	var playlist struct {
		Musics []primitive.ObjectID `bson:"musics"`
	}
	if err := playlistCollection.FindOne(dbCtx, bson.M{"_id": objectID}).Decode(&playlist); err != nil {
		return nil, err
	}

	ids := make([]string, 0, len(playlist.Musics))
	for _, id := range playlist.Musics {
		ids = append(ids, id.Hex())
	}
	return ids, nil
}

func trainRecommendationModel(ctx context.Context, reportProgress func(progress, total int, message string)) (gin.H, error) {
	if reportProgress == nil {
		reportProgress = func(int, int, string) {}
	}
	reportProgress(2, 100, "Carregando catalogo musical.")
	catalog, err := loadRecommendationCatalog(ctx)
	if err != nil {
		return nil, err
	}
	reportProgress(8, 100, "Extraindo caracteristicas das musicas.")

	playCounts := loadMusicPlayCounts(ctx)
	existingVectors := loadExistingRecommendationVectorDocs(ctx)
	rawVectors := make(map[string]map[string]float64, len(catalog))
	docFreq := map[string]int{}
	catalogByID := map[string]bson.M{}
	candidates := make([]recommendationCandidate, 0, len(catalog))
	reusedVectors := 0

	for idx, music := range catalog {
		id := objectIDHex(music["_id"])
		if id == "" {
			continue
		}
		musicUpdatedAt := asTime(music["updatedAt"])
		vector := map[string]float64{}
		if existing, ok := existingVectors[id]; ok && !musicUpdatedAt.IsZero() && asTime(existing["musicUpdatedAt"]).Equal(musicUpdatedAt) {
			vector = asFloatMap(existing["rawFeatures"])
			if len(vector) > 0 {
				reusedVectors++
			}
		}
		if len(vector) == 0 {
			vector = buildMusicFeatureVector(music)
		}
		rawVectors[id] = vector
		catalogByID[id] = music
		seen := map[string]bool{}
		for key := range vector {
			if !seen[key] {
				docFreq[key]++
				seen[key] = true
			}
		}
		if len(catalog) > 0 && (idx%25 == 0 || idx == len(catalog)-1) {
			progress := 8 + int(math.Round((float64(idx+1)/float64(len(catalog)))*17))
			reportProgress(progress, 100, "Vetorizando musicas novas e reutilizando as ja indexadas.")
		}
	}

	reportProgress(28, 100, "Aplicando pesos TF-IDF.")
	totalDocs := float64(len(rawVectors))
	for id, raw := range rawVectors {
		vector := map[string]float64{}
		for key, value := range raw {
			idf := math.Log(1+(totalDocs/(1+float64(docFreq[key])))) + 1
			vector[key] = value * idf
		}
		music := catalogByID[id]
		candidates = append(candidates, recommendationCandidate{
			Music:     music,
			Feature:   vector,
			Norm:      vectorNorm(vector),
			ArtistID:  objectIDHex(music["artistId"]),
			PlayCount: playCounts[id],
		})
	}

	reportProgress(36, 100, "Lendo playlists e sequencias de plays.")
	collab := loadCollaborativeSignals(ctx)
	reportProgress(45, 100, "Calculando vizinhos musicais.")
	neighborsByID := buildRecommendationNeighbors(candidates, collab, func(done, total int) {
		if total <= 0 {
			return
		}
		progress := 45 + int(math.Round((float64(done)/float64(total))*40))
		reportProgress(progress, 100, "Calculando similaridade entre musicas.")
	})

	reportProgress(88, 100, "Salvando modelo no MongoDB.")
	if err := recommendationVectorsCollection.Drop(ctx); err != nil {
		return nil, err
	}

	docs := make([]interface{}, 0, len(candidates))
	now := time.Now()
	for _, candidate := range candidates {
		id := objectIDHex(candidate.Music["_id"])
		neighbors := neighborsByID[id]
		docs = append(docs, bson.M{
			"_id":               id,
			"musicId":           id,
			"artistId":          candidate.ArtistID,
			"rawFeatures":       rawVectors[id],
			"features":          candidate.Feature,
			"norm":              candidate.Norm,
			"neighbors":         neighbors,
			"playCount":         candidate.PlayCount,
			"spotifyPopularity": asInt(candidate.Music["spotifyPopularity"]),
			"musicUpdatedAt":    candidate.Music["updatedAt"],
			"modelVersion":      recommendationModelVersion,
			"updatedAt":         now,
		})
	}
	if len(docs) > 0 {
		if _, err := recommendationVectorsCollection.InsertMany(ctx, docs); err != nil {
			return nil, err
		}
	}

	reportProgress(94, 100, "Criando indices do modelo.")
	_, _ = recommendationVectorsCollection.Indexes().CreateMany(ctx, []mongo.IndexModel{
		{Keys: bson.D{{Key: "musicId", Value: 1}}},
		{Keys: bson.D{{Key: "modelVersion", Value: 1}}},
	})

	totalPlays, _ := playEventsCollection.CountDocuments(ctx, bson.M{})
	totalPlaylists, _ := playlistCollection.CountDocuments(ctx, bson.M{})
	modelDoc := bson.M{
		"_id":            "current",
		"modelVersion":   recommendationModelVersion,
		"catalogMusics":  len(candidates),
		"featureCount":   len(docFreq),
		"playEvents":     totalPlays,
		"playlists":      totalPlaylists,
		"neighborCap":    recommendationNeighborCap,
		"reusedVectors":  reusedVectors,
		"trainedAt":      now,
		"collabItemRows": len(collab),
	}
	_, err = recommendationModelsCollection.UpdateOne(
		ctx,
		bson.M{"_id": "current"},
		bson.M{"$set": modelDoc},
		options.Update().SetUpsert(true),
	)
	if err != nil {
		return nil, err
	}

	reportProgress(100, 100, "Modelo treinado com sucesso.")
	return gin.H{
		"message":       "Modelo de recomendacao treinado",
		"modelVersion":  recommendationModelVersion,
		"catalogMusics": len(candidates),
		"featureCount":  len(docFreq),
		"playEvents":    totalPlays,
		"playlists":     totalPlaylists,
		"neighborCap":   recommendationNeighborCap,
		"reusedVectors": reusedVectors,
		"updatedAt":     now,
	}, nil
}

func loadExistingRecommendationVectorDocs(ctx context.Context) map[string]bson.M {
	result := map[string]bson.M{}
	cursor, err := recommendationVectorsCollection.Find(
		ctx,
		bson.M{"modelVersion": recommendationModelVersion},
		options.Find().SetProjection(bson.M{"rawFeatures": 1, "musicUpdatedAt": 1}),
	)
	if err != nil {
		return result
	}
	defer cursor.Close(ctx)

	for cursor.Next(ctx) {
		var doc bson.M
		if cursor.Decode(&doc) != nil {
			continue
		}
		id := objectIDHex(doc["_id"])
		if id != "" {
			result[id] = doc
		}
	}
	return result
}

func buildRecommendationNeighbors(candidates []recommendationCandidate, collab map[string]map[string]float64, progress func(done, total int)) map[string][]recommendationNeighbor {
	neighborsByID := map[string][]recommendationNeighbor{}
	for i := range candidates {
		leftID := objectIDHex(candidates[i].Music["_id"])
		ranked := make([]recommendationNeighbor, 0, len(candidates)-1)
		for j := range candidates {
			if i == j {
				continue
			}
			rightID := objectIDHex(candidates[j].Music["_id"])
			contentScore := 0.0
			if candidates[i].Norm > 0 && candidates[j].Norm > 0 {
				contentScore = dotProduct(candidates[i].Feature, candidates[j].Feature) / (candidates[i].Norm * candidates[j].Norm)
			}
			collabScore := collabScoreForPair(collab, leftID, rightID)
			score := (contentScore * 0.74) + (collabScore * 0.26)
			if candidates[i].ArtistID != "" && candidates[i].ArtistID == candidates[j].ArtistID {
				score += 0.03
			}
			if score <= 0 {
				continue
			}
			ranked = append(ranked, recommendationNeighbor{MusicID: rightID, Score: roundFloat(score, 6)})
		}

		sort.SliceStable(ranked, func(a, b int) bool {
			return ranked[a].Score > ranked[b].Score
		})
		if len(ranked) > recommendationNeighborCap {
			ranked = ranked[:recommendationNeighborCap]
		}
		neighborsByID[leftID] = ranked
		if progress != nil && (i%5 == 0 || i == len(candidates)-1) {
			progress(i+1, len(candidates))
		}
	}
	return neighborsByID
}

func loadCollaborativeSignals(ctx context.Context) map[string]map[string]float64 {
	signals := map[string]map[string]float64{}
	addPair := func(a, b string, weight float64) {
		if a == "" || b == "" || a == b {
			return
		}
		if signals[a] == nil {
			signals[a] = map[string]float64{}
		}
		if signals[b] == nil {
			signals[b] = map[string]float64{}
		}
		signals[a][b] += weight
		signals[b][a] += weight
	}

	playlistCursor, err := playlistCollection.Find(ctx, bson.M{}, options.Find().SetProjection(bson.M{"musics": 1}))
	if err == nil {
		defer playlistCursor.Close(ctx)
		for playlistCursor.Next(ctx) {
			var row struct {
				Musics []primitive.ObjectID `bson:"musics"`
			}
			if playlistCursor.Decode(&row) != nil {
				continue
			}
			ids := uniqueObjectIDStrings(row.Musics, 150)
			if len(ids) < 2 {
				continue
			}
			weight := 1 / math.Sqrt(float64(len(ids)))
			for i := 0; i < len(ids); i++ {
				for j := i + 1; j < len(ids); j++ {
					addPair(ids[i], ids[j], weight)
				}
			}
		}
	}

	playCursor, err := playEventsCollection.Find(
		ctx,
		bson.M{},
		options.Find().SetSort(bson.D{{Key: "userId", Value: 1}, {Key: "createdAt", Value: 1}}).SetProjection(bson.M{"musicId": 1, "userId": 1}),
	)
	if err == nil {
		defer playCursor.Close(ctx)
		currentUser := ""
		window := []string{}
		for playCursor.Next(ctx) {
			var row struct {
				MusicID primitive.ObjectID `bson:"musicId"`
				UserID  string             `bson:"userId"`
			}
			if playCursor.Decode(&row) != nil {
				continue
			}
			if row.UserID != currentUser {
				currentUser = row.UserID
				window = []string{}
			}
			id := row.MusicID.Hex()
			for distance, previous := range reverseWindow(window) {
				addPair(previous, id, 1/(1+float64(distance)))
			}
			window = append(window, id)
			if len(window) > 12 {
				window = window[len(window)-12:]
			}
		}
	}

	maxScore := 0.0
	for _, related := range signals {
		for _, score := range related {
			if score > maxScore {
				maxScore = score
			}
		}
	}
	if maxScore > 0 {
		for id, related := range signals {
			for otherID, score := range related {
				signals[id][otherID] = math.Log1p(score) / math.Log1p(maxScore)
			}
		}
	}

	return signals
}

func uniqueObjectIDStrings(ids []primitive.ObjectID, max int) []string {
	seen := map[string]bool{}
	result := make([]string, 0, len(ids))
	for _, id := range ids {
		if id.IsZero() {
			continue
		}
		hex := id.Hex()
		if seen[hex] {
			continue
		}
		seen[hex] = true
		result = append(result, hex)
		if max > 0 && len(result) >= max {
			break
		}
	}
	return result
}

func reverseWindow(window []string) []string {
	result := make([]string, 0, len(window))
	for i := len(window) - 1; i >= 0; i-- {
		result = append(result, window[i])
	}
	return result
}

func recommendMusics(ctx context.Context, queueIDs, extraExclude []string, limit int) ([]bson.M, error) {
	dbCtx, cancel := context.WithTimeout(ctx, 15*time.Second)
	defer cancel()

	playCounts := loadMusicPlayCounts(dbCtx)
	candidates, byID, trained, err := loadTrainedRecommendationCandidates(dbCtx)
	if err != nil {
		return nil, err
	}
	if !trained {
		candidates, byID, err = buildRealtimeRecommendationCandidates(dbCtx, playCounts)
		if err != nil {
			return nil, err
		}
	}
	if len(candidates) == 0 {
		return []bson.M{}, nil
	}

	excluded := map[string]bool{}
	for _, id := range queueIDs {
		if id != "" {
			excluded[id] = true
		}
	}
	for _, id := range extraExclude {
		if id != "" {
			excluded[id] = true
		}
	}

	profile := map[string]float64{}
	neighborScores := map[string]float64{}
	queueLen := len(queueIDs)
	for idx, id := range queueIDs {
		candidate, ok := byID[id]
		if !ok {
			continue
		}
		weight := 1.0
		if queueLen > 1 {
			weight = 0.45 + (0.55 * float64(idx+1) / float64(queueLen))
		}
		for key, value := range candidate.Feature {
			profile[key] += value * weight
		}
		for neighborID, score := range candidate.Neighbors {
			neighborScores[neighborID] += score * weight
		}
	}
	profileNorm := vectorNorm(profile)

	maxPlays := 0
	for _, count := range playCounts {
		if count > maxPlays {
			maxPlays = count
		}
	}

	recentArtists := map[string]bool{}
	start := len(queueIDs) - 5
	if start < 0 {
		start = 0
	}
	for _, id := range queueIDs[start:] {
		if candidate, ok := byID[id]; ok && candidate.ArtistID != "" {
			recentArtists[candidate.ArtistID] = true
		}
	}

	for i := range candidates {
		id := objectIDHex(candidates[i].Music["_id"])
		if excluded[id] {
			candidates[i].Score = math.Inf(-1)
			continue
		}

		score := 0.0
		if profileNorm > 0 && candidates[i].Norm > 0 {
			score += (dotProduct(profile, candidates[i].Feature) / (profileNorm * candidates[i].Norm)) * 0.48
		}
		if neighborScore := neighborScores[id]; neighborScore > 0 {
			score += neighborScore * 0.42
		}

		popularity := float64(asInt(candidates[i].Music["spotifyPopularity"])) / 100.0
		score += popularity * 0.06

		if maxPlays > 0 {
			plays := float64(candidates[i].PlayCount)
			if plays == 0 {
				plays = float64(playCounts[id])
			}
			score += (math.Log1p(plays) / math.Log1p(float64(maxPlays))) * 0.04
		}

		if recentArtists[candidates[i].ArtistID] {
			score -= 0.12
		}

		if profileNorm == 0 {
			score += popularity
		}

		candidates[i].Score = score
	}

	sort.SliceStable(candidates, func(i, j int) bool {
		if candidates[i].Score == candidates[j].Score {
			return asInt(candidates[i].Music["spotifyPopularity"]) > asInt(candidates[j].Music["spotifyPopularity"])
		}
		return candidates[i].Score > candidates[j].Score
	})

	serverURL := os.Getenv("SERVER_URL")
	selected := make([]bson.M, 0, limit)
	artistUse := map[string]int{}
	for _, candidate := range candidates {
		if len(selected) >= limit {
			break
		}
		if math.IsInf(candidate.Score, -1) {
			continue
		}
		if limit > 1 && candidate.ArtistID != "" && artistUse[candidate.ArtistID] >= 2 {
			continue
		}
		selected = append(selected, formatRecommendedMusic(candidate.Music, serverURL))
		artistUse[candidate.ArtistID]++
	}

	return selected, nil
}

func loadTrainedRecommendationCandidates(ctx context.Context) ([]recommendationCandidate, map[string]recommendationCandidate, bool, error) {
	count, err := recommendationVectorsCollection.CountDocuments(ctx, bson.M{"modelVersion": recommendationModelVersion})
	if err != nil {
		return nil, nil, false, err
	}
	if count == 0 {
		return nil, nil, false, nil
	}

	catalog, err := loadRecommendationCatalog(ctx)
	if err != nil {
		return nil, nil, false, err
	}
	catalogByID := map[string]bson.M{}
	for _, music := range catalog {
		id := objectIDHex(music["_id"])
		if id != "" {
			catalogByID[id] = music
		}
	}

	cursor, err := recommendationVectorsCollection.Find(ctx, bson.M{"modelVersion": recommendationModelVersion})
	if err != nil {
		return nil, nil, false, err
	}
	defer cursor.Close(ctx)

	candidates := make([]recommendationCandidate, 0, count)
	byID := map[string]recommendationCandidate{}
	for cursor.Next(ctx) {
		var doc bson.M
		if cursor.Decode(&doc) != nil {
			continue
		}
		id := asString(doc["musicId"])
		music, ok := catalogByID[id]
		if !ok {
			continue
		}
		candidate := recommendationCandidate{
			Music:     music,
			Feature:   asFloatMap(doc["features"]),
			Neighbors: asNeighborScoreMap(doc["neighbors"]),
			Norm:      asFloat(doc["norm"]),
			ArtistID:  asString(doc["artistId"]),
			PlayCount: asInt(doc["playCount"]),
		}
		candidates = append(candidates, candidate)
		byID[id] = candidate
	}
	return candidates, byID, len(candidates) > 0, nil
}

func buildRealtimeRecommendationCandidates(ctx context.Context, playCounts map[string]int) ([]recommendationCandidate, map[string]recommendationCandidate, error) {
	catalog, err := loadRecommendationCatalog(ctx)
	if err != nil {
		return nil, nil, err
	}

	byID := map[string]recommendationCandidate{}
	candidates := make([]recommendationCandidate, 0, len(catalog))
	for _, music := range catalog {
		id := objectIDHex(music["_id"])
		feature := buildMusicFeatureVector(music)
		candidate := recommendationCandidate{
			Music:     music,
			Feature:   feature,
			Neighbors: map[string]float64{},
			Norm:      vectorNorm(feature),
			ArtistID:  objectIDHex(music["artistId"]),
			PlayCount: playCounts[id],
		}
		byID[id] = candidate
		candidates = append(candidates, candidate)
	}

	return candidates, byID, nil
}

func loadRecommendationCatalog(ctx context.Context) ([]bson.M, error) {
	serverURL := os.Getenv("SERVER_URL")
	pipeline := []bson.M{
		{"$lookup": bson.M{
			"from":         "albums",
			"localField":   "albumId",
			"foreignField": "_id",
			"as":           "album",
		}},
		{"$unwind": bson.M{"path": "$album", "preserveNullAndEmptyArrays": true}},
		{"$lookup": bson.M{
			"from":         "artists",
			"localField":   "artistId",
			"foreignField": "_id",
			"as":           "artist",
		}},
		{"$unwind": bson.M{"path": "$artist", "preserveNullAndEmptyArrays": true}},
		{"$addFields": bson.M{
			"artistName":              "$artist.name",
			"albumName":               "$album.name",
			"artistGenres":            "$artist.genres",
			"albumReleaseDate":        "$album.releaseDate",
			"albumType":               "$album.albumType",
			"artistSpotifyPopularity": "$artist.spotifyPopularity",
			"artistSpotifyFollowers":  "$artist.spotifyFollowers",
			"coverUrl": bson.M{"$cond": []interface{}{
				bson.M{"$ne": []interface{}{"$coverUrl", ""}},
				"$coverUrl",
				"$album.albumCoverUrl",
			}},
			"color": bson.M{"$cond": []interface{}{
				bson.M{"$ne": []interface{}{"$color", ""}},
				"$color",
				"$album.color",
			}},
		}},
		{"$project": bson.M{"album": 0, "artist": 0}},
	}

	cursor, err := musicCollection.Aggregate(ctx, pipeline)
	if err != nil {
		return nil, err
	}
	defer cursor.Close(ctx)

	var musics []bson.M
	if err := cursor.All(ctx, &musics); err != nil {
		return nil, err
	}
	for _, music := range musics {
		if rawURL, ok := music["url"].(string); ok && strings.HasPrefix(rawURL, "/") {
			music["url"] = serverURL + rawURL
		}
	}
	return musics, nil
}

func loadMusicPlayCounts(ctx context.Context) map[string]int {
	counts := map[string]int{}
	pipeline := []bson.M{
		{"$group": bson.M{"_id": "$musicId", "count": bson.M{"$sum": 1}}},
	}
	cursor, err := playEventsCollection.Aggregate(ctx, pipeline)
	if err != nil {
		return counts
	}
	defer cursor.Close(ctx)

	var rows []bson.M
	if err := cursor.All(ctx, &rows); err != nil {
		return counts
	}
	for _, row := range rows {
		counts[objectIDHex(row["_id"])] = asInt(row["count"])
	}
	return counts
}

func buildMusicFeatureVector(music bson.M) map[string]float64 {
	vector := map[string]float64{}
	addTokenFeature(vector, "title", asString(music["name"]), 0.9)
	addTokenFeature(vector, "artist", asString(music["artistName"]), 2.2)
	addTokenFeature(vector, "album", asString(music["albumName"]), 0.7)
	addTokenFeature(vector, "genre", asString(music["genre"]), 4.0)
	addTokenFeature(vector, "album_type", asString(music["albumType"]), 0.5)
	addTokenFeature(vector, "duration", durationBucket(asInt(music["spotifyDurationMs"])), 0.8)
	addTokenFeature(vector, "popularity", popularityBucket(asInt(music["spotifyPopularity"])), 0.5)
	addTokenFeature(vector, "artist_popularity", popularityBucket(asInt(music["artistSpotifyPopularity"])), 0.45)
	addTokenFeature(vector, "followers", followersBucket(asInt(music["artistSpotifyFollowers"])), 0.35)
	addTokenFeature(vector, "release", releaseBucket(asString(music["albumReleaseDate"])), 0.4)
	addTokenFeature(vector, "track_no", trackNumberBucket(asInt(music["spotifyTrackNumber"])), 0.25)

	if asBool(music["spotifyExplicit"]) {
		vector["explicit:true"] += 0.6
	} else {
		vector["explicit:false"] += 0.3
	}

	for _, genre := range asStringSlice(music["artistGenres"]) {
		addTokenFeature(vector, "artist_genre", genre, 3.2)
	}

	id := objectIDHex(music["_id"])
	if id != "" {
		lyricsPath := filepath.Join("uploads", "lyrics", id+".lrc")
		if lyrics, err := parseLRC(lyricsPath); err == nil {
			var builder strings.Builder
			for i, line := range lyrics {
				if i >= 80 {
					break
				}
				builder.WriteString(" ")
				builder.WriteString(line.Content)
			}
			addTokenFeature(vector, "lyrics", builder.String(), 0.18)
		}
	}

	return vector
}

var recommendationTokenRegex = regexp.MustCompile(`[a-z0-9]+`)

func addTokenFeature(vector map[string]float64, prefix, value string, weight float64) {
	value = strings.ToLower(strings.TrimSpace(value))
	if value == "" {
		return
	}
	tokens := recommendationTokenRegex.FindAllString(value, -1)
	for _, token := range tokens {
		if len(token) < 2 {
			continue
		}
		vector[prefix+":"+token] += weight
	}
}

func dotProduct(a, b map[string]float64) float64 {
	if len(a) > len(b) {
		a, b = b, a
	}
	sum := 0.0
	for key, value := range a {
		sum += value * b[key]
	}
	return sum
}

func vectorNorm(vector map[string]float64) float64 {
	sum := 0.0
	for _, value := range vector {
		sum += value * value
	}
	return math.Sqrt(sum)
}

func collabScoreForPair(collab map[string]map[string]float64, leftID, rightID string) float64 {
	if related, ok := collab[leftID]; ok {
		return related[rightID]
	}
	return 0
}

func roundFloat(value float64, places int) float64 {
	if places <= 0 {
		return math.Round(value)
	}
	factor := math.Pow(10, float64(places))
	return math.Round(value*factor) / factor
}

func formatRecommendedMusic(music bson.M, serverURL string) bson.M {
	id := objectIDHex(music["_id"])
	coverURL := asString(music["coverUrl"])
	if coverURL != "" && strings.HasPrefix(coverURL, "/") {
		coverURL = serverURL + coverURL
	}
	url := asString(music["url"])
	if url != "" && strings.HasPrefix(url, "/") {
		url = serverURL + url
	}

	response := bson.M{
		"_id":                id,
		"url":                url,
		"name":               asString(music["name"]),
		"artistId":           objectIDHex(music["artistId"]),
		"artistName":         asString(music["artistName"]),
		"albumId":            objectIDHex(music["albumId"]),
		"albumName":          asString(music["albumName"]),
		"waveform":           music["waveform"],
		"genre":              asString(music["genre"]),
		"coverUrl":           coverURL,
		"color":              asString(music["color"]),
		"spotifyId":          asString(music["spotifyId"]),
		"spotifyUrl":         asString(music["spotifyUrl"]),
		"spotifyPopularity":  asInt(music["spotifyPopularity"]),
		"spotifyDurationMs":  asInt(music["spotifyDurationMs"]),
		"spotifyTrackNumber": asInt(music["spotifyTrackNumber"]),
		"spotifyDiscNumber":  asInt(music["spotifyDiscNumber"]),
		"spotifyExplicit":    asBool(music["spotifyExplicit"]),
		"createdAt":          music["createdAt"],
		"updatedAt":          music["updatedAt"],
	}

	if id != "" {
		lyricsPath := filepath.Join("uploads", "lyrics", id+".lrc")
		if lyrics, err := parseLRC(lyricsPath); err == nil {
			response["lyrics"] = lyrics
		}
	}
	if response["waveform"] == nil {
		response["waveform"] = []float64{}
	}
	return response
}

func durationBucket(ms int) string {
	if ms <= 0 {
		return "unknown"
	}
	minutes := ms / 60000
	switch {
	case minutes < 2:
		return "short"
	case minutes <= 4:
		return "medium"
	case minutes <= 7:
		return "long"
	default:
		return "extended"
	}
}

func popularityBucket(popularity int) string {
	switch {
	case popularity >= 80:
		return "viral"
	case popularity >= 55:
		return "popular"
	case popularity >= 25:
		return "known"
	default:
		return "deep"
	}
}

func followersBucket(followers int) string {
	switch {
	case followers >= 10000000:
		return "global"
	case followers >= 1000000:
		return "mainstream"
	case followers >= 100000:
		return "known"
	case followers >= 10000:
		return "rising"
	default:
		return "niche"
	}
}

func trackNumberBucket(trackNumber int) string {
	switch {
	case trackNumber <= 0:
		return "unknown"
	case trackNumber <= 3:
		return "front"
	case trackNumber <= 8:
		return "middle"
	default:
		return "deep"
	}
}

func releaseBucket(releaseDate string) string {
	if len(releaseDate) < 4 {
		return "unknown"
	}
	year := releaseDate[:4]
	switch {
	case year >= "2020":
		return "2020s"
	case year >= "2010":
		return "2010s"
	case year >= "2000":
		return "2000s"
	case year >= "1990":
		return "1990s"
	default:
		return "classic"
	}
}

func objectIDHex(value interface{}) string {
	switch v := value.(type) {
	case primitive.ObjectID:
		if v.IsZero() {
			return ""
		}
		return v.Hex()
	case string:
		return v
	default:
		return ""
	}
}

func asString(value interface{}) string {
	if value == nil {
		return ""
	}
	if str, ok := value.(string); ok {
		return str
	}
	return ""
}

func asInt(value interface{}) int {
	switch v := value.(type) {
	case int:
		return v
	case int32:
		return int(v)
	case int64:
		return int(v)
	case float64:
		return int(v)
	default:
		return 0
	}
}

func asFloat(value interface{}) float64 {
	switch v := value.(type) {
	case float64:
		return v
	case float32:
		return float64(v)
	case int:
		return float64(v)
	case int32:
		return float64(v)
	case int64:
		return float64(v)
	default:
		return 0
	}
}

func asFloatMap(value interface{}) map[string]float64 {
	result := map[string]float64{}
	switch v := value.(type) {
	case map[string]float64:
		return v
	case bson.M:
		for key, item := range v {
			result[key] = asFloat(item)
		}
	case map[string]interface{}:
		for key, item := range v {
			result[key] = asFloat(item)
		}
	}
	return result
}

func asTime(value interface{}) time.Time {
	switch v := value.(type) {
	case time.Time:
		return v
	case primitive.DateTime:
		return v.Time()
	default:
		return time.Time{}
	}
}

func asNeighborScoreMap(value interface{}) map[string]float64 {
	result := map[string]float64{}
	switch v := value.(type) {
	case []recommendationNeighbor:
		for _, item := range v {
			result[item.MusicID] = item.Score
		}
	case primitive.A:
		for _, item := range v {
			if doc, ok := item.(bson.M); ok {
				result[asString(doc["musicId"])] = asFloat(doc["score"])
			}
		}
	case []interface{}:
		for _, item := range v {
			if doc, ok := item.(bson.M); ok {
				result[asString(doc["musicId"])] = asFloat(doc["score"])
			}
		}
	}
	delete(result, "")
	return result
}

func asBool(value interface{}) bool {
	if b, ok := value.(bool); ok {
		return b
	}
	return false
}

func asStringSlice(value interface{}) []string {
	switch v := value.(type) {
	case []string:
		return v
	case primitive.A:
		items := make([]string, 0, len(v))
		for _, item := range v {
			if str, ok := item.(string); ok {
				items = append(items, str)
			}
		}
		return items
	case []interface{}:
		items := make([]string, 0, len(v))
		for _, item := range v {
			if str, ok := item.(string); ok {
				items = append(items, str)
			}
		}
		return items
	default:
		return []string{}
	}
}
