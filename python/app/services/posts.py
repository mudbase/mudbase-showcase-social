"""posts collection: public (authenticated, including the anonymous guest
session) read, `customer`-role-only create/update/delete — enforced
server-side by Mudbase collection permissions (see plan/build-plan.md),
not re-checked here.
"""

import asyncio
from typing import Any

from app.config import get_settings
from app.mudbase_client import create_data_sync, get_data_sync, list_data_sync, update_data_sync
from app.schemas.pagination import PaginationMeta
from app.schemas.post import Post, PostFormValues

_FEED_PAGE_SIZE = 10
_AUTHOR_POSTS_LIMIT = 50


async def list_feed(*, page: int = 1, access_token: str | None = None) -> tuple[list[Post], PaginationMeta]:
    settings = get_settings()
    result = await asyncio.to_thread(
        list_data_sync,
        settings.posts_collection_id,
        sort="-createdAt",
        page=page,
        limit=_FEED_PAGE_SIZE,
        access_token=access_token,
    )
    posts = [Post.model_validate(doc) for doc in result["data"]]
    pagination = PaginationMeta.model_validate(result["pagination"]) if result["pagination"] else PaginationMeta()
    return posts, pagination


async def get_post(post_id: str, *, access_token: str | None = None) -> Post | None:
    settings = get_settings()
    doc = await asyncio.to_thread(get_data_sync, settings.posts_collection_id, post_id, access_token=access_token)
    return Post.model_validate(doc) if doc else None


async def list_posts_by_author(author_id: str, *, access_token: str | None = None) -> list[Post]:
    settings = get_settings()
    result = await asyncio.to_thread(
        list_data_sync,
        settings.posts_collection_id,
        filter_dict={"authorId": author_id},
        sort="-createdAt",
        limit=_AUTHOR_POSTS_LIMIT,
        access_token=access_token,
    )
    return [Post.model_validate(doc) for doc in result["data"]]


async def get_latest_post_by_author(author_id: str, *, access_token: str | None = None) -> Post | None:
    """Used by profiles.py's best-effort display-name resolution — see
    plan/build-plan.md "Known limitations" (no `users` collection)."""
    settings = get_settings()
    result = await asyncio.to_thread(
        list_data_sync,
        settings.posts_collection_id,
        filter_dict={"authorId": author_id},
        sort="-createdAt",
        limit=1,
        access_token=access_token,
    )
    docs = result["data"]
    return Post.model_validate(docs[0]) if docs else None


async def count_posts_by_author(author_id: str, *, access_token: str | None = None) -> int:
    settings = get_settings()
    result = await asyncio.to_thread(
        list_data_sync,
        settings.posts_collection_id,
        filter_dict={"authorId": author_id},
        limit=1,
        access_token=access_token,
    )
    pagination = result["pagination"]
    return int(pagination["total"]) if pagination else 0


async def create_post(
    values: PostFormValues,
    *,
    author_id: str,
    author_name: str,
    access_token: str,
) -> Post:
    settings = get_settings()
    body: dict[str, Any] = {
        "authorId": author_id,
        "authorName": author_name,
        "content": values.content,
        "imageUrl": values.image_url or None,
        "likesCount": 0,
        "commentsCount": 0,
    }
    doc = await asyncio.to_thread(create_data_sync, settings.posts_collection_id, body, access_token=access_token)
    return Post.model_validate(doc)


async def adjust_post_counts(
    post_id: str,
    *,
    likes_delta: int = 0,
    comments_delta: int = 0,
    access_token: str,
) -> Post | None:
    """Mudbase collections have no atomic `$inc` — every counter update
    re-reads the current post first, then PATCHes the recomputed value.
    Mirrors the reference web app's `useToggleLike`/`useCreateComment`
    (client-side read-then-write against the same REST contract)."""
    settings = get_settings()
    current = await get_post(post_id, access_token=access_token)
    if current is None:
        return None
    body: dict[str, Any] = {}
    if likes_delta:
        body["likesCount"] = max(0, current.likes_count + likes_delta)
    if comments_delta:
        body["commentsCount"] = max(0, current.comments_count + comments_delta)
    if not body:
        return current
    doc = await asyncio.to_thread(
        update_data_sync, settings.posts_collection_id, post_id, body, access_token=access_token
    )
    return Post.model_validate(doc)
