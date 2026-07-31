package server

import (
	"net/http"

	"github.com/go-chi/chi/v5"
)

// ProfileData is the /users/{userId} page's content payload.
type ProfileData struct {
	Base
	ProfileUserID   string
	ProfileName     string
	ProfileInitials string
	PostCount       int32
	FollowerCount   int32
	FollowingCount  int32
	IsOwnProfile    bool
	IsFollowing     bool
	Posts           []PostView
	PostsEmpty      bool
}

func (a *App) handleProfile(w http.ResponseWriter, r *http.Request) {
	userID := chi.URLParam(r, "userId")
	data := sessionFrom(r)
	token := data.AccessToken()
	ctx := r.Context()

	displayName, err := a.profiles.ResolveDisplayName(ctx, token, userID)
	if err != nil {
		a.serverError(w, r, err)
		return
	}

	posts, postCount, err := a.posts.ByAuthor(ctx, token, userID)
	if err != nil {
		a.serverError(w, r, err)
		return
	}

	followerCount, err := a.follows.FollowerCount(ctx, token, userID)
	if err != nil {
		a.serverError(w, r, err)
		return
	}
	followingCount, err := a.follows.FollowingCount(ctx, token, userID)
	if err != nil {
		a.serverError(w, r, err)
		return
	}

	isOwnProfile := data.IsSignedIn() && data.UserID() == userID
	var isFollowing bool
	if data.IsSignedIn() && !isOwnProfile {
		isFollowing, err = a.follows.IsFollowing(ctx, token, data.UserID(), userID)
		if err != nil {
			a.serverError(w, r, err)
			return
		}
	}

	var likedIDs map[string]bool
	if data.IsSignedIn() {
		likedIDs, err = a.likes.LikedPostIDs(ctx, token, data.UserID())
		if err != nil {
			a.serverError(w, r, err)
			return
		}
	}

	view := ProfileData{
		Base:            a.baseView(r, displayName),
		ProfileUserID:   userID,
		ProfileName:     displayName,
		ProfileInitials: initials(displayName),
		PostCount:       postCount,
		FollowerCount:   followerCount,
		FollowingCount:  followingCount,
		IsOwnProfile:    isOwnProfile,
		IsFollowing:     isFollowing,
		Posts:           newPostViews(posts, likedIDs, data.UserID(), data.IsSignedIn()),
		PostsEmpty:      len(posts) == 0,
	}
	view.FlashError, view.FlashSuccess = flashFromQuery(r)
	a.render(w, r, http.StatusOK, "profile.html", view)
}

// handleProfileRedirect sends the signed-in visitor to their own profile. Route already gated by
// requireSignedIn, so data.UserID() is guaranteed non-empty.
func (a *App) handleProfileRedirect(w http.ResponseWriter, r *http.Request) {
	data := sessionFrom(r)
	http.Redirect(w, r, "/users/"+data.UserID(), http.StatusSeeOther)
}

// handleFollowToggle follows or unfollows userID for the signed-in visitor. Route already gated by
// requireSignedIn.
func (a *App) handleFollowToggle(w http.ResponseWriter, r *http.Request) {
	userID := chi.URLParam(r, "userId")
	data := sessionFrom(r)

	if userID == data.UserID() {
		redirectWithError(w, r, "/users/"+userID, "You can't follow yourself.")
		return
	}

	if _, err := a.follows.Toggle(r.Context(), data.AccessToken(), data.UserID(), userID, data.DisplayName()); err != nil {
		redirectWithError(w, r, "/users/"+userID, "Couldn't update that follow. Please try again.")
		return
	}
	http.Redirect(w, r, "/users/"+userID, http.StatusSeeOther)
}
