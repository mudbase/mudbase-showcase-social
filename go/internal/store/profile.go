package store

import (
	"context"
	"fmt"
)

// ProfileService composes PostService and FollowService to resolve the one thing this schema has
// no direct source of truth for: a display name for an arbitrary user ID. There is no `users`
// collection (see README "Known limitations") - every author/follower name is denormalized onto
// the row that references them instead.
type ProfileService struct {
	posts   *PostService
	follows *FollowService
}

// NewProfileService builds a ProfileService over the given posts and follows services.
func NewProfileService(posts *PostService, follows *FollowService) *ProfileService {
	return &ProfileService{posts: posts, follows: follows}
}

// ResolveDisplayName best-efforts a name for userID: their most recent post's authorName, falling
// back to any followingName recorded by someone who follows them, falling back to the literal
// string "Member" if neither exists yet (e.g. a brand-new account that has only ever followed
// people, never posted, and has no followers) - mirrors the reference web app's
// useResolvedDisplayName (web/src/hooks/useProfileStats.ts).
func (s *ProfileService) ResolveDisplayName(ctx context.Context, token, userID string) (string, error) {
	post, ok, err := s.posts.MostRecentByAuthor(ctx, token, userID)
	if err != nil {
		return "", fmt.Errorf("store: resolving display name for %s: %w", userID, err)
	}
	if ok && post.AuthorName != "" {
		return post.AuthorName, nil
	}

	name, ok, err := s.follows.AnyFollowingNameFor(ctx, token, userID)
	if err != nil {
		return "", fmt.Errorf("store: resolving display name for %s: %w", userID, err)
	}
	if ok {
		return name, nil
	}

	return "Member", nil
}
