// Package config loads and validates every environment variable this app needs at startup.
// Failing fast here means a misconfigured deployment never serves a single request instead of
// panicking deep inside a request handler the first time a particular env var is touched.
package config

import (
	"fmt"
	"os"
	"strconv"
)

// Config holds every environment-derived setting the app needs, resolved once at startup.
type Config struct {
	// MudbaseURL is the Mudbase API base URL (e.g. https://cloud.mudbase.dev).
	MudbaseURL string
	// ProjectID is this app's Mudbase project ID.
	ProjectID string
	// PostsCollectionID is the Mudbase collection ID backing the `posts` collection.
	PostsCollectionID string
	// CommentsCollectionID is the Mudbase collection ID backing the `comments` collection.
	CommentsCollectionID string
	// LikesCollectionID is the Mudbase collection ID backing the `likes` collection.
	LikesCollectionID string
	// FollowsCollectionID is the Mudbase collection ID backing the `follows` collection.
	FollowsCollectionID string
	// SessionSecret signs and encrypts the httpOnly session cookie holding the Mudbase JWT.
	SessionSecret string
	// CookieSecure sets the session cookie's Secure flag. Enable in production (HTTPS); leave off
	// for plain-HTTP local development, where a Secure cookie would silently never be sent.
	CookieSecure bool
	// Port is the local HTTP listen port.
	Port string
}

// Load reads and validates every required environment variable, returning a descriptive error
// for the first one that's missing rather than letting the zero value propagate silently.
func Load() (*Config, error) {
	cfg := &Config{
		MudbaseURL:           envOrDefault("MUDBASE_URL", "https://cloud.mudbase.dev"),
		ProjectID:            os.Getenv("MUDBASE_PROJECT_ID"),
		PostsCollectionID:    os.Getenv("MUDBASE_POSTS_COLLECTION_ID"),
		CommentsCollectionID: os.Getenv("MUDBASE_COMMENTS_COLLECTION_ID"),
		LikesCollectionID:    os.Getenv("MUDBASE_LIKES_COLLECTION_ID"),
		FollowsCollectionID:  os.Getenv("MUDBASE_FOLLOWS_COLLECTION_ID"),
		SessionSecret:        os.Getenv("SESSION_SECRET"),
		CookieSecure:         envOrDefault("COOKIE_SECURE", "false") == "true",
		Port:                 envOrDefault("PORT", "8080"),
	}

	required := map[string]string{
		"MUDBASE_PROJECT_ID":             cfg.ProjectID,
		"MUDBASE_POSTS_COLLECTION_ID":    cfg.PostsCollectionID,
		"MUDBASE_COMMENTS_COLLECTION_ID": cfg.CommentsCollectionID,
		"MUDBASE_LIKES_COLLECTION_ID":    cfg.LikesCollectionID,
		"MUDBASE_FOLLOWS_COLLECTION_ID":  cfg.FollowsCollectionID,
		"SESSION_SECRET":                 cfg.SessionSecret,
	}
	for name, value := range required {
		if value == "" {
			return nil, fmt.Errorf("config: missing required environment variable %s", name)
		}
	}

	if len(cfg.SessionSecret) < 32 {
		return nil, fmt.Errorf("config: SESSION_SECRET must be at least 32 characters, got %d", len(cfg.SessionSecret))
	}

	if _, err := strconv.Atoi(cfg.Port); err != nil {
		return nil, fmt.Errorf("config: PORT must be numeric: %w", err)
	}

	return cfg, nil
}

func envOrDefault(name, fallback string) string {
	if v := os.Getenv(name); v != "" {
		return v
	}
	return fallback
}
