"""Mirrors web/src/types/comment.ts."""

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator

_MAX_CONTENT_LENGTH = 300


class Comment(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    id: str = Field(alias="_id")
    post_id: str = Field(alias="postId")
    author_id: str = Field(alias="authorId")
    author_name: str = Field(alias="authorName")
    content: str
    created_at: datetime | None = Field(default=None, alias="createdAt")


class CommentFormValues(BaseModel):
    """Validated shape of the comment composer. Mirrors the zod schema in
    web/src/components/comments/CommentComposer.tsx (300-char cap)."""

    content: str = Field(min_length=1, max_length=_MAX_CONTENT_LENGTH)

    @field_validator("content")
    @classmethod
    def _strip_content(cls, value: str) -> str:
        stripped = value.strip()
        if not stripped:
            raise ValueError("Write a comment before submitting.")
        return stripped
