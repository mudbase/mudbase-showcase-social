"""Mirrors web/src/types/post.ts. Field aliases match the raw Mudbase
document shape (camelCase, `_id`) so `Post.model_validate(doc)` works
directly off a `DataApi` response dict — no separate mapping layer."""

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator

_MAX_CONTENT_LENGTH = 500


class Post(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    id: str = Field(alias="_id")
    author_id: str = Field(alias="authorId")
    author_name: str = Field(alias="authorName")
    content: str
    image_url: str | None = Field(default=None, alias="imageUrl")
    likes_count: int = Field(default=0, alias="likesCount")
    comments_count: int = Field(default=0, alias="commentsCount")
    created_at: datetime | None = Field(default=None, alias="createdAt")
    updated_at: datetime | None = Field(default=None, alias="updatedAt")


class PostFormValues(BaseModel):
    """Validated shape of the post composer. Mirrors the zod schema in
    web/src/components/feed/PostComposer.tsx (500-char cap, optional
    http(s) image URL — see that project's "Known limitations" for why an
    image URL is a text field rather than a file upload: bucket/file
    creation is gated to org-level owner/admin/developer system roles,
    unreachable by any project end-user)."""

    content: str = Field(min_length=1, max_length=_MAX_CONTENT_LENGTH)
    image_url: str = ""

    @field_validator("content")
    @classmethod
    def _strip_content(cls, value: str) -> str:
        stripped = value.strip()
        if not stripped:
            raise ValueError("Write something before posting.")
        return stripped

    @field_validator("image_url")
    @classmethod
    def _validate_image_url(cls, value: str) -> str:
        stripped = value.strip()
        if stripped and not (stripped.startswith("http://") or stripped.startswith("https://")):
            raise ValueError("Enter a valid image URL")
        return stripped
