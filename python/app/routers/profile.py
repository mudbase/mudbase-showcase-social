"""Profile page: resolved display name, follower/following/post counts,
that user's posts, follow/unfollow button. Mirrors web/src/app/users/[userId]
and web/src/app/profile (a thin redirect to the current user's own profile).
"""

from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse, RedirectResponse

from app.context import build_base_context
from app.mudbase_client import MudbaseApiError
from app.schemas.post import Post
from app.services import follows as follows_service
from app.services import likes as likes_service
from app.services import posts as posts_service
from app.services import profiles as profiles_service
from app.services.profiles import ProfileStats
from app.session import call_with_reauth, ensure_anonymous_session, get_session_user, get_valid_access_token, set_flash
from app.templates_env import templates

router = APIRouter()


@router.get("/profile", response_model=None)
async def my_profile_redirect(request: Request) -> RedirectResponse:
    user = get_session_user(request)
    if user is None:
        set_flash(request, "Sign in to view your profile.", "info")
        return RedirectResponse("/login?next=/profile", status_code=303)
    return RedirectResponse(f"/users/{user.id}", status_code=303)


@router.get("/users/{user_id}", response_class=HTMLResponse, response_model=None)
async def user_profile(request: Request, user_id: str) -> HTMLResponse:
    await ensure_anonymous_session(request)
    token = await get_valid_access_token(request)
    current_user = get_session_user(request)

    stats: ProfileStats | None
    user_posts: list[Post]
    load_error: str | None
    try:
        if token:
            stats, _token = await call_with_reauth(
                request, token, lambda t: profiles_service.get_profile_stats(user_id, access_token=t)
            )
            user_posts, _token = await call_with_reauth(
                request, token, lambda t: posts_service.list_posts_by_author(user_id, access_token=t)
            )
        else:
            stats = await profiles_service.get_profile_stats(user_id, access_token=None)
            user_posts = await posts_service.list_posts_by_author(user_id, access_token=None)
        load_error = None
    except MudbaseApiError as exc:
        stats, user_posts, load_error = None, [], f"Couldn't load this profile right now: {exc.message}"

    is_own_profile = current_user is not None and current_user.id == user_id
    is_following = False
    if not is_own_profile and current_user is not None and current_user.is_customer and token:
        try:
            follow, _token = await call_with_reauth(
                request, token, lambda t: follows_service.find_follow(current_user.id, user_id, access_token=t)
            )
            is_following = follow is not None
        except MudbaseApiError:
            is_following = False

    liked_post_ids: set[str] = set()
    if current_user is not None and current_user.is_customer and token:
        try:
            liked_post_ids, _token = await call_with_reauth(
                request, token, lambda t: likes_service.list_liked_post_ids(current_user.id, access_token=t)
            )
        except MudbaseApiError:
            liked_post_ids = set()

    context = await build_base_context(request)
    context.update(
        {
            "profile_user_id": user_id,
            "stats": stats,
            "user_posts": user_posts,
            "load_error": load_error,
            "is_own_profile": is_own_profile,
            "is_following": is_following,
            "liked_post_ids": liked_post_ids,
        }
    )
    return templates.TemplateResponse(request=request, name="profile.html", context=context)


@router.post("/users/{user_id}/follow", response_model=None)
async def toggle_follow_submit(request: Request, user_id: str) -> RedirectResponse:
    current_user = get_session_user(request)
    if current_user is None or not current_user.is_customer:
        set_flash(request, "Sign in to follow people.", "info")
        return RedirectResponse(f"/login?next=/users/{user_id}", status_code=303)

    if current_user.id == user_id:
        set_flash(request, "You can't follow yourself.", "error")
        return RedirectResponse(f"/users/{user_id}", status_code=303)

    token = await get_valid_access_token(request)
    if not token:
        return RedirectResponse(f"/login?next=/users/{user_id}", status_code=303)

    try:
        display_name = await profiles_service.resolve_display_name(user_id, access_token=token)
        await follows_service.toggle_follow(
            current_user.id, user_id, following_name=display_name, access_token=token
        )
    except MudbaseApiError as exc:
        set_flash(request, f"Couldn't update that follow: {exc.message}", "error")

    return RedirectResponse(f"/users/{user_id}", status_code=303)
