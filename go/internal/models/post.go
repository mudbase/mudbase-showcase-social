// Package models holds this app's typed views of the four Mudbase collections it reads and
// writes (posts, comments, likes, follows) - see plan/build-plan.md for the full schema.
package models

// Post mirrors the `posts` Mudbase collection schema.
type Post struct {
	ID            string `json:"_id"`
	CreatedAt     string `json:"createdAt"`
	UpdatedAt     string `json:"updatedAt"`
	AuthorID      string `json:"authorId"`
	AuthorName    string `json:"authorName"`
	Content       string `json:"content"`
	ImageURL      string `json:"imageUrl,omitempty"`
	LikesCount    int64  `json:"likesCount"`
	CommentsCount int64  `json:"commentsCount"`
}
