// Command server runs the Mudbase Showcase Social micro-blog: a server-rendered Go
// reimplementation of the Mudbase showcase social reference app, talking to the real Mudbase Go
// SDK, with zero custom backend.
package main

import (
	"log"
	"net/http"
	"time"

	"github.com/mudbase/mudbase-showcase-social/go/internal/config"
	"github.com/mudbase/mudbase-showcase-social/go/internal/server"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("config: %v", err)
	}

	app, err := server.New(cfg)
	if err != nil {
		log.Fatalf("server: %v", err)
	}

	httpServer := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           app.Routes(),
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       30 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       90 * time.Second,
	}

	log.Printf("Mudbase Showcase Social listening on http://localhost:%s", cfg.Port)
	if err := httpServer.ListenAndServe(); err != nil {
		log.Fatalf("server: %v", err)
	}
}
