// Package server wires the app's HTTP surface: routing, session handling, and every
// server-rendered page handler, on top of internal/store's domain services.
package server

import (
	"fmt"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"

	"github.com/mudbase/mudbase-showcase-social/go/internal/config"
	"github.com/mudbase/mudbase-showcase-social/go/internal/mbase"
	"github.com/mudbase/mudbase-showcase-social/go/internal/session"
	"github.com/mudbase/mudbase-showcase-social/go/internal/store"
)

// App bundles every dependency the HTTP handlers need.
type App struct {
	cfg       *config.Config
	sessions  *session.Store
	mudbase   *mbase.Client
	posts     *store.PostService
	comments  *store.CommentService
	likes     *store.LikeService
	follows   *store.FollowService
	profiles  *store.ProfileService
	templates *Templates
}

// New builds the App and its full dependency graph from cfg.
func New(cfg *config.Config) (*App, error) {
	templates, err := loadTemplates()
	if err != nil {
		return nil, fmt.Errorf("server: loading templates: %w", err)
	}

	client := mbase.New(cfg)
	posts := store.NewPostService(client, cfg.PostsCollectionID)
	comments := store.NewCommentService(client, cfg.CommentsCollectionID)
	likes := store.NewLikeService(client, cfg.LikesCollectionID, posts)
	follows := store.NewFollowService(client, cfg.FollowsCollectionID)
	profiles := store.NewProfileService(posts, follows)

	return &App{
		cfg:       cfg,
		sessions:  session.New(cfg.SessionSecret, cfg.CookieSecure),
		mudbase:   client,
		posts:     posts,
		comments:  comments,
		likes:     likes,
		follows:   follows,
		profiles:  profiles,
		templates: templates,
	}, nil
}

// Routes builds the full chi router for this app. Static assets are mounted outside the session
// middleware group - a stylesheet request has no business establishing (or waiting on) a Mudbase
// anonymous session.
func (a *App) Routes() http.Handler {
	root := chi.NewRouter()
	root.Use(middleware.Logger)
	root.Use(middleware.Recoverer)

	staticHandler := http.FileServer(http.FS(staticFS))
	root.Get("/static/*", staticHandler.ServeHTTP)

	r := chi.NewRouter()
	r.Use(a.sessionMiddleware)

	r.Get("/", a.handleFeed)
	r.Get("/feed/fragment", a.handleFeedFragment)
	r.With(a.requireSignedIn).Post("/posts", a.handlePostCreate)

	r.Get("/posts/{id}", a.handlePostDetail)
	r.Get("/posts/{id}/fragment", a.handlePostDetailFragment)
	r.With(a.requireSignedIn).Post("/posts/{id}/like", a.handlePostLikeToggle)
	r.With(a.requireSignedIn).Post("/posts/{id}/comments", a.handleCommentCreate)

	r.Get("/users/{userId}", a.handleProfile)
	r.With(a.requireSignedIn).Post("/users/{userId}/follow", a.handleFollowToggle)
	r.With(a.requireSignedIn).Get("/profile", a.handleProfileRedirect)

	r.Get("/login", a.handleLoginShow)
	r.Post("/login", a.handleLoginSubmit)
	r.Post("/logout", a.handleLogout)

	root.Mount("/", r)
	return root
}

// baseView builds the Base view fields shared by every page from the current request's session.
func (a *App) baseView(r *http.Request, title string) Base {
	data := sessionFrom(r)
	return Base{
		Title:       title,
		IsSignedIn:  data.IsSignedIn(),
		DisplayName: data.DisplayName(),
		UserID:      data.UserID(),
	}
}
