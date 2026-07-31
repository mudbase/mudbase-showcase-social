package server

import (
	"net/http"
	"strconv"
	"strings"
)

// postContentMaxLen mirrors the reference web app's PostComposer zod schema
// (web/plan/build-plan.md: "Post content capped at 500 chars").
const postContentMaxLen = 500

// FeedView is the paginated post list shared by the full feed page and its poll-refreshed
// fragment.
type FeedView struct {
	Posts      []PostView
	PostsEmpty bool
	Page       int32
	HasPrev    bool
	HasMore    bool
	PrevPage   int32
	NextPage   int32
}

func (a *App) feedView(r *http.Request, page int32) (FeedView, error) {
	data := sessionFrom(r)
	token := data.AccessToken()

	posts, hasMore, err := a.posts.Feed(r.Context(), token, page)
	if err != nil {
		return FeedView{}, err
	}

	var likedIDs map[string]bool
	if data.IsSignedIn() {
		likedIDs, err = a.likes.LikedPostIDs(r.Context(), token, data.UserID())
		if err != nil {
			return FeedView{}, err
		}
	}

	return FeedView{
		Posts:      newPostViews(posts, likedIDs, data.UserID(), data.IsSignedIn()),
		PostsEmpty: len(posts) == 0,
		Page:       page,
		HasPrev:    page > 1,
		HasMore:    hasMore,
		PrevPage:   page - 1,
		NextPage:   page + 1,
	}, nil
}

func parsePage(r *http.Request) int32 {
	raw := r.URL.Query().Get("page")
	if raw == "" {
		return 1
	}
	page, err := strconv.Atoi(raw)
	if err != nil || page < 1 {
		return 1
	}
	return int32(page)
}

// HomeData is the / page's content payload.
type HomeData struct {
	Base
	FeedView
	ComposerContent  string
	ComposerImageURL string
}

// handleFeed renders the paginated feed with the post composer above it.
func (a *App) handleFeed(w http.ResponseWriter, r *http.Request) {
	page := parsePage(r)
	feed, err := a.feedView(r, page)
	if err != nil {
		a.serverError(w, r, err)
		return
	}

	view := HomeData{
		Base:     a.baseView(r, ""),
		FeedView: feed,
	}
	view.FlashError, view.FlashSuccess = flashFromQuery(r)
	a.render(w, r, http.StatusOK, "home.html", view)
}

// handleFeedFragment renders just the post list (no layout, no composer), polled every few
// seconds by a small inline script on the feed page - this app's stand-in for the reference web
// app's Socket.IO `subscribe:collection` realtime feed (web/src/hooks/usePostsLive.ts): there is no
// official Mudbase Go realtime client, so the feed refreshes via polling instead of a push
// subscription, which is functionally equivalent for this use case (see README "Known
// limitations").
func (a *App) handleFeedFragment(w http.ResponseWriter, r *http.Request) {
	page := parsePage(r)
	feed, err := a.feedView(r, page)
	if err != nil {
		a.serverError(w, r, err)
		return
	}
	a.renderFragment(w, r, http.StatusOK, "feed_fragment.html", feed)
}

// handlePostCreate publishes a new post. Route already gated by requireSignedIn.
func (a *App) handlePostCreate(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseForm(); err != nil {
		a.serverError(w, r, err)
		return
	}
	content := strings.TrimSpace(r.FormValue("content"))
	imageURL := strings.TrimSpace(r.FormValue("imageUrl"))

	if content == "" {
		redirectWithError(w, r, "/", "Write something before posting.")
		return
	}
	if len(content) > postContentMaxLen {
		redirectWithError(w, r, "/", "Posts can't be longer than 500 characters.")
		return
	}

	data := sessionFrom(r)
	if _, err := a.posts.Create(r.Context(), data.AccessToken(), data.UserID(), data.DisplayName(), content, imageURL); err != nil {
		redirectWithError(w, r, "/", "Couldn't publish that post. Please try again.")
		return
	}

	http.Redirect(w, r, "/", http.StatusSeeOther)
}
