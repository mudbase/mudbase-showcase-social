"""Profile page support. No `users` collection exists in this data model
(see plan/build-plan.md "Known limitations"), so a profile has no
server-side source of truth for a display name — every author/commenter/
follower name is denormalized onto the row that references them instead.
`resolve_display_name` best-efforts a name for a given user id: their most
recent post's `authorName`, falling back to any `followingName` recorded by
someone who follows them, falling back to the literal string "Member" if
neither exists yet (e.g. a brand-new account that has only ever followed
people, never posted, and has no followers).
"""

from pydantic import BaseModel

from app.services.follows import count_followers, count_following, find_any_follow_naming
from app.services.posts import count_posts_by_author, get_latest_post_by_author

_FALLBACK_DISPLAY_NAME = "Member"


class ProfileStats(BaseModel):
    display_name: str
    post_count: int
    follower_count: int
    following_count: int


async def resolve_display_name(user_id: str, *, access_token: str | None = None) -> str:
    latest_post = await get_latest_post_by_author(user_id, access_token=access_token)
    if latest_post is not None:
        return latest_post.author_name

    naming_follow = await find_any_follow_naming(user_id, access_token=access_token)
    if naming_follow is not None and naming_follow.following_name:
        return naming_follow.following_name

    return _FALLBACK_DISPLAY_NAME


async def get_profile_stats(user_id: str, *, access_token: str | None = None) -> ProfileStats:
    display_name = await resolve_display_name(user_id, access_token=access_token)
    post_count = await count_posts_by_author(user_id, access_token=access_token)
    follower_count = await count_followers(user_id, access_token=access_token)
    following_count = await count_following(user_id, access_token=access_token)
    return ProfileStats(
        display_name=display_name,
        post_count=post_count,
        follower_count=follower_count,
        following_count=following_count,
    )
