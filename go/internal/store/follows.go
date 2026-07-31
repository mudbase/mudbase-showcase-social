package store

import (
	"context"
	"fmt"

	"github.com/mudbase/mudbase-showcase-social/go/internal/mbase"
	"github.com/mudbase/mudbase-showcase-social/go/internal/models"
)

// FollowService implements every operation the app needs against the `follows` collection.
type FollowService struct {
	client       *mbase.Client
	collectionID string
}

// NewFollowService builds a FollowService bound to the given follows collection ID.
func NewFollowService(client *mbase.Client, followsCollectionID string) *FollowService {
	return &FollowService{client: client, collectionID: followsCollectionID}
}

// findFollow looks up the (followerID, followingID) follow row, ok=false if none exists.
func (s *FollowService) findFollow(ctx context.Context, token, followerID, followingID string) (follow models.Follow, ok bool, err error) {
	result, err := mbase.List[models.Follow](ctx, s.client, token, s.collectionID, mbase.ListParams{
		Filter: map[string]interface{}{"followerId": followerID, "followingId": followingID},
		Limit:  1,
	})
	if err != nil {
		return models.Follow{}, false, fmt.Errorf("store: looking up follow %s->%s: %w", followerID, followingID, err)
	}
	if len(result.Data) == 0 {
		return models.Follow{}, false, nil
	}
	return result.Data[0], true, nil
}

// IsFollowing reports whether followerID currently follows followingID.
func (s *FollowService) IsFollowing(ctx context.Context, token, followerID, followingID string) (bool, error) {
	_, ok, err := s.findFollow(ctx, token, followerID, followingID)
	return ok, err
}

// Toggle follows followingID for followerID if not already following, or unfollows if already
// following - the same check-then-act tradeoff as LikeService.Toggle. followingName is
// denormalized onto the row (see models.Follow) so followingID's profile can resolve a display
// name even if they've never posted. Returns the new following state.
func (s *FollowService) Toggle(ctx context.Context, token, followerID, followingID, followingName string) (following bool, err error) {
	existing, ok, err := s.findFollow(ctx, token, followerID, followingID)
	if err != nil {
		return false, err
	}

	if ok {
		if err := mbase.Delete(ctx, s.client, token, s.collectionID, existing.ID); err != nil {
			return false, fmt.Errorf("store: removing follow: %w", err)
		}
		return false, nil
	}

	body := map[string]interface{}{
		"followerId":  followerID,
		"followingId": followingID,
	}
	if followingName != "" {
		body["followingName"] = followingName
	}
	if _, err := mbase.Create[models.Follow](ctx, s.client, token, s.collectionID, body); err != nil {
		return false, fmt.Errorf("store: creating follow: %w", err)
	}
	return true, nil
}

// FollowerCount returns how many accounts follow userID, via pagination.Total on a limit-1 query -
// no need to fetch the rows themselves for a plain count.
func (s *FollowService) FollowerCount(ctx context.Context, token, userID string) (int32, error) {
	result, err := mbase.List[models.Follow](ctx, s.client, token, s.collectionID, mbase.ListParams{
		Filter: map[string]interface{}{"followingId": userID},
		Limit:  1,
	})
	if err != nil {
		return 0, fmt.Errorf("store: counting followers for %s: %w", userID, err)
	}
	return result.Total, nil
}

// FollowingCount returns how many accounts userID follows.
func (s *FollowService) FollowingCount(ctx context.Context, token, userID string) (int32, error) {
	result, err := mbase.List[models.Follow](ctx, s.client, token, s.collectionID, mbase.ListParams{
		Filter: map[string]interface{}{"followerId": userID},
		Limit:  1,
	})
	if err != nil {
		return 0, fmt.Errorf("store: counting following for %s: %w", userID, err)
	}
	return result.Total, nil
}

// AnyFollowingNameFor returns the followingName recorded by anyone who follows userID, ok=false if
// nobody follows them yet or none of their followers' rows carry a name - used as the second
// fallback in ProfileService.ResolveDisplayName.
func (s *FollowService) AnyFollowingNameFor(ctx context.Context, token, userID string) (name string, ok bool, err error) {
	result, err := mbase.List[models.Follow](ctx, s.client, token, s.collectionID, mbase.ListParams{
		Filter: map[string]interface{}{"followingId": userID},
		Limit:  20,
	})
	if err != nil {
		return "", false, fmt.Errorf("store: looking up a following name for %s: %w", userID, err)
	}
	for _, follow := range result.Data {
		if follow.FollowingName != "" {
			return follow.FollowingName, true, nil
		}
	}
	return "", false, nil
}
