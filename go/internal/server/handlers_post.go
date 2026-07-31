package server

import (
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"
)

// commentContentMaxLen mirrors the reference web app's CommentComposer zod schema
// (web/plan/build-plan.md: "comments at 300 [chars]").
const commentContentMaxLen = 300

// PostDetailView is the post-detail payload shared by the full page and its poll-refreshed
// fragment (like count/state and the comment thread).
type PostDetailView struct {
	Post          PostView
	Comments      []CommentView
	CommentsEmpty bool
}

func (a *App) postDetailView(r *http.Request, id string) (PostDetailView, error) {
	data := sessionFrom(r)
	token := data.AccessToken()

	post, err := a.posts.ByID(r.Context(), token, id)
	if err != nil {
		return PostDetailView{}, err
	}

	var likedByMe bool
	if data.IsSignedIn() {
		likedByMe, err = a.likes.IsLiked(r.Context(), token, id, data.UserID())
		if err != nil {
			return PostDetailView{}, err
		}
	}

	comments, err := a.comments.ForPost(r.Context(), token, id)
	if err != nil {
		return PostDetailView{}, err
	}

	return PostDetailView{
		Post:          newPostView(post, likedByMe, data.UserID(), data.IsSignedIn()),
		Comments:      newCommentViews(comments),
		CommentsEmpty: len(comments) == 0,
	}, nil
}

// PostPageData is the /posts/{id} page's content payload.
type PostPageData struct {
	Base
	PostDetailView
}

func (a *App) handlePostDetail(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	detail, err := a.postDetailView(r, id)
	if err != nil {
		redirectWithError(w, r, "/", "That post couldn't be found.")
		return
	}

	view := PostPageData{
		Base:           a.baseView(r, "Post"),
		PostDetailView: detail,
	}
	view.FlashError, view.FlashSuccess = flashFromQuery(r)
	a.render(w, r, http.StatusOK, "post_detail.html", view)
}

// handlePostDetailFragment renders just the like button/count and comment thread (no layout, no
// composer), polled every few seconds by a small inline script on the post detail page - see
// handlers_feed.go's handleFeedFragment doc comment for why this app polls instead of subscribing
// to a push realtime feed.
func (a *App) handlePostDetailFragment(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	detail, err := a.postDetailView(r, id)
	if err != nil {
		a.serverError(w, r, err)
		return
	}
	a.renderFragment(w, r, http.StatusOK, "post_detail_fragment.html", detail)
}

// handlePostLikeToggle likes or unlikes a post for the signed-in visitor. Route already gated by
// requireSignedIn.
func (a *App) handlePostLikeToggle(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	data := sessionFrom(r)

	if _, err := a.likes.Toggle(r.Context(), data.AccessToken(), id, data.UserID()); err != nil {
		redirectWithError(w, r, "/posts/"+id, "Couldn't update your like. Please try again.")
		return
	}
	http.Redirect(w, r, "/posts/"+id, http.StatusSeeOther)
}

// handleCommentCreate posts a new comment on a post. Route already gated by requireSignedIn.
func (a *App) handleCommentCreate(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	if err := r.ParseForm(); err != nil {
		a.serverError(w, r, err)
		return
	}
	content := strings.TrimSpace(r.FormValue("content"))
	if content == "" {
		redirectWithError(w, r, "/posts/"+id, "Write a comment before submitting.")
		return
	}
	if len(content) > commentContentMaxLen {
		redirectWithError(w, r, "/posts/"+id, "Comments can't be longer than 300 characters.")
		return
	}

	data := sessionFrom(r)
	token := data.AccessToken()

	if _, err := a.comments.Create(r.Context(), token, id, data.UserID(), data.DisplayName(), content); err != nil {
		redirectWithError(w, r, "/posts/"+id, "Couldn't post your comment. Please try again.")
		return
	}
	if err := a.posts.BumpCommentsCount(r.Context(), token, id, 1); err != nil {
		a.serverError(w, r, err)
		return
	}

	http.Redirect(w, r, "/posts/"+id, http.StatusSeeOther)
}
