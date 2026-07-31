# Build Plan — Mudbase Showcase: Social (Python port)
Generated: 2026-07-31
Mode: port (1 of N language/platform ports of `../web`, the reference implementation)
Type: server-rendered web (fullstack via BaaS, zero custom backend)
Stack: FastAPI + Jinja2 + vanilla CSS/JS, backed entirely by the real Mudbase Python SDK
(`mudbase-sdk`) against `cloud.mudbase.dev` — no ORM, no database of our own, no custom REST API.

## Stack Decisions

- **FastAPI + Jinja2, matching the sibling `mudbase-showcase-ecommerce/python` port exactly**
  (same dependency pins, same `mudbase_sdk` version 2.0.0, same architecture: `app/mudbase_client.py`
  wraps the synchronous SDK with `asyncio.to_thread`, `app/session.py` holds the Mudbase JWT only in
  a signed httpOnly Starlette session cookie — never sent to browser JS). This is the established
  convention for this showcase's Python ports (confirmed by reading that project's `mudbase_client.py`,
  `session.py`, `config.py`, `main.py`, one router/service/schema triad, `requirements.txt`, and
  `mypy.ini` before writing any code here), not a fresh architectural choice.
- **No realtime.** The reference web app subscribes to a Socket.IO room (`usePostsLive`) so new posts
  and counter updates appear live. The sibling ecommerce Python port explicitly does not implement
  its own realtime equivalent ("No realtime seller dashboard... out of scope for a
  faithful-but-simpler server-rendered reimplementation") — this port follows the same precedent.
  This is plain request/response HTML; a page reload (or the pagination/"Load more" links) is how a
  visitor sees new activity, matching the task's explicit "manual refresh is acceptable" allowance.
- **Post images are a pasted URL, not a file upload** — same real platform constraint the reference
  web app and the ecommerce Python port both document (see "Known limitations").

## Real-Project Verification (done live against cloud.mudbase.dev during this build)

1. **`mudbase_sdk.DataApi.list_data`'s `limit` parameter is capped at 100 server-side by the SDK's
   own Pydantic validation** (`Annotated[int, Field(le=100, strict=True)]` in
   `mudbase_sdk/api/data_api.py`) — found live when `list_liked_post_ids` (originally `limit=200`)
   and `list_comments` (originally `limit=200`) both raised a `pydantic_core.ValidationError` at
   runtime the first time a signed-in visitor hit the feed. Both call sites were dropped to
   `limit=100` (see `app/services/likes.py`, `app/services/comments.py`). This is a real
   discrepancy from the reference web app's own `mudbase.ts`, which has no client-side limit cap at
   all (the constraint is enforced only by this SDK version, not by the raw REST API the TS client
   calls directly) — worth flagging for any future SDK regeneration.
2. **The Mudbase login endpoint's IP rate limit is much tighter in practice than the 5/15min
   documented ceiling.** A single verification `curl` against `/api/auth/local/login` before this
   build started, plus one real login attempt through this app's own `/login` route, was enough to
   trip `429 {"error":"Too many requests, please try again later.","retryAfter":900}` — confirmed
   by testing the same two accounts directly with `curl` afterward (both `429`, same `retryAfter`).
   This is the same real constraint the task's own instructions anticipated ("If you hit a 429 on
   login, fall back to these pre-minted tokens").
3. **The task's pre-minted fallback tokens do not validate against the live backend.** Both
   `GET /api/auth/session` (bearer the provided Ava access token) and
   `POST /api/auth/refresh` (body the provided Ava refresh token) were tried directly with `curl`:
   the session check returned `401 {"error":"Invalid token."}` (a signature-verification failure,
   not an expiry — the token's own `exp` claim had ~700s left at the time of the check) and the
   refresh call returned `400 {"error":"Invalid or expired refresh token"}`. Decoding the JWT payload
   locally confirmed the claims looked well-formed (`sub`, `customRole: "customer"`,
   `projectId` matching this project) — the failure is specifically that the live backend's signing
   key does not verify these tokens, not a shape or expiry problem. Live end-to-end verification for
   this port therefore used a real password login once the rate limit cleared (see "Live smoke test
   results" below) rather than the fallback tokens.
4. **Session-cookie injection was used as a diagnostic tool, not a login bypass.** To distinguish
   "my session-cookie handling is broken" from "the provided tokens are bad" without spending more
   rate-limited login attempts, a short throwaway script built a Starlette-compatible signed session
   cookie by hand (same `itsdangerous.TimestampSigner` + base64-JSON scheme as
   `starlette.middleware.sessions.SessionMiddleware`) carrying the task's pre-minted tokens directly.
   The app correctly unsigned it, loaded `SessionUser`, then correctly detected the near-expired
   access token, correctly attempted a proactive refresh per `get_valid_access_token`'s margin logic,
   and correctly surfaced the refresh failure by clearing the session — i.e. this app's own
   session/refresh code path is confirmed working; the tokens themselves were the dead end.

## Data Models (Mudbase Collections — already provisioned, used as-is, not recreated)

Identical to `../web/plan/build-plan.md`'s data model — same collection IDs, same field shapes, same
permissions (`customer` role: create/read/update/delete, `dataScope: "all"`; anonymous `viewer`:
read only). Not repeated in full here; see that file for the complete verified schema and
permission-grant history (findings #7 and #8 in that document — the collections' permissions and an
Atlas cluster capacity issue that were fixed on the platform side before any client code, including
this port, could write successfully).

- **posts** — `6a6cf7d0d07caabbbdfbe9db` — `authorId`, `authorName`, `content`, `imageUrl?`,
  `likesCount`, `commentsCount`.
- **comments** — `6a6cf7d1d07caabbbdfbe9f1` — `postId`, `authorId`, `authorName`, `content`.
- **likes** — `6a6cf81ed07caabbbdfbea20` — `postId`, `userId`. No compound unique index —
  app-layer check-then-act uniqueness (`app/services/likes.py::toggle_like`).
- **follows** — `6a6cf81ed07caabbbdfbea32` — `followerId`, `followingId`, `followingName?`. Same
  check-then-act guard (`app/services/follows.py::toggle_follow`).

## Auth Flow

```
First visit (no session)  → POST /api/auth/anonymous → guest session (role: viewer, customRole: null)
                                                        → can read the feed/posts/comments, cannot write
Register (POST /register) → POST /api/auth/local/signup/customer (agreedToTerms: true required)
                                                        → 201, no token, requireVerification: true
                                                        → verification email queued to the given address
Verify (GET /verify-email?token=...) → app calls POST /api/users/verify-email { token } server-side
                                        as a side effect of the GET (see app/routers/auth.py docstring
                                        for why this differs from the reference SPA's client-side call)
Login (POST /login)       → POST /api/auth/local/login → 403 EMAIL_VERIFICATION_REQUIRED until verified
                                                        → 200 + token/refreshToken once verified
                                                        → stored server-side only (Starlette session
                                                          cookie, never sent to browser JS)
Logout (POST /logout)     → POST /api/auth/logout (revokes token + kills session) → clears local session
```

Session refresh: `app/session.py` ports the ecommerce Python port's `get_valid_access_token`
(proactive, margin-based refresh) and `call_with_reauth` (reactive, retry-once-on-401) verbatim —
see that project's `session.py` docstring for the full rationale. This is the same idea as the
reference web app's `MudbaseClient.request()` 401→refresh→retry pattern (`web/src/lib/mudbase.ts`),
adapted for a server-held session instead of a browser-held one.

## No Realtime (deliberate, see "Stack Decisions")

The feed, post detail, and profile pages are plain request/response HTML. A "Load more"/page-number
pagination control on the feed and a page reload are how a visitor sees new posts, likes, comments,
or follows made by someone else — there is no Socket.IO subscription anywhere in this port.

## UI Pages

- `/` — feed: composer (auth-gated with a "sign in to post" prompt for guests) + paginated post list
  (newest first, `?page=`), each post's like button reflecting the current visitor's own like state.
- `/posts/{id}` — post detail: full post, comment thread (oldest-first), comment composer (auth-gated),
  like toggle.
- `/users/{userId}` — profile: best-effort resolved display name (see "Known limitations"),
  follower/following/post counts, that user's posts, follow/unfollow button (hidden on your own
  profile).
- `/profile` — thin redirect to `/users/{current_user_id}` (or to `/login` if signed out).
- `/login`, `/register` — email+password; register shows a "check your inbox" flash message rather
  than assuming a session (this project requires email verification).
- `/verify-email` — completes the emailed verification link server-side.

## Security Implementation

- **Input validation**: Pydantic models at every boundary — `app/schemas/auth.py` (register/login),
  `app/schemas/post.py` (500-char cap, optional http(s)-only image URL), `app/schemas/comment.py`
  (300-char cap). No raw `dict` request bodies.
- **Authentication**: Mudbase-issued JWT (access + refresh), held only in a signed, httpOnly,
  `same_site=lax` Starlette session cookie (`SessionMiddleware`, secret from `SESSION_SECRET_KEY`) —
  never exposed to browser JS, a deliberate difference from the reference SPA (which necessarily
  holds its token in `localStorage` for direct browser-to-Mudbase calls).
- **Authorization**: enforced server-side by Mudbase collection permissions (`customer`-only
  create/update/delete, public read) — this app's own `is_customer`/`get_session_user` checks are UX
  gating (redirect to `/login`), not the security boundary.
- **Rate limiting**: inherited from Mudbase's own per-endpoint limits (see "Real-Project
  Verification" #2 above — observed materially tighter than 5/15min on `/api/auth/local/login` in
  practice) — no additional app-level limiting needed since there is no custom backend of our own.
- **Secrets**: `SESSION_SECRET_KEY` is the only real secret this app holds, and it never leaves the
  server (signs a cookie, is never sent to the client, never logged). Every Mudbase ID
  (`MUDBASE_PROJECT_ID`, the four collection IDs) is safe to expose publicly regardless — see
  `.env.example`.

## Known Limitations (real platform constraints, not bugs — same class of finding as `../web` and
`../../ecommerce/python`)

**Post images are a pasted URL, not an upload.** Bucket/file creation
(`rbacCheck("file","create")`) only allows the org-level system roles owner/admin/developer. Every
project end-user — including a real, verified `customer` account — always carries system role
`viewer`. No project end-user JWT can ever pass this check (verified live by the reference web app,
re-confirmed by the ecommerce Python port's own `seller_product_form.html`). `PostFormValues.image_url`
is a plain URL text field for this reason.

**No `users` collection, so profile display names are best-effort.** Identical constraint to the
reference web app: `app/services/profiles.py::resolve_display_name` tries a user's most recent
post's `authorName`, falls back to any `followingName` recorded by someone who follows them, falls
back to the literal string "Member" if neither exists yet.

**No in-app email-verification resend.** The resend endpoint requires a valid JWT, which an
unverified account cannot obtain (login is blocked until verified) — there is no accessible way
around this from a project end-user's own permissions, matching the reference web app exactly.

**No realtime.** See "Stack Decisions" above.

**Mudbase's `DataApi.list_data` caps `limit` at 100** (an SDK-level constraint, see "Real-Project
Verification" #1) — every list call in this port respects that ceiling; a feed/comment thread/like
list with more than 100 rows would need real pagination past what a single call returns (the feed
already paginates via `page`; comment threads and per-user liked-post lookups do not, since a demo
account is very unlikely to exceed 100 comments on one post or 100 total likes).

## Live Smoke Test Results (2026-07-31, against the real project)

Real password login was blocked by the platform's own login-endpoint rate limit for most of this
build (see "Real-Project Verification" #2 and #3). What's confirmed so far, structurally, against
the running local server (all without needing an authenticated session):

| Step | Result |
|---|---|
| App boots, `mypy app` (strict) | ✅ zero issues, 26 source files |
| `GET /`, `/login`, `/register` render (unauthenticated) | ✅ `200` |
| Anonymous guest session bootstrap (`ensure_anonymous_session`) | ✅ confirmed live once, then independently rate-limited under repeated testing (shares the same IP-wide auth bucket as login) — app degrades gracefully to an unauthenticated read rather than erroring, per its own design |
| Unauthenticated writes (like/comment/follow/post) redirect to `/login?next=...` | ✅ `303`, correct destination |
| `GET /posts/{nonexistent-id}` | ✅ `404` with the "doesn't exist or was removed" empty state |
| Register-form validation (bad email, short password, missing terms checkbox) | ✅ `422`, correct per-field messages |
| `limit=200` → `limit=100` fix for `list_liked_post_ids`/`list_comments` | ✅ verified by reproducing the original `pydantic_core.ValidationError` live, then confirming the fix |

**Authenticated end-to-end verification (Ava posts, Ben comments/likes/follows, profile counts)
could not be completed live, and this is reported honestly rather than fabricated.** After the
first `429`, all further Mudbase network activity was stopped and a single retry was scheduled
after a full clean 920-second wait with *zero* requests of any kind to any Mudbase endpoint in
between (verified: the wait loop only called `date`, no `curl`). That single retry, at T+920s,
still returned `429 {"retryAfter":900}` — the identical `retryAfter` value as every earlier attempt,
despite a genuinely idle 15+ minute window. This rules out a simple sliding-window rate limit
(which would show a shrinking `retryAfter` as the window elapses) and points instead to either a
fixed-duration lockout that doesn't decay in the response payload, or an escalating ban triggered by
the volume of requests made earlier in this build (a verification curl, one real `/login` attempt
through the app, and — a mistake — one incidental live `/register` call while testing checkbox form
parsing, which turned out to hit the same shared `/api/auth/*` bucket). Continuing to retry risked
extending the lockout further and contradicted the task's own guidance against open-ended waiting,
so authenticated live verification was stopped here rather than continued indefinitely.

**What this does and doesn't mean for confidence in the port:**
- The identical architecture (`mudbase_client.py`, `session.py`, the `DataApi` CRUD wrappers) is
  ported near-verbatim from `../../ecommerce/python`, which has its own prior live-verified
  successful runs against Mudbase.
- The reference `../web` app's own `plan/build-plan.md` documents a full live smoke test — real
  registration, login, post/comment/like/follow create, counter updates, pagination — against this
  *exact same project and these exact same four collections*, succeeding end-to-end just before
  this port was built.
- This port's own code was verified as thoroughly as possible without a live authenticated session:
  `mypy --strict` clean, every route exercised via `curl` (unauthenticated feed/login/register
  rendering, auth-gated redirects on all four write endpoints, 404 handling, form validation at
  every boundary, the `limit=200→100` bug reproduced and fixed live), and an independent
  `python-reviewer` agent pass (see below) that reviewed the code cold and found no critical or
  high-severity issues.
- What is **not** independently confirmed for this specific port is a real authenticated write
  round-trip (create a post, like it, comment on it, follow, read the counters back). Given the
  identical, already-proven client code and the sibling/reference apps' successful live runs against
  the same backend, this is assessed as low-risk — but it is not the same as having watched it
  happen, and this document says so plainly rather than claiming otherwise.

## Independent Code Review (python-reviewer agent, during this build)

An independent review pass (agent had no visibility into this document, reviewed cold) found no
critical or high-severity issues. Two medium findings were fixed immediately:

1. **Non-atomic counter update had no isolation from the primary write's success.**
   `toggle_like`/`create_comment` created/deleted the like/comment row, then called
   `adjust_post_counts` as a second step — if that second call raised, the exception propagated
   up through the router, which flashed an error to the user even though the like/comment had
   already committed. Fixed: the counter update is now wrapped in its own `try/except
   MudbaseApiError` in both `app/services/likes.py` (`_adjust_likes_count_best_effort`) and
   `app/services/comments.py`, logging a warning instead of raising — the primary write's success
   is never misreported because a secondary, cosmetic counter refresh failed.
2. **`list_liked_post_ids`'s 100-row cap wasn't documented as a UX tradeoff**, only as an SDK
   constraint. Fixed: docstring in `app/services/likes.py` now spells out the concrete effect (a
   visitor with >100 likes may see an older post's like button render as not-liked) as an accepted
   tradeoff, matching the same precedent already documented for `list_comments`.

Two low-severity notes were left as-is (correctly, per the reviewer's own assessment): `%-d`/`%-I`
strftime directives in `app/utils.py` are BSD/glibc extensions not portable to Windows (no action
needed — this project's documented deployment targets are macOS/Linux, matching the sibling
ecommerce port); a `debug`-level log for the "post deleted concurrently with a like" edge case in
`adjust_post_counts` was considered but skipped as genuinely low-value noise for a demo app.

## Environment Variables

See `.env.example`. `MUDBASE_PROJECT_ID` and the four collection IDs are safe to expose (same reason
as the reference web app: no request in this data model is authorized by a bare ID, only by the
caller's JWT and Mudbase's own collection permissions). `SESSION_SECRET_KEY` is the one real secret —
generate with `python -c "import secrets; print(secrets.token_urlsafe(48))"`.

## File Tree

```
mudbase-showcase-social/python/
├── requirements.txt, mypy.ini, .env.example, .gitignore, README.md
├── plan/build-plan.md
└── app/
    ├── main.py, config.py, mudbase_client.py, session.py, context.py, utils.py, templates_env.py
    ├── schemas/ (auth, post, comment, social, pagination)
    ├── services/ (auth_service, posts, comments, likes, follows, profiles)
    ├── routers/ (auth, feed, posts, profile)
    ├── templates/ (base, index, post_detail, profile, login, register, verify_email,
    │               partials/post_card)
    └── static/css/styles.css
```
