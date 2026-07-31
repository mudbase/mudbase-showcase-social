"""Post detail: full post, comment thread, comment composer, like toggle.
Mirrors web/src/app/posts/[id]/page.tsx.
"""

from typing import Annotated

from fastapi import APIRouter, Form, Request
from fastapi.responses import HTMLResponse, RedirectResponse
from pydantic import ValidationError

from app.context import build_base_context
from app.mudbase_client import MudbaseApiError
from app.schemas.comment import Comment, CommentFormValues
from app.schemas.post import Post
from app.services import comments as comments_service
from app.services import likes as likes_service
from app.services import posts as posts_service
from app.session import call_with_reauth, ensure_anonymous_session, get_session_user, get_valid_access_token, set_flash
from app.templates_env import templates

router = APIRouter()


@router.get("/posts/{post_id}", response_class=HTMLResponse, response_model=None)
async def post_detail(request: Request, post_id: str) -> HTMLResponse:
    await ensure_anonymous_session(request)
    token = await get_valid_access_token(request)
    user = get_session_user(request)

    post: Post | None
    comments: list[Comment]
    try:
        if token:
            post, _token = await call_with_reauth(
                request, token, lambda t: posts_service.get_post(post_id, access_token=t)
            )
            comments, _token = await call_with_reauth(
                request, token, lambda t: comments_service.list_comments(post_id, access_token=t)
            )
        else:
            post = await posts_service.get_post(post_id, access_token=None)
            comments = await comments_service.list_comments(post_id, access_token=None)
    except MudbaseApiError:
        post, comments = None, []

    is_liked = False
    if post is not None and user is not None and user.is_customer and token:
        try:
            like, _token = await call_with_reauth(
                request, token, lambda t: likes_service.find_like(post_id, user.id, access_token=t)
            )
            is_liked = like is not None
        except MudbaseApiError:
            is_liked = False

    context = await build_base_context(request)
    context.update(
        {
            "post": post,
            "comments": comments,
            "is_liked": is_liked,
            "errors": {},
        }
    )
    status_code = 200 if post is not None else 404
    return templates.TemplateResponse(request=request, name="post_detail.html", context=context, status_code=status_code)


@router.post("/posts/{post_id}/comments", response_model=None)
async def create_comment_submit(
    request: Request,
    post_id: str,
    content: Annotated[str, Form()],
) -> HTMLResponse | RedirectResponse:
    user = get_session_user(request)
    if user is None or not user.is_customer:
        set_flash(request, "Sign in to comment.", "info")
        return RedirectResponse(f"/login?next=/posts/{post_id}", status_code=303)

    token = await get_valid_access_token(request)
    if not token:
        return RedirectResponse(f"/login?next=/posts/{post_id}", status_code=303)

    try:
        values = CommentFormValues(content=content)
    except ValidationError:
        set_flash(request, "Write a comment before submitting.", "error")
        return RedirectResponse(f"/posts/{post_id}", status_code=303)

    try:
        await comments_service.create_comment(
            post_id, values, author_id=user.id, author_name=user.display_name, access_token=token
        )
    except MudbaseApiError as exc:
        set_flash(request, f"Couldn't post that comment: {exc.message}", "error")
        return RedirectResponse(f"/posts/{post_id}", status_code=303)

    return RedirectResponse(f"/posts/{post_id}", status_code=303)


@router.post("/posts/{post_id}/like", response_model=None)
async def toggle_like_submit(request: Request, post_id: str, next: Annotated[str | None, Form()] = None) -> RedirectResponse:
    destination = next or f"/posts/{post_id}"
    user = get_session_user(request)
    if user is None or not user.is_customer:
        set_flash(request, "Sign in to like posts.", "info")
        return RedirectResponse(f"/login?next={destination}", status_code=303)

    token = await get_valid_access_token(request)
    if not token:
        return RedirectResponse(f"/login?next={destination}", status_code=303)

    try:
        await likes_service.toggle_like(post_id, user.id, access_token=token)
    except MudbaseApiError as exc:
        set_flash(request, f"Couldn't update that like: {exc.message}", "error")

    return RedirectResponse(destination, status_code=303)
