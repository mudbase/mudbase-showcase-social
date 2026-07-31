# Build Plan — Mudbase Showcase: Social (Go port)
Generated: 2026-07-31
Mode: port (one of 10 language/platform ports of `web/`, the reference Next.js implementation)
Type: server-rendered web (fullstack via BaaS, no custom backend)
Stack: Go 1.26 + net/http + chi/v5 + html/template + gorilla/sessions, backed entirely by
Mudbase (cloud.mudbase.dev) via the official `github.com/mudbase/mudbase-sdk/go` SDK.

## Stack Decisions

- Mirrors `mudbase-showcase-ecommerce/go`'s established framework exactly: net/http + chi,
  server-rendered `html/template` pages, a `gorilla/sessions` encrypted cookie holding the
  Mudbase JWT (there is no client-side JS framework, so the cookie is the only place a token can
  live), and the same `internal/mbase` package shape (Client, generic List/Get/Create/Update/
  Delete, TokenRefresher-carrying context). This is a direct sibling of that codebase, not a
  reinvention - see that project's `internal/mbase/refresh.go` and `internal/session/session.go`,
  read verbatim before writing this app's equivalents.
- **The 401 -> refresh -> retry bug class this task flagged up front**: the reference web app's
  `src/lib/mudbase.ts` captures `refreshToken` at login/register time and correctly wires it
  through `refreshAccessToken()` on every 401 (with `refreshInFlight` dedup for the rotating
  single-use refresh token). The ecommerce Go port already found and fixed the version of this bug
  that matters for a server-rendered Go app: capturing the refresh token in session state but never
  actually invoking it on a 401 from a deep `store` call. This port ports the *fix*, not a naive
  re-transcription of the bug: every `mbase.List/Get/Create/Update/Delete` call runs through
  `callWithRefresh` (`internal/mbase/refresh.go`), which is handed a `TokenRefresher` closure via
  request context (`internal/server/middleware.go`'s `sessionMiddleware`/`tokenRefresher`) that
  exchanges the session's stored refresh token for a new pair and persists both back into the
  cookie - not just the access token - before retrying the failed call once.
- **No Register/verify-email flow.** Unlike the ecommerce port, this app only implements Login
  against the two pre-provisioned, pre-verified accounts named in the task - the task's own
  instruction is "use these, avoid registering new ones," and the reference web app's own
  build-plan documents this backend's registration as requiring real-inbox email verification
  with no in-app resend path, which is not something a repeatable Go port smoke test should
  depend on. `internal/mbase/auth.go` therefore has no `Register` method at all (the ecommerce
  port's raw-HTTP registration workaround is the piece intentionally not carried over).
- **Polling, not a Go realtime client, for "realtime."** There is no official Mudbase Go realtime
  (Socket.IO) client, exactly the same gap the ecommerce Go port documents for its seller order
  queue. This port uses the identical pattern: a small inline script polls a `/…/fragment`
  endpoint every few seconds and replaces one `<div>`'s innerHTML - the feed's post list
  (`/feed/fragment`) and a post's like-state + comment thread (`/posts/{id}/fragment`). Comment/
  post composer forms deliberately live *outside* the polled div so a poll-driven refresh never
  wipes text the visitor is actively typing.

## Data Models (Mudbase Collections — already provisioned, used as-is, not recreated)

Identical schema to `web/plan/build-plan.md` - see that file for the full provisioning history
(role permissions grant, the Atlas 500-collection-cap incident) - restated here only as this app's
Go structs (`internal/models/*.go`):

- **posts** (`6a6cf7d0d07caabbbdfbe9db`): `authorId`, `authorName`, `content`, `imageUrl?`,
  `likesCount`, `commentsCount`.
- **comments** (`6a6cf7d1d07caabbbdfbe9f1`): `postId`, `authorId`, `authorName`, `content`.
- **likes** (`6a6cf81ed07caabbbdfbea20`): `postId`, `userId` - one row per pair, uniqueness
  enforced by a check-then-act query in `store.LikeService.Toggle`, same tradeoff the reference
  web app documents.
- **follows** (`6a6cf81ed07caabbbdfbea32`): `followerId`, `followingId`, `followingName?` -
  denormalized name, same check-then-act tradeoff in `store.FollowService.Toggle`.

## Auth Flow

```
First visit (no session cookie) → POST /api/auth/anonymous → guest session (viewer, no customRole)
                                                             → can read the feed/posts/comments,
                                                               cannot write
Sign in                          → POST /api/auth/local/login (email/password)
                                                             → 200 + token/refreshToken, stored in
                                                               the encrypted session cookie
Sign out                          → POST /api/auth/logout (revokes token) + clears session identity
```

No registration UI - the app logs in with the two accounts the task provided
(`mudhaxk+mbsocial1@gmail.com` "Ava Poster", `mudhaxk+mbsocial2@gmail.com` "Ben Follower",
password `SocialTest123!` for both).

## Realtime (poll-based - see "Stack Decisions" above)

- `GET /feed/fragment?page=N` - re-renders the current feed page's post list + pagination nav.
  Polled every 5s by an inline script on `/`.
- `GET /posts/{id}/fragment` - re-renders a post's like button/count + full comment thread.
  Polled every 4s by an inline script on `/posts/{id}`.

## UI Pages / Routes

- `GET /` - feed: composer (signed-in only) + paginated post list (`page` query param, 10/page,
  newest first). Public read; posting requires sign-in.
- `GET /posts/{id}` - post detail: full post, live-polled like button + comment thread, comment
  composer (signed-in only).
- `POST /posts` - create a post (`requireSignedIn`).
- `POST /posts/{id}/like` - toggle like (`requireSignedIn`).
- `POST /posts/{id}/comments` - add a comment (`requireSignedIn`).
- `GET /users/{userId}` - profile: resolved display name, follower/following/post counts, that
  user's posts, follow/unfollow button (hidden on your own profile).
- `POST /users/{userId}/follow` - toggle follow (`requireSignedIn`).
- `GET /profile` - redirects to `/users/{currentUserID}` (`requireSignedIn`).
- `GET /login`, `POST /login` - email + password. `POST /logout`.

## Security Implementation

- Input validation: server-side length checks mirroring the reference web app's zod schemas
  (post content ≤ 500 chars, comment content ≤ 300 chars, required fields checked before any
  Mudbase call).
- Authentication: Mudbase-issued JWT (access + refresh) held in a signed, encrypted, httpOnly
  session cookie (`gorilla/sessions`, AES via a SHA-256-derived key from `SESSION_SECRET`,
  `SameSite=Lax`). 401 → refresh → retry is wired through every collection call via request
  context (see "Stack Decisions").
- Authorization: enforced server-side by Mudbase collection permissions (customer-only
  create/update/delete, public read) - this app's own `requireSignedIn` middleware is UX gating
  (redirect to `/login`), not the security boundary.
- Secrets: `SESSION_SECRET` is the only real secret this app holds (signs/encrypts the session
  cookie) - never logged, loaded from the environment, validated ≥ 32 chars at startup
  (`internal/config`). Every Mudbase credential (project ID, collection IDs) is a plain
  identifier, not a secret, matching the reference web app's own `NEXT_PUBLIC_*` treatment.

## Known Limitations (real platform constraints, not bugs - see `web/plan/build-plan.md` for the
live-verified detail behind each of these; restated briefly here)

- **No post image upload, only a pasted URL.** File/bucket creation is gated to org-level
  owner/admin/developer roles; no project end-user JWT can ever pass that check (verified live in
  the reference web app's build). `PostComposer`'s `imageUrl` field is a plain URL text input.
- **No `users` collection.** Every author/follower name is denormalized onto the row that
  references them. `store.ProfileService.ResolveDisplayName` best-efforts a name for an arbitrary
  user ID from their most recent post, then any recorded `followingName`, then the literal string
  "Member".
- **No registration/email-verification UI in this port** (see "Stack Decisions" above).
- **Polling instead of a push realtime subscription** (see "Stack Decisions" above) - there is no
  official Mudbase Go realtime (Socket.IO) client to subscribe with.

## Live Smoke Test Results

See `README.md` → "Live smoke test (2026-07-31, real project, two real accounts)" for the full
step-by-step table against the real project with the two real accounts above, including the note
on how a shared, concurrently-exhausted login rate limit (six sibling ports building against the
same two demo accounts at the same time) was handled without waiting it out or fabricating a
result.

## File Tree

```
mudbase-showcase-social/go/
├── go.mod, go.sum, .env.example, .gitignore, README.md
├── plan/build-plan.md
├── cmd/server/main.go
├── internal/
│   ├── config/config.go
│   ├── mbase/ (client.go, auth.go, data.go, errors.go, refresh.go)
│   ├── models/ (post.go, comment.go, like.go, follow.go)
│   ├── store/ (posts.go, comments.go, likes.go, follows.go, profile.go)
│   ├── session/session.go
│   └── server/
│       ├── app.go, context.go, middleware.go, templates.go, view.go, format.go, helpers.go
│       ├── handlers_auth.go, handlers_feed.go, handlers_post.go, handlers_profile.go
│       ├── templates/ (layout.html, partials.html, home.html, feed_fragment.html,
│       │   post_detail.html, post_detail_fragment.html, profile.html, login.html)
│       └── static/style.css
```
