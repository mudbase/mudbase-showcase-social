package store

import (
	"context"
	"fmt"

	"github.com/mudbase/mudbase-showcase-social/go/internal/mbase"
	"github.com/mudbase/mudbase-showcase-social/go/internal/models"
)

// commentsPageLimit bounds how many comments a single post detail page renders.
const commentsPageLimit = 200

// CommentService implements every operation the app needs against the `comments` collection.
type CommentService struct {
	client       *mbase.Client
	collectionID string
}

// NewCommentService builds a CommentService bound to the given comments collection ID.
func NewCommentService(client *mbase.Client, commentsCollectionID string) *CommentService {
	return &CommentService{client: client, collectionID: commentsCollectionID}
}

// ForPost returns every comment on postID, oldest first - normal thread order, mirrors
// web/src/hooks/useComments.ts's `sort: "createdAt"`.
func (s *CommentService) ForPost(ctx context.Context, token, postID string) ([]models.Comment, error) {
	result, err := mbase.List[models.Comment](ctx, s.client, token, s.collectionID, mbase.ListParams{
		Filter: map[string]interface{}{"postId": postID},
		Sort:   "createdAt",
		Limit:  commentsPageLimit,
	})
	if err != nil {
		return nil, fmt.Errorf("store: listing comments for post %s: %w", postID, err)
	}
	return result.Data, nil
}

// Create inserts a new comment on postID, authored by authorID/authorName.
func (s *CommentService) Create(ctx context.Context, token, postID, authorID, authorName, content string) (models.Comment, error) {
	comment, err := mbase.Create[models.Comment](ctx, s.client, token, s.collectionID, map[string]interface{}{
		"postId":     postID,
		"authorId":   authorID,
		"authorName": authorName,
		"content":    content,
	})
	if err != nil {
		return models.Comment{}, fmt.Errorf("store: creating comment on post %s: %w", postID, err)
	}
	return comment, nil
}
