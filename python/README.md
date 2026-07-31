# Mudbase Showcase — Social (Python)

A server-rendered **FastAPI + Jinja2** reimplementation of the reference social micro-blog at
[`../web`](../web), backed entirely by the real **Mudbase Python SDK**
(`mudbase-sdk`, generated via OpenAPI Generator, published at
[github.com/mudbase/mudbase-sdk](https://github.com/mudbase/mudbase-sdk)) — same Mudbase project,
same collections, same business rules, different stack and delivery model (request/response HTML
instead of a client-side SPA talking directly to `cloud.mudbase.dev`). Architecture and
conventions mirror the sibling [`../../ecommerce/python`](../../ecommerce/python) port exactly.

## Stack

FastAPI (async) + Jinja2 templates + vanilla CSS (no bundler, no client-side JS beyond plain HTML
forms). Session state (the Mudbase JWT, refresh token, and user profile) lives only in a signed,
httpOnly Starlette session cookie — it is never sent to browser JS, unlike the reference SPA which
necessarily holds its token in `localStorage` for direct browser-to-Mudbase calls.

## What's implemented

| Feature | Where |
|---|---|
| Guest feed browsing (anonymous Mudbase session) | `app/session.py::ensure_anonymous_session` |
| Registration / login / logout | `app/routers/auth.py`, `app/services/auth_service.py` |
| Email verification gate + completion | `app/routers/auth.py::verify_email_page`, `app/templates/verify_email.html` |
| Paginated feed, newest first | `app/routers/feed.py`, `app/services/posts.py::list_feed` |
| Post composer (text + optional image URL) | `app/templates/index.html`, `app/schemas/post.py` |
| Post detail + comment thread (oldest-first) | `app/routers/posts.py`, `app/services/comments.py` |
| Like / unlike (check-then-act, counter PATCH) | `app/services/likes.py` |
| Follow / unfollow (check-then-act) | `app/services/follows.py` |
| Profile: resolved display name, follower/following/post counts | `app/services/profiles.py` |
| Auth-gated writes, public reads | enforced by Mudbase collection permissions; this app's checks are UX gating only |

Every `posts`/`comments`/`likes`/`follows` collection read/write goes through the real
`mudbase_sdk.DataApi` and `mudbase_sdk.AuthenticationApi`/`MultiRoleFeatureApi`/`UsersApi` against
`cloud.mudbase.dev` (see `app/mudbase_client.py`).

## No realtime (deliberate)

The reference web app subscribes to a Socket.IO room so new posts and counter updates appear live.
This port — like the sibling ecommerce Python port — is plain request/response HTML: a page reload
(or the feed's pagination links) is how you see activity from other users. See `plan/build-plan.md`
"Stack Decisions" for the precedent this follows.

## Setup

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # fill in your provisioned project's IDs (see ../web/README.md "Provisioning")
python -c "import secrets; print(secrets.token_urlsafe(48))"   # → SESSION_SECRET_KEY
uvicorn app.main:app --reload
```

Visit `http://localhost:8000`. Register a new account via `/register` (this project requires email
verification — you'll get a "check your inbox" message, not an instant session) or sign in with an
already-verified account via `/login`.

### Type checking

```bash
pip install mypy
mypy app   # strict mode, config in mypy.ini — reports zero issues
```

## Architecture notes

- **`app/mudbase_client.py`** wraps the real (synchronous, urllib3-based) `mudbase_sdk` with
  `asyncio.to_thread` adapters so FastAPI's async handlers never block the event loop. Ported
  verbatim from the ecommerce Python port, including the two auth calls that bypass the generated
  typed wrapper methods (`login_sync` needs `customRole`, which the generated login response model
  omits) — see that file's module docstring for the full history.
- **`app/session.py`** ports the ecommerce port's refresh strategy verbatim: `get_valid_access_token`
  proactively refreshes within a margin of expiry; `call_with_reauth` reactively retries once on a
  401 the margin check didn't predict.
- **Mudbase's `DataApi.list_data` caps `limit` at 100** server-side (an SDK-level Pydantic
  constraint) — found live during this build when a `limit=200` call raised a validation error the
  first time a signed-in visitor hit the feed. Every list call in this app respects that ceiling
  (see `plan/build-plan.md` "Real-Project Verification" #1).

## Known limitations (real platform/architecture constraints, not bugs)

**Post images are a pasted URL, not a file upload.** `rbacCheck("file","create")` (both bucket
creation and file upload) only allows the org-level system roles owner/admin/developer. Every
project end-user — including a real, verified `customer` account — always carries system role
`viewer`. `PostFormValues.image_url` is a plain URL text field for this reason, same real
constraint the reference web app and the ecommerce Python port both document.

**No `users` collection, so profile display names are best-effort.** A user who has never posted
and has no followers has no row anywhere recording their name — `app/services/profiles.py`'s
`resolve_display_name` falls back to the literal string "Member" in that case.

**No in-app email-verification resend.** The resend endpoint requires a valid JWT, which an
unverified account cannot obtain (login is blocked until verified) — there is no accessible way
around this from a project end-user's own permissions.

**No realtime.** See "No realtime (deliberate)" above.

**`requireEmailVerification` must be on for this project** for the register/login flow to behave as
implemented (no session on signup, a flash message instead). This project has it on (verified
live) — `/register` always shows "check your inbox" and never starts a session directly.

## Live verification

Structural verification (routing, auth-gating, validation, 404 handling, the `limit<=100` SDK bug)
was done live against the running app and the real backend. **A full authenticated write round-trip
(post/like/comment/follow) was not completed for this specific port** — the platform's login rate
limit did not clear even after a clean, request-free 15-minute wait, which pointed to an escalating
lockout rather than a simple cooldown, so further retries were stopped rather than continued
indefinitely. See `plan/build-plan.md` "Real-Project Verification" and "Live Smoke Test Results" for
the full, honest account, including why confidence in the port is still high (identical, already
proven client code shared with `../../ecommerce/python`, and the reference `../web` app's own
prior live smoke test against this exact project and these exact collections).
