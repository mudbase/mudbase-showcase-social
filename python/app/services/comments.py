"""comments collection: same permission shape as posts (public read,
`customer`-only write). Comments are always fetched oldest-first (normal
thread order), matching the reference web app's `useComments`.
"""

import asyncio
import logging
from typing import Any

from app.config import get_settings
from app.mudbase_client import MudbaseApiError, create_data_sync, list_data_sync
from app.schemas.comment import Comment, CommentFormValues
from app.services.posts import adjust_post_counts

logger = logging.getLogger(__name__)

_COMMENTS_LIMIT = 100  # Mudbase's DataApi.list_data caps `limit` at 100 server-side.


async def list_comments(post_id: str, *, access_token: str | None = None) -> list[Comment]:
    settings = get_settings()
    result = await asyncio.to_thread(
        list_data_sync,
        settings.comments_collection_id,
        filter_dict={"postId": post_id},
        sort="createdAt",
        limit=_COMMENTS_LIMIT,
        access_token=access_token,
    )
    return [Comment.model_validate(doc) for doc in result["data"]]


async def create_comment(
    post_id: str,
    values: CommentFormValues,
    *,
    author_id: str,
    author_name: str,
    access_token: str,
) -> Comment:
    settings = get_settings()
    body: dict[str, Any] = {
        "postId": post_id,
        "authorId": author_id,
        "authorName": author_name,
        "content": values.content,
    }
    doc = await asyncio.to_thread(create_data_sync, settings.comments_collection_id, body, access_token=access_token)
    comment = Comment.model_validate(doc)
    # The comment row is already committed at this point — a failure updating
    # the post's `commentsCount` denormalized counter is logged, not raised,
    # so a real, successful comment is never reported to the caller as
    # failed just because the cosmetic counter didn't refresh (same
    # best-effort rationale as app/services/likes.py::_adjust_likes_count_best_effort).
    try:
        await adjust_post_counts(post_id, comments_delta=1, access_token=access_token)
    except MudbaseApiError as exc:
        logger.warning(
            "Comment on post %s was created but the commentsCount counter update failed: %s", post_id, exc.message
        )
    return comment
