package models

// Follow mirrors the `follows` Mudbase collection schema. FollowingName is denormalized at write
// time so a profile page can resolve a display name for a user who has never posted - there is no
// `users` collection in this schema (see store.ProfileService.ResolveDisplayName and README
// "Known limitations"). Same check-then-act uniqueness guard as Like.
type Follow struct {
	ID            string `json:"_id"`
	CreatedAt     string `json:"createdAt"`
	UpdatedAt     string `json:"updatedAt"`
	FollowerID    string `json:"followerId"`
	FollowingID   string `json:"followingId"`
	FollowingName string `json:"followingName,omitempty"`
}
