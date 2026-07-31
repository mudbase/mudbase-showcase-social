package models

// Like mirrors the `likes` Mudbase collection schema - one row per (postId, userId) pair. This
// collection type has no compound unique index, so uniqueness is enforced at the application
// layer (see store.LikeService.Toggle's check-then-act query) - a reasonable, not airtight, guard
// against a double-click/double-tab race, matching the reference web app's own documented
// tradeoff (web/plan/build-plan.md).
type Like struct {
	ID        string `json:"_id"`
	CreatedAt string `json:"createdAt"`
	UpdatedAt string `json:"updatedAt"`
	PostID    string `json:"postId"`
	UserID    string `json:"userId"`
}
