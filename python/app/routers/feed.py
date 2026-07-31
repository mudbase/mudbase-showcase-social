"""Home feed + post composer. Mirrors web/src/app/page.tsx,
src/components/feed/FeedList.tsx and src/components/feed/PostComposer.tsx.

No realtime subscription here (unlike the reference SPA's `usePostsLive`
Socket.IO room) — matching the sibling `mudbase-showcase-ecommerce/python`
port's own precedent ("No realtime seller dashboard... out of scope for a
faithful-but-simpler server-rendered reimplementation"). This is plain
request/response HTML; a page reload (or a pagination link) is how a
visitor sees new activity from other users.
"""

from typing import Annotated

from fastapi import APIRouter, Form, Request
from fastapi.responses import HTMLResponse, RedirectResponse
from pydantic import ValidationError

from app.context import build_base_context
from app.mudbase_client import MudbaseApiError
from app.schemas.pagination import PaginationMeta
from app.schemas.post import Post, PostFormValues
from app.services import likes as likes_service
from app.services import posts as posts_service
from app.session import call_with_reauth, ensure_anonymous_session, get_session_user, get_valid_access_token, set_flash
from app.templates_env import templates

router = APIRouter()


@router.get("/", response_class=HTMLResponse, response_model=None)
async def feed_index(request: Request, page: int = 1) -> HTMLResponse:
    await ensure_anonymous_session(request)
    token = await get_valid_access_token(request)
    user = get_session_user(request)
    safe_page = max(1, page)

    posts: list[Post]
    pagination: PaginationMeta | None
    load_error: str | None
    try:
        if token:
            (posts, pagination), _token = await call_with_reauth(
                request, token, lambda t: posts_service.list_feed(page=safe_page, access_token=t)
            )
        else:
            posts, pagination = await posts_service.list_feed(page=safe_page, access_token=None)
        load_error = None
    except MudbaseApiError as exc:
        posts, pagination, load_error = [], None, f"Couldn't load the feed right now: {exc.message}"

    liked_post_ids: set[str] = set()
    if user is not None and user.is_customer and token:
        try:
            liked_post_ids, _token = await call_with_reauth(
                request, token, lambda t: likes_service.list_liked_post_ids(user.id, access_token=t)
            )
        except MudbaseApiError:
            # The like-state overlay is decoration, not the page's purpose —
            # a Mudbase hiccup here shouldn't block the whole feed from rendering.
            liked_post_ids = set()

    context = await build_base_context(request)
    context.update(
        {
            "posts": posts,
            "pagination": pagination,
            "page": safe_page,
            "load_error": load_error,
            "liked_post_ids": liked_post_ids,
            "errors": {},
            "form_error": None,
        }
    )
    return templates.TemplateResponse(request=request, name="index.html", context=context)


@router.post("/posts", response_model=None)
async def create_post_submit(
    request: Request,
    content: Annotated[str, Form()],
    image_url: Annotated[str, Form()] = "",
) -> HTMLResponse | RedirectResponse:
    user = get_session_user(request)
    if user is None or not user.is_customer:
        set_flash(request, "Sign in to post.", "info")
        return RedirectResponse("/login?next=/", status_code=303)

    token = await get_valid_access_token(request)
    if not token:
        return RedirectResponse("/login?next=/", status_code=303)

    try:
        values = PostFormValues(content=content, image_url=image_url)
    except ValidationError as exc:
        posts, pagination = await posts_service.list_feed(page=1, access_token=token)
        context = await build_base_context(request)
        context.update(
            {
                "posts": posts,
                "pagination": pagination,
                "page": 1,
                "load_error": None,
                "liked_post_ids": set(),
                "errors": _field_errors(exc),
                "form_error": None,
            }
        )
        return templates.TemplateResponse(request=request, name="index.html", context=context, status_code=422)

    try:
        _post, token = await call_with_reauth(
            request,
            token,
            lambda t: posts_service.create_post(values, author_id=user.id, author_name=user.display_name, access_token=t),
        )
    except MudbaseApiError as exc:
        set_flash(request, f"Couldn't publish that post: {exc.message}", "error")
        return RedirectResponse("/", status_code=303)

    set_flash(request, "Posted!", "success")
    return RedirectResponse("/", status_code=303)


def _field_errors(exc: ValidationError) -> dict[str, str]:
    errors: dict[str, str] = {}
    for error in exc.errors():
        field = str(error["loc"][0]) if error["loc"] else "form"
        errors[field] = error["msg"]
    return errors
