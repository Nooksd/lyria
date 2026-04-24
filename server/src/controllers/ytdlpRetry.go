package controllers

import (
	"bytes"
	"context"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"time"
)

// ytdlpRetryConfig holds settings for the smart retry mechanism
type ytdlpRetryConfig struct {
	MaxRetries       int
	InitialBackoff   time.Duration
	MaxBackoff       time.Duration
	BackoffMultipler float64
}

var defaultRetryConfig = ytdlpRetryConfig{
	MaxRetries:       5,
	InitialBackoff:   30 * time.Second,
	MaxBackoff:       5 * time.Minute,
	BackoffMultipler: 2.0,
}

// ytdlpResult holds the result of a yt-dlp execution with retry
type ytdlpResult struct {
	Success    bool
	Stderr     string
	RetryCount int
}

// isRetryableError checks if the yt-dlp error is a bot detection / cookie / rate limit issue
// that can be resolved by waiting or updating cookies
func isRetryableError(stderr string) bool {
	retryablePatterns := []string{
		"Sign in to confirm you're not a bot",
		"confirm you're not a bot",
		"cookies",
		"HTTP Error 429",
		"Too Many Requests",
		"rate limit",
		"rate-limit",
		"IncompleteRead",
		"Connection reset by peer",
		"urlopen error",
		"timed out",
		"HTTP Error 503",
		"HTTP Error 403",
	}
	stderrLower := strings.ToLower(stderr)
	for _, pattern := range retryablePatterns {
		if strings.Contains(stderrLower, strings.ToLower(pattern)) {
			return true
		}
	}
	return false
}

// runYtdlpWithRetry executes yt-dlp with exponential backoff retry for bot detection errors.
// It monitors cookies.txt changes and retries immediately when the file is updated.
// The logFunc callback receives status messages for logging/progress.
func runYtdlpWithRetry(
	ctx context.Context,
	ytArgs []string,
	config ytdlpRetryConfig,
	logFunc func(msg string),
) ytdlpResult {
	backoff := config.InitialBackoff

	// Per-attempt hard deadline: kills yt-dlp if it hangs for any reason
	const attemptTimeout = 4 * time.Minute

	for attempt := 0; attempt <= config.MaxRetries; attempt++ {
		if cancelled := ctx.Err(); cancelled != nil {
			return ytdlpResult{Success: false, Stderr: "cancelled", RetryCount: attempt}
		}

		attemptCtx, attemptCancel := context.WithTimeout(ctx, attemptTimeout)
		cmd := exec.CommandContext(attemptCtx, "yt-dlp", ytArgs...)
		var cmdStderr bytes.Buffer
		cmd.Stderr = &cmdStderr

		err := cmd.Run()
		attemptCancel()
		if err == nil {
			return ytdlpResult{Success: true, RetryCount: attempt}
		}

		errMsg := cmdStderr.String()

		// If context was cancelled (job cancel or per-attempt timeout), handle it
		if ctx.Err() != nil {
			return ytdlpResult{Success: false, Stderr: "cancelled", RetryCount: attempt}
		}
		if attemptCtx.Err() != nil && ctx.Err() == nil {
			// Per-attempt timeout fired (not job cancel) — treat as retryable
			logFunc(fmt.Sprintf("⏳ Faixa demorou mais de %s, forçando nova tentativa (%d/%d)...",
				attemptTimeout.Round(time.Second), attempt+1, config.MaxRetries+1))
			errMsg = "timeout"
		} else if !isRetryableError(errMsg) {
			// If not retryable, fail immediately
			if len(errMsg) > 500 {
				errMsg = errMsg[len(errMsg)-500:]
			}
			return ytdlpResult{
				Success:    false,
				Stderr:     fmt.Sprintf("%s | %s", err.Error(), errMsg),
				RetryCount: attempt,
			}
		}

		// Last attempt exhausted
		if attempt == config.MaxRetries {
			if len(errMsg) > 500 {
				errMsg = errMsg[len(errMsg)-500:]
			}
			return ytdlpResult{
				Success:    false,
				Stderr:     fmt.Sprintf("Esgotadas %d tentativas. Último erro: %s | %s", config.MaxRetries+1, err.Error(), errMsg),
				RetryCount: attempt,
			}
		}

		// Log the retry
		logFunc(fmt.Sprintf("⏳ Bot detectado (tentativa %d/%d). Aguardando %s antes de tentar novamente...",
			attempt+1, config.MaxRetries+1, backoff.Round(time.Second)))

		// Wait with cookie file monitoring — if cookies.txt changes, retry immediately
		if !waitWithCookieWatch(ctx, backoff) {
			return ytdlpResult{Success: false, Stderr: "cancelled", RetryCount: attempt}
		}

		// Increase backoff for next attempt
		backoff = time.Duration(float64(backoff) * config.BackoffMultipler)
		if backoff > config.MaxBackoff {
			backoff = config.MaxBackoff
		}
	}

	return ytdlpResult{Success: false, Stderr: "retry loop exited unexpectedly"}
}

// waitWithCookieWatch waits for the specified duration but returns early
// if cookies.txt is modified (so the import can retry with fresh cookies).
// Returns false if context is cancelled.
func waitWithCookieWatch(ctx context.Context, duration time.Duration) bool {
	cookiesPath := "/opt/lyria/server/cookies.txt"

	// Record initial mod time
	var initialModTime time.Time
	if info, err := os.Stat(cookiesPath); err == nil {
		initialModTime = info.ModTime()
	}

	deadline := time.After(duration)
	ticker := time.NewTicker(2 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return false
		case <-deadline:
			return true
		case <-ticker.C:
			// Check if cookies file was updated
			if info, err := os.Stat(cookiesPath); err == nil {
				if info.ModTime().After(initialModTime) {
					return true // Cookies updated, retry now!
				}
			}
		}
	}
}
