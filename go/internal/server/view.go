package server

import "github.com/mudbase/mudbase-showcase-social/go/internal/models"

// Base holds the fields every page's layout needs (header nav, flash banner). It is embedded in
// every page-specific data struct so templates can read `.IsSignedIn`, `.Flash`, etc. directly at
// the top level via Go's promoted-field rules.
type Base struct {
	Title        string
	IsSignedIn   bool
	DisplayName  string
	UserID       string
	FlashError   string
	FlashSuccess string
}

// PostView is a display-ready post: every derived value (author initials, formatted date, this
// visitor's like state) is computed once here instead of in the template. ViewerSignedIn is
// carried on the view itself (rather than read from the enclosing page's Base in the template) so
// partials.html's "post_card" can decide whether to render an interactive like button without
// depending on html/template's `$`-scoping rules across nested {{template}} invocations.
type PostView struct {
	models.Post
	CreatedLabel   string
	AuthorInitials string
	LikedByMe      bool
	IsOwnPost      bool
	ViewerSignedIn bool
}

func newPostView(p models.Post, likedByMe bool, currentUserID string, viewerSignedIn bool) PostView {
	return PostView{
		Post:           p,
		CreatedLabel:   formatDate(p.CreatedAt),
		AuthorInitials: initials(p.AuthorName),
		LikedByMe:      likedByMe,
		IsOwnPost:      currentUserID != "" && p.AuthorID == currentUserID,
		ViewerSignedIn: viewerSignedIn,
	}
}

// newPostViews builds a PostView for each post, looking up each one's liked state from
// likedPostIDs (nil is treated as "nothing liked", the correct behavior for a signed-out visitor).
func newPostViews(posts []models.Post, likedPostIDs map[string]bool, currentUserID string, viewerSignedIn bool) []PostView {
	views := make([]PostView, 0, len(posts))
	for _, p := range posts {
		views = append(views, newPostView(p, likedPostIDs[p.ID], currentUserID, viewerSignedIn))
	}
	return views
}

// CommentView is a display-ready comment.
type CommentView struct {
	models.Comment
	CreatedLabel   string
	AuthorInitials string
}

func newCommentView(c models.Comment) CommentView {
	return CommentView{
		Comment:        c,
		CreatedLabel:   formatDate(c.CreatedAt),
		AuthorInitials: initials(c.AuthorName),
	}
}

func newCommentViews(comments []models.Comment) []CommentView {
	views := make([]CommentView, 0, len(comments))
	for _, c := range comments {
		views = append(views, newCommentView(c))
	}
	return views
}
