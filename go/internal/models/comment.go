package models

// Comment mirrors the `comments` Mudbase collection schema - one row per comment, always read
// oldest-first for normal thread order (see store.CommentService.ForPost).
type Comment struct {
	ID         string `json:"_id"`
	CreatedAt  string `json:"createdAt"`
	UpdatedAt  string `json:"updatedAt"`
	PostID     string `json:"postId"`
	AuthorID   string `json:"authorId"`
	AuthorName string `json:"authorName"`
	Content    string `json:"content"`
}
