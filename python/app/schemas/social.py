"""Mirrors web/src/types/like.ts and web/src/types/follow.ts. Both
collections have no compound unique index, so uniqueness (one row per
postId+userId, or per followerId+followingId) is enforced at the application
layer by the services in app/services/likes.py and app/services/follows.py —
a check-then-act query immediately before create/delete, a reasonable (not
airtight) guard against a double-click/double-tab race for a demo app."""

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class Like(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    id: str = Field(alias="_id")
    post_id: str = Field(alias="postId")
    user_id: str = Field(alias="userId")
    created_at: datetime | None = Field(default=None, alias="createdAt")


class Follow(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    id: str = Field(alias="_id")
    follower_id: str = Field(alias="followerId")
    following_id: str = Field(alias="followingId")
    following_name: str | None = Field(default=None, alias="followingName")
    created_at: datetime | None = Field(default=None, alias="createdAt")
