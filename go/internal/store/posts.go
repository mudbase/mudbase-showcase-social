// Package store implements every domain operation this app needs against the four Mudbase
// collections (posts, comments, likes, follows), on top of internal/mbase's generic CRUD helpers.
package store

import (
	"context"
	"fmt"

	"github.com/mudbase/mudbase-showcase-social/go/internal/mbase"
	"github.com/mudbase/mudbase-showcase-social/go/internal/models"
)

// feedPageLimit mirrors the reference web app's default page size (web/src/hooks/usePostsFeed.ts).
const feedPageLimit = 10

// profilePostsLimit bounds how many of a single author's posts a profile page renders.
const profilePostsLimit = 50

// PostService implements every operation the app needs against the `posts` collection.
type PostService struct {
	client       *mbase.Client
	collectionID string
}

// NewPostService builds a PostService bound to the given posts collection ID.
func NewPostService(client *mbase.Client, postsCollectionID string) *PostService {
	return &PostService{client: client, collectionID: postsCollectionID}
}

// Feed returns one newest-first page of posts, plus whether a next page exists.
func (s *PostService) Feed(ctx context.Context, token string, page int32) (posts []models.Post, hasMore bool, err error) {
	if page < 1 {
		page = 1
	}
	result, err := mbase.List[models.Post](ctx, s.client, token, s.collectionID, mbase.ListParams{
		Sort:  "-createdAt",
		Page:  page,
		Limit: feedPageLimit,
	})
	if err != nil {
		return nil, false, fmt.Errorf("store: listing feed page %d: %w", page, err)
	}
	return result.Data, page < result.TotalPages, nil
}

// ByID fetches a single post by its Mudbase document ID.
func (s *PostService) ByID(ctx context.Context, token, id string) (models.Post, error) {
	post, err := mbase.Get[models.Post](ctx, s.client, token, s.collectionID, id)
	if err != nil {
		return models.Post{}, fmt.Errorf("store: fetching post %s: %w", id, err)
	}
	return post, nil
}

// ByAuthor returns every post by authorID, newest first, plus the total count (used for a
// profile's post-count stat, per the pagination.total the real API already returns).
func (s *PostService) ByAuthor(ctx context.Context, token, authorID string) ([]models.Post, int32, error) {
	result, err := mbase.List[models.Post](ctx, s.client, token, s.collectionID, mbase.ListParams{
		Filter: map[string]interface{}{"authorId": authorID},
		Sort:   "-createdAt",
		Limit:  profilePostsLimit,
	})
	if err != nil {
		return nil, 0, fmt.Errorf("store: listing posts for author %s: %w", authorID, err)
	}
	return result.Data, result.Total, nil
}

// MostRecentByAuthor returns authorID's single most recent post, ok=false if they have none yet -
// used by ProfileService.ResolveDisplayName to recover a display name with no `users` collection.
func (s *PostService) MostRecentByAuthor(ctx context.Context, token, authorID string) (post models.Post, ok bool, err error) {
	result, err := mbase.List[models.Post](ctx, s.client, token, s.collectionID, mbase.ListParams{
		Filter: map[string]interface{}{"authorId": authorID},
		Sort:   "-createdAt",
		Limit:  1,
	})
	if err != nil {
		return models.Post{}, false, fmt.Errorf("store: fetching most recent post for author %s: %w", authorID, err)
	}
	if len(result.Data) == 0 {
		return models.Post{}, false, nil
	}
	return result.Data[0], true, nil
}

// Create inserts a new post owned by authorID/authorName, with counters starting at zero.
func (s *PostService) Create(ctx context.Context, token, authorID, authorName, content, imageURL string) (models.Post, error) {
	body := map[string]interface{}{
		"authorId":      authorID,
		"authorName":    authorName,
		"content":       content,
		"likesCount":    0,
		"commentsCount": 0,
	}
	if imageURL != "" {
		body["imageUrl"] = imageURL
	}
	post, err := mbase.Create[models.Post](ctx, s.client, token, s.collectionID, body)
	if err != nil {
		return models.Post{}, fmt.Errorf("store: creating post: %w", err)
	}
	return post, nil
}

// bumpCounter reads the current post, applies delta to whichever counter field name identifies
// (never below zero), and patches it back. There is no atomic $inc on this collection API, so this
// is a read-modify-write - the same "check-then-act is fine for a demo" tradeoff the likes/follows
// uniqueness guards make (see models.Like's doc comment), not a strictly race-free counter.
func (s *PostService) bumpCounter(ctx context.Context, token, postID, field string, delta int64) error {
	post, err := s.ByID(ctx, token, postID)
	if err != nil {
		return err
	}
	var current int64
	switch field {
	case "likesCount":
		current = post.LikesCount
	case "commentsCount":
		current = post.CommentsCount
	default:
		return fmt.Errorf("store: unknown counter field %q", field)
	}
	next := current + delta
	if next < 0 {
		next = 0
	}
	if _, err := mbase.Update[models.Post](ctx, s.client, token, s.collectionID, postID, map[string]interface{}{
		field: next,
	}); err != nil {
		return fmt.Errorf("store: updating post %s counter %s: %w", postID, field, err)
	}
	return nil
}

// BumpLikesCount adjusts a post's likesCount by delta (+1 on like, -1 on unlike).
func (s *PostService) BumpLikesCount(ctx context.Context, token, postID string, delta int64) error {
	return s.bumpCounter(ctx, token, postID, "likesCount", delta)
}

// BumpCommentsCount adjusts a post's commentsCount by delta (+1 on new comment).
func (s *PostService) BumpCommentsCount(ctx context.Context, token, postID string, delta int64) error {
	return s.bumpCounter(ctx, token, postID, "commentsCount", delta)
}
