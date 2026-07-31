"""likes collection: one row per (postId, userId) pair. This collection type
has no compound unique index, so uniqueness is enforced at the application
layer — every toggle re-queries `{postId, userId}` immediately before
creating/deleting, a reasonable (not airtight) guard against a
double-click/double-tab race, matching the reference web app's
`useToggleLike`.
"""

import asyncio
import logging

from app.config import get_settings
from app.mudbase_client import MudbaseApiError, create_data_sync, delete_data_sync, list_data_sync
from app.schemas.social import Like
from app.services.posts import adjust_post_counts

logger = logging.getLogger(__name__)


async def find_like(post_id: str, user_id: str, *, access_token: str | None = None) -> Like | None:
    settings = get_settings()
    result = await asyncio.to_thread(
        list_data_sync,
        settings.likes_collection_id,
        filter_dict={"postId": post_id, "userId": user_id},
        limit=1,
        access_token=access_token,
    )
    docs = result["data"]
    return Like.model_validate(docs[0]) if docs else None


async def list_liked_post_ids(user_id: str, *, access_token: str) -> set[str]:
    """Used by the feed/profile pages to render each post's like button in
    its correct (already-liked or not) state for the current visitor.

    Capped at 100 rows (see the `limit` comment below) — a visitor with more
    than 100 likes on record will see the like button on some of their
    older-liked posts render as not-liked. This is an explicit, accepted
    tradeoff for a demo app (same precedent as `comments.py::list_comments`'s
    100-row cap), not an oversight: the like/comment counts on the post
    itself are unaffected either way, only this per-viewer overlay."""
    settings = get_settings()
    result = await asyncio.to_thread(
        list_data_sync,
        settings.likes_collection_id,
        filter_dict={"userId": user_id},
        limit=100,  # Mudbase's DataApi.list_data caps `limit` at 100 server-side.
        access_token=access_token,
    )
    return {Like.model_validate(doc).post_id for doc in result["data"]}


async def toggle_like(post_id: str, user_id: str, *, access_token: str) -> bool:
    """Returns the new liked state (True if now liked, False if now unliked).

    The like row itself (create/delete) is the operation that determines
    success — once it commits, the toggle has genuinely happened. The
    `likesCount` counter update on `posts` is a best-effort denormalization
    on top of that: if it fails (e.g. a transient Mudbase error), the failure
    is logged rather than raised, so a real like/unlike is never reported to
    the caller as failed just because the cosmetic counter didn't refresh.
    Mudbase has no atomic `$inc`, so a lost counter update here is a rare,
    self-correcting drift (the next real toggle on the same post reads the
    stale count and adjusts from there) rather than a compounding one.
    """
    settings = get_settings()
    existing = await find_like(post_id, user_id, access_token=access_token)
    if existing is not None:
        await asyncio.to_thread(delete_data_sync, settings.likes_collection_id, existing.id, access_token=access_token)
        await _adjust_likes_count_best_effort(post_id, delta=-1, access_token=access_token)
        return False

    await asyncio.to_thread(
        create_data_sync,
        settings.likes_collection_id,
        {"postId": post_id, "userId": user_id},
        access_token=access_token,
    )
    await _adjust_likes_count_best_effort(post_id, delta=1, access_token=access_token)
    return True


async def _adjust_likes_count_best_effort(post_id: str, *, delta: int, access_token: str) -> None:
    try:
        await adjust_post_counts(post_id, likes_delta=delta, access_token=access_token)
    except MudbaseApiError as exc:
        logger.warning(
            "Like toggle for post %s succeeded but the likesCount counter update failed: %s", post_id, exc.message
        )
