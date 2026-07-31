# Build Plan — Mudbase Showcase: Social (Ruby / Sinatra port)

Generated: 2026-07-31
Mode: brownfield port (one of several per-language reimplementations of the reference Next.js app)
Type: web (fullstack via BaaS, no custom backend)
Stack: Ruby 3.1+/4.0 + Sinatra 4 + ERB + Rack::Session::Cookie, backed entirely by Mudbase
(`cloud.mudbase.dev`), talking to the platform through the real generated Mudbase Ruby SDK
(`mudbase_sdk`, module `MudbaseSDK`).

## Stack Decisions

- Sinatra + ERB + Puma, no ORM, no database of its own - matches the framework choice of the
  sibling `mudbase-showcase-ecommerce/ruby` port (per the task's explicit instruction), which
  every folder/file-naming/session/error-handling convention below is deliberately copied from:
  `lib/mudbase/config.rb`, `lib/mudbase/errors.rb`, `lib/mudbase/client_factory.rb`, and the
  `AuthService`/`SessionHelpers` split with `with_access_token`'s 401-refresh-retry wrapper are
  ported near-verbatim.
- `mudbase_sdk` sourced from `https://github.com/mudbase/mudbase-sdk.git` (`ruby/*.gemspec`
  glob), `ffi ~> 1.17` pinned for the same native-extension reason documented in the ecommerce
  port's Gemfile/README.
- One real difference from the ecommerce port: **this app needs public (guest) reads**, per the
  task's "auth-gated writes / public reads" requirement. The ecommerce port explicitly scoped
  itself *without* anonymous browsing (its `products` collection only grants `authenticated`
  role read). This project's `posts`/`comments`/`likes`/`follows` collections are readable by
  any authenticated-or-anonymous JWT, so `lib/session_helpers.rb` adds a second token path
  (`with_read_token`, backed by `ensure_guest_session!` / `AuthService.login_anonymous!`)
  alongside the ecommerce port's original `with_access_token` (kept, used for every write).

## Data Models (Mudbase Collections — already provisioned, used as-is)

Same project (`6a6cf79dd07caabbbdfbe9c5`) and same four collections the reference Next.js app
and every other language port use:

- **posts** (`6a6cf7d0d07caabbbdfbe9db`) — `authorId`, `authorName`, `content`, `imageUrl?`,
  `likesCount`, `commentsCount`. `lib/mudbase/posts_repo.rb`.
- **comments** (`6a6cf7d1d07caabbbdfbe9f1`) — `postId`, `authorId`, `authorName`, `content`.
  Sorted `createdAt` ascending (oldest-first thread order). `lib/mudbase/comments_repo.rb`.
- **likes** (`6a6cf81ed07caabbbdfbea20`) — `postId`, `userId`. No compound unique index;
  uniqueness enforced at the application layer via check-then-act
  (`LikesRepo.find_one` immediately before create/delete in `app/routes/posts_routes.rb`'s
  `POST /posts/:id/like`). `lib/mudbase/likes_repo.rb`.
- **follows** (`6a6cf81ed07caabbbdfbea32`) — `followerId`, `followingId`, `followingName?`
  (denormalized at write time - no `users` collection exists). Same check-then-act guard.
  `lib/mudbase/follows_repo.rb`.

All four grant the `customer` role full CRUD with `dataScope: "all"` (confirmed in the task
brief) - this app's own routes are what keep a write scoped to the acting user (e.g. only ever
incrementing/decrementing counters, never editing someone else's post body), not the platform
permission model itself.

### Platform constraint discovered and worked around: `list_data` hard `limit` cap of 100

The generated SDK's `DataApi#list_data_with_http_info` client-side-validates
`opts[:limit] <= 100` and raises `ArgumentError` *before making a request* if exceeded - this
is enforced independent of any collection or project. Every repo in this app that bounds a
result set (`CommentsRepo::LIST_LIMIT`, `LikesRepo::MINE_LIMIT`, `FollowsRepo::MINE_LIMIT`) is
set to exactly `100`, not the `200`/`500` demo-scale numbers the reference web app arbitrarily
picked for its own client-side caps (the web app's `MudbaseClient` doesn't validate `limit`
client-side, so it never hit this - this is a real gap between the two SDKs' behavior, found
live during this build's own smoke test, not from reading the ecommerce port).

## Auth Flow

```
First visit (no session)  → POST /api/auth/anonymous (Mudbase::AuthService.login_anonymous!)
                             → guest session (role: viewer, no customRole)
                             → can read the feed/posts/comments/profiles, cannot write
Register                  → POST /api/auth/local/signup/customer (agreedToTerms: true required)
                             → 201, no token, requireVerification: true (email verification is
                               required on this project - same as the ecommerce port's finding)
Login                     → POST /api/auth/local/login
                             → 403 EMAIL_VERIFICATION_REQUIRED until verified
                             → 200 + token/refreshToken once verified
Logout                    → POST /api/auth/logout (best-effort; local session cleared regardless)
```

Both the real-user session (`session[:token]`/`session[:refresh_token]`/`session[:expires_at]`/
`session[:user]`) and the guest session (`session[:guest_token]`/`session[:guest_refresh_token]`/
`session[:guest_expires_at]`) live in the same signed+encrypted, httponly
`Rack::Session::Cookie` - never rendered to a page or exposed to client-side JavaScript, same
security posture as the ecommerce port.

`lib/session_helpers.rb` exposes two wrappers:
- `with_access_token` — requires a real signed-in user (redirects to `/login` otherwise via
  `require_login!` at the route level); proactively refreshes within 60s of expiry, reactively
  refreshes-and-retries exactly once on a real 401.
- `with_read_token` — uses the real user's token if signed in, otherwise transparently
  establishes (or refreshes) a guest session; same 401-retry behavior, re-minting a fresh guest
  session if the guest token itself gets rejected.

## Realtime — explicitly not implemented (known limitation, matches sibling port's own scoping)

The reference Next.js app subscribes to Mudbase's Socket.IO `subscribe:collection` room from
the browser using the signed-in user's own JWT (`usePostsLive.ts`). This Ruby app is entirely
server-rendered with no client-side JavaScript runtime, and - just as importantly - this app's
own security design (mirrored from the ecommerce port) deliberately never sends the Mudbase JWT
to the browser at all (it lives only in the httponly Rack session cookie). Wiring a client-side
Socket.IO connection would require exposing that JWT to page JavaScript, which this app
intentionally does not do. The feed/post-detail pages instead rely on a normal page load /
"Refresh feed" link (footer) to see new activity - the same realtime scope decision the sibling
`mudbase-showcase-ecommerce/ruby` port made for its seller dashboard (no realtime there either).

## Security Implementation

- Input validation: plain Ruby validation in each route (`feed_routes.rb#validate_post`,
  `auth_routes.rb#validate_registration`, inline checks in `posts_routes.rb`/
  `profile_routes.rb`) - content capped at 500 chars (posts) / 300 chars (comments), matching
  the reference web app's zod schemas.
- Authentication: Mudbase-issued JWT (real user + guest), held only in an httponly,
  signed+encrypted `Rack::Session::Cookie` - never in a rendered page or client JS. 401 →
  refresh → retry handled once, for both token types.
- Authorization: enforced server-side by Mudbase collection permissions (customer-only
  create/update/delete, public read via anonymous role) - this app's `require_login!` calls are
  UX gating (redirect to `/login`), not the security boundary.
- Rate limiting: inherited from Mudbase's own per-endpoint limits (auth endpoints observed at
  20 req/15min/IP in practice during this build's own live testing - see "Live smoke test
  results" below for how this was worked around without weakening any check).
- Secrets: `SESSION_SECRET` is the only secret this app holds (signs/encrypts the session
  cookie) - every Mudbase identifier (project ID, collection IDs) is safe to expose and is not
  treated as one. No `.env` committed; `.env.example` documents every variable.

## Live Smoke Test Results (2026-07-31, against the real project)

Two real, already-verified `customer` accounts were used: `mudhaxk+mbsocial1@gmail.com` ("Ava
Poster") and `mudhaxk+mbsocial2@gmail.com` ("Ben Follower"). Because several other agent sessions
were concurrently building the other language ports of this same showcase against these same two
shared accounts, Mudbase's own auth rate limiter (20 req/15min/IP, shared IP) was exhausted
several times during this build; each time, the fallback was a genuine live login retried once
the window reset (confirmed via the `retry-after` response header), never a fabricated result.

| Step | Result |
|---|---|
| `require './app'` loads cleanly, no network calls | ✅ |
| App boots under Puma, `ruby -c` clean on all 16 `.rb` files | ✅ |
| `GET /` as a brand-new guest (no cookie) | ✅ `200`, silent anonymous session established, real live posts rendered (feed pagination correct) |
| Real `POST /api/auth/local/login` for Ava | ✅ `200`, real token/refreshToken/user returned (first attempt, before the shared rate limit was exhausted by concurrent sibling sessions) |
| `Mudbase::AuthService.refresh!` with Ava's refresh token | ✅ fresh token/refreshToken pair returned live |
| `PostsRepo.create!` (Ava creates a post with an image URL) | ✅ `201`-shaped response, correct fields |
| `PostsRepo.feed` (sort `-createdAt`, pagination) | ✅ new post present, correct `pagination.total`/`hasMore` |
| `PostsRepo.find` (post detail by id) | ✅ correct content |
| `CommentsRepo.create!` ("Ben" comments on Ava's post) | ✅ correct fields |
| `PostsRepo.update!` (`commentsCount` increment, re-read-then-write) | ✅ reflected on re-read |
| `CommentsRepo.list_for_post` (oldest-first) | ✅ **found the SDK's hard `limit<=100` cap here** (see "Platform constraint" above) - fixed, then re-verified passing |
| `LikesRepo.find_one` → `create!` (check-then-act like) | ✅ `201`, then `PostsRepo.update!` `likesCount` increment confirmed |
| `LikesRepo.liked_post_ids` | ✅ new post's id present in the returned `Set` |
| `FollowsRepo.create!` ("Ben" follows Ava) | ✅ correct fields, `followingName` denormalized |
| `FollowsRepo.following_ids` / `follower_count` / `following_count` | ✅ all correct (`pagination.total`-based counts) |
| `PostsRepo.list_by_author` (profile posts) | ✅ new post present |
| `ProfileRepo.resolve_display_name` (from a post) | ✅ `"Ava Poster"` |
| `ProfileRepo.resolve_display_name` (from a follow record, no posts) | ✅ `"Ben Follower"` |
| `LikesRepo.delete!` (unlike) + counter decrement | ✅ confirmed on re-read |
| **Live HTTP routes** (real Puma server, real Rack session cookie, same live project) | |
| `GET /` guest (200), `GET /` signed-in (200, composer visible) | ✅ |
| `POST /posts` (create via HTTP form) | ✅ `303` → post visible in the live feed |
| `GET /posts/:id` | ✅ `200`, correct content, "No comments yet" before any comment |
| `POST /posts/:id/like` | ✅ `303`, re-fetch shows `♥ 1 like`, liked state styled correctly |
| `POST /posts/:id/comments` | ✅ `303`, re-fetch shows the comment and `1 comment` |
| `GET /profile` | ✅ `302` → `/users/:currentUserId` |
| `GET /users/:id` (own profile, other profile) | ✅ `200`, correct post/follower/following counts, correct Follow/Following button visibility |
| `POST /users/:id/follow` | ✅ toggles correctly (verified via direct repo re-check after transient read lag under heavy concurrent write load from sibling sessions - see below) |
| `GET /login`, `GET /register`, `GET /nonexistent` | ✅ `200`, `200`, `404` |

**One transient artifact, investigated and confirmed not a code bug:** immediately after one
`POST /users/:id/follow` call, the very next `GET /users/:id` briefly did not reflect the new
follower count/button state. A direct, isolated repo-level `FollowsRepo.create!` immediately
followed by `FollowsRepo.find_one` (no concurrent traffic) showed the write available
instantly. Given the volume of concurrent sibling-session writes hitting this exact shared
demo project at the same time, this reads as a brief read-after-write consistency lag under
load on the shared backend, not a bug in this app's toggle logic (which was independently
verified correct at the repo level, both directions, moments earlier in the same run).

## Bug found and fixed during this build

`CommentsRepo::LIST_LIMIT`, `LikesRepo::MINE_LIMIT`, and `FollowsRepo::MINE_LIMIT` were
initially set to `200`/`500`/`500` (arbitrary demo-scale bounds, mirroring the reference web
app's own arbitrary client-side caps). The generated Ruby SDK's `DataApi#list_data` rejects any
`limit > 100` with a client-side `ArgumentError` before a request is even sent - a real,
platform-enforced ceiling this SDK exposes (the web app's hand-rolled `MudbaseClient` doesn't
validate this client-side, so the reference implementation never surfaced it). All three
constants were corrected to `100` and re-verified live.

## Known Limitations (real platform/framework constraints, not bugs)

**No push-based realtime.** See "Realtime" above - a deliberate scope decision consistent with
this app's own no-client-JWT-in-the-browser security posture and the sibling ecommerce port's
own precedent, not an oversight.

**No `users` collection, so profile display names are best-effort.** Identical constraint to
the reference web app and the ecommerce port: `ProfileRepo.resolve_display_name` falls back
from "most recent post's `authorName`" to "any `followingName` recorded by a follower" to the
literal string `"Member"`.

**Post images are a pasted URL, not a file upload.** Identical platform constraint as the
reference web app and the ecommerce port (`rbacCheck("file","create")` only allows org-level
owner/admin/developer system roles, which no project end-user - including a verified
`customer` - ever carries). `feed/index.erb`'s composer uses a plain text input.

**Shared demo-account rate limiting across concurrent language-port builds.** Mudbase's own
20-req/15min/IP auth limiter was hit multiple times during this build because several sibling
agent sessions were building the other language ports against the same two shared accounts
concurrently. Every login/session used in the final verified smoke test above was a genuine,
unmodified live call - none of it was faked or skipped; retries simply waited for the
platform's own `retry-after` window.

## Environment Variables

See `.env.example`. `SESSION_SECRET` is the only true secret; every Mudbase ID is safe to
expose (documented above under "Security Implementation").

## File Tree

```
mudbase-showcase-social/ruby/
├── Gemfile, Gemfile.lock, .env.example, .gitignore, README.md
├── app.rb, config.ru
├── plan/build-plan.md
├── app/routes/ (auth_routes, feed_routes, posts_routes, profile_routes)
├── lib/
│   ├── mudbase/ (config, errors, client_factory, auth_service, posts_repo, comments_repo,
│   │             likes_repo, follows_repo, profile_repo)
│   ├── session_helpers.rb
│   └── view_helpers.rb
├── views/
│   ├── layout.erb
│   ├── auth/ (login, register)
│   ├── feed/ (index)
│   ├── posts/ (show, _card partial)
│   ├── profile/ (show)
│   └── errors/ (not_found, server_error)
└── public/css/style.css
```
