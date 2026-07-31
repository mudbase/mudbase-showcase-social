"""follows collection: one row per (followerId, followingId) pair, same
check-then-act uniqueness guard as likes.py (see that module's docstring).
`followingName` is denormalized onto the row at write time — see
plan/build-plan.md "Known limitations" for why (no `users` collection to
resolve a display name from otherwise).
"""

import asyncio

from app.config import get_settings
from app.mudbase_client import create_data_sync, delete_data_sync, list_data_sync
from app.schemas.social import Follow


async def find_follow(follower_id: str, following_id: str, *, access_token: str | None = None) -> Follow | None:
    settings = get_settings()
    result = await asyncio.to_thread(
        list_data_sync,
        settings.follows_collection_id,
        filter_dict={"followerId": follower_id, "followingId": following_id},
        limit=1,
        access_token=access_token,
    )
    docs = result["data"]
    return Follow.model_validate(docs[0]) if docs else None


async def count_followers(user_id: str, *, access_token: str | None = None) -> int:
    settings = get_settings()
    result = await asyncio.to_thread(
        list_data_sync,
        settings.follows_collection_id,
        filter_dict={"followingId": user_id},
        limit=1,
        access_token=access_token,
    )
    pagination = result["pagination"]
    return int(pagination["total"]) if pagination else 0


async def count_following(user_id: str, *, access_token: str | None = None) -> int:
    settings = get_settings()
    result = await asyncio.to_thread(
        list_data_sync,
        settings.follows_collection_id,
        filter_dict={"followerId": user_id},
        limit=1,
        access_token=access_token,
    )
    pagination = result["pagination"]
    return int(pagination["total"]) if pagination else 0


async def find_any_follow_naming(user_id: str, *, access_token: str | None = None) -> Follow | None:
    """Used by profiles.py's best-effort display-name resolution: a row
    recorded by anyone who follows `user_id` carries their denormalized
    `followingName`, which is the last fallback before the literal
    string "Member" (see plan/build-plan.md "Known limitations")."""
    settings = get_settings()
    result = await asyncio.to_thread(
        list_data_sync,
        settings.follows_collection_id,
        filter_dict={"followingId": user_id},
        limit=1,
        access_token=access_token,
    )
    docs = result["data"]
    return Follow.model_validate(docs[0]) if docs else None


async def toggle_follow(
    follower_id: str,
    following_id: str,
    *,
    following_name: str | None,
    access_token: str,
) -> bool:
    """Returns the new following state (True if now following, False if now unfollowed)."""
    settings = get_settings()
    existing = await find_follow(follower_id, following_id, access_token=access_token)
    if existing is not None:
        await asyncio.to_thread(
            delete_data_sync, settings.follows_collection_id, existing.id, access_token=access_token
        )
        return False

    await asyncio.to_thread(
        create_data_sync,
        settings.follows_collection_id,
        {"followerId": follower_id, "followingId": following_id, "followingName": following_name},
        access_token=access_token,
    )
    return True
