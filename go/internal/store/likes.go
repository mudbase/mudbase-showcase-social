package store

import (
	"context"
	"fmt"

	"github.com/mudbase/mudbase-showcase-social/go/internal/mbase"
	"github.com/mudbase/mudbase-showcase-social/go/internal/models"
)

// likedPostIDsLimit bounds how many of the current visitor's own likes are fetched to mark hearts
// filled across a feed/profile page - generous enough that a real demo account never truncates.
const likedPostIDsLimit = 500

// LikeService implements every operation the app needs against the `likes` collection.
type LikeService struct {
	client       *mbase.Client
	collectionID string
	posts        *PostService
}

// NewLikeService builds a LikeService bound to the given likes collection ID. It needs *PostService
// too, since toggling a like also has to bump the post's denormalized likesCount.
func NewLikeService(client *mbase.Client, likesCollectionID string, posts *PostService) *LikeService {
	return &LikeService{client: client, collectionID: likesCollectionID, posts: posts}
}

// findLike looks up the (postID, userID) like row, ok=false if none exists.
func (s *LikeService) findLike(ctx context.Context, token, postID, userID string) (like models.Like, ok bool, err error) {
	result, err := mbase.List[models.Like](ctx, s.client, token, s.collectionID, mbase.ListParams{
		Filter: map[string]interface{}{"postId": postID, "userId": userID},
		Limit:  1,
	})
	if err != nil {
		return models.Like{}, false, fmt.Errorf("store: looking up like for post %s: %w", postID, err)
	}
	if len(result.Data) == 0 {
		return models.Like{}, false, nil
	}
	return result.Data[0], true, nil
}

// IsLiked reports whether userID currently likes postID.
func (s *LikeService) IsLiked(ctx context.Context, token, postID, userID string) (bool, error) {
	_, ok, err := s.findLike(ctx, token, postID, userID)
	return ok, err
}

// Toggle likes postID for userID if not already liked, or unlikes it if it is - a check-then-act
// query immediately before create/delete (see models.Like's doc comment on the tradeoff this
// implies). Either way, the post's denormalized likesCount is bumped to match. Returns the new
// liked state.
func (s *LikeService) Toggle(ctx context.Context, token, postID, userID string) (liked bool, err error) {
	existing, ok, err := s.findLike(ctx, token, postID, userID)
	if err != nil {
		return false, err
	}

	if ok {
		if err := mbase.Delete(ctx, s.client, token, s.collectionID, existing.ID); err != nil {
			return false, fmt.Errorf("store: removing like: %w", err)
		}
		if err := s.posts.BumpLikesCount(ctx, token, postID, -1); err != nil {
			return false, err
		}
		return false, nil
	}

	if _, err := mbase.Create[models.Like](ctx, s.client, token, s.collectionID, map[string]interface{}{
		"postId": postID,
		"userId": userID,
	}); err != nil {
		return false, fmt.Errorf("store: creating like: %w", err)
	}
	if err := s.posts.BumpLikesCount(ctx, token, postID, 1); err != nil {
		return false, err
	}
	return true, nil
}

// LikedPostIDs returns the set of post IDs userID currently likes, as a lookup map so feed/profile
// rendering can mark each post card's heart filled in O(1) per post - mirrors
// web/src/hooks/useLikes.ts's useMyLikedPostIds.
func (s *LikeService) LikedPostIDs(ctx context.Context, token, userID string) (map[string]bool, error) {
	result, err := mbase.List[models.Like](ctx, s.client, token, s.collectionID, mbase.ListParams{
		Filter: map[string]interface{}{"userId": userID},
		Limit:  likedPostIDsLimit,
	})
	if err != nil {
		return nil, fmt.Errorf("store: listing likes for user %s: %w", userID, err)
	}
	ids := make(map[string]bool, len(result.Data))
	for _, like := range result.Data {
		ids[like.PostID] = true
	}
	return ids, nil
}
