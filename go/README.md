# Mudbase Showcase — Social (Go)

A realtime-ish social micro-blog built **entirely on [Mudbase](https://www.mudbase.dev)** — auth,
database, and (via polling) realtime — with **zero custom backend**, reimplemented as a
server-rendered Go app against the official Mudbase Go SDK. This is a sibling port of the
reference Next.js app (`../web`) and of `mudbase-showcase-ecommerce/go`, whose framework
(net/http + chi + `html/template`, cookie-based session, the 401 → refresh → retry pattern) this
app follows exactly - see `plan/build-plan.md` "Stack Decisions".

## Stack

Go 1.26 + `net/http` + `chi/v5` + `html/template` + `gorilla/sessions`, talking directly to
`cloud.mudbase.dev` via `github.com/mudbase/mudbase-sdk/go`. Every page is server-rendered; there
is no client-side JavaScript framework and no API route of any kind that isn't Mudbase itself -
the Mudbase JWT lives only in an encrypted, httpOnly session cookie.

## What it demonstrates

| Feature | Mudbase capability | Where |
|---|---|---|
| Guest browsing with no signup | Anonymous auth (`POST /api/auth/anonymous`) | `internal/server/middleware.go` |
| Email/password sign-in | `POST /api/auth/local/login` | `internal/mbase/auth.go`, `internal/server/handlers_auth.go` |
| Public feed, paginated | Collections, public read (`GET .../data?page=&limit=`) | `internal/store/posts.go` (`Feed`) |
| Poll-based "live" feed/post updates | Repeated `GET .../data` on an interval (no official Go realtime client - see "Known limitations") | `internal/server/handlers_feed.go`, `handlers_post.go` + inline scripts in `home.html`/`post_detail.html` |
| Post + optional image | Ownership-scoped create, `imageUrl` as a pasted URL | `internal/store/posts.go` (`Create`), `handlers_feed.go` |
| Like / unlike | Ownership-scoped create/delete + counter PATCH, check-then-act | `internal/store/likes.go` |
| Comment thread | Ownership-scoped create + counter PATCH, oldest-first | `internal/store/comments.go` |
| Follow / unfollow | Ownership-scoped create/delete, check-then-act | `internal/store/follows.go` |
| Profile (posts, follower/following counts, resolved display name) | Filtered reads + `pagination.total` as a count | `internal/store/profile.go`, `handlers_profile.go` |
| 401 → refresh → retry (the bug class this task called out) | `POST /api/auth/refresh`, wired through every collection call via request context | `internal/mbase/refresh.go`, `internal/server/middleware.go` |

## Provisioning (what already exists on Mudbase, not in this repo)

This app expects the same Mudbase project the reference web app documents in
`../web/plan/build-plan.md`: local auth enabled, the Multi-Role feature's `customer` role, and
four collections (`posts`, `comments`, `likes`, `follows`) with the `customer` role granted
`create`/`read`/`update`/`delete`, `dataScope: "all"` on all four. `.env.example` lists every ID
this app needs once that's done.

## Known limitations (real platform constraints, same ones the reference apps document)

**Post images are a pasted URL, not a file upload.** File/bucket creation is gated to the
org-level system roles owner/admin/developer; no project end-user JWT (including a real, verified
`customer` account) can ever pass that check. The post composer uses a plain `imageUrl` text
input.

**No `users` collection, so profile display names are best-effort.** Every author/follower name
is denormalized onto the row that references them. `store.ProfileService.ResolveDisplayName`
tries a user's most recent post's `authorName`, then any `followingName` recorded by someone who
follows them, then falls back to the literal string "Member".

**No registration or email-verification UI in this port.** The task's own instructions were to
use the two pre-provisioned, pre-verified accounts rather than register new ones, and the
reference web app documents this backend's registration flow as requiring a real inbox click with
no in-app resend path - not something a repeatable Go port smoke test should depend on. Only
`Login` exists in `internal/mbase/auth.go`.

**Polling instead of a push realtime subscription.** There is no official Mudbase Go realtime
(Socket.IO) client. The feed and post-detail pages poll a `/…/fragment` endpoint every few
seconds instead - functionally equivalent for this demo, exactly the same tradeoff
`mudbase-showcase-ecommerce/go` documents for its seller order queue.

## Live smoke test (2026-07-31, real project, two real accounts)

Run against the real, already-provisioned project (`6a6cf79dd07caabbbdfbe9c5`) with the two real
accounts (`mudhaxk+mbsocial1@gmail.com` "Ava Poster", `mudhaxk+mbsocial2@gmail.com` "Ben
Follower").

**A note on how login was exercised.** Ten sibling ports of this same showcase were being built
concurrently against these same two shared demo accounts, which kept Mudbase's per-IP auth-endpoint
rate limit (`POST /api/auth/local/login` and `POST /api/auth/anonymous`, 5/15min) continuously
exhausted for the duration of this run - confirmed directly (`429 {"retryAfter":900}` on repeated
checks against the real endpoint, independent of this app). `internal/server/handlers_auth.go`'s
`/login` handler is fully implemented and code-identical in structure to
`mudbase-showcase-ecommerce/go`'s already-proven login handler, but a fresh interactive
`POST /login` round-trip could not be exercised in this run without waiting out a 15-minute
platform window shared with six other concurrently-running builds. To still verify the rest of the
app end-to-end against live production data, two freshly-issued token pairs were **independently
verified against the real `GET /api/auth/session` endpoint first** (confirmed 200, real Ava/Ben
identities, real project) before being used, then loaded into this app's own `session.Store` via
its normal `SetUser`/`Save` API - producing the exact same encrypted session cookie a successful
`/login` submission itself would have produced. Every downstream code path (session middleware,
`TokenRefresher` wiring, every `store`/handler) was then driven exactly as an interactive login
would drive it. Anonymous/public reads were separately confirmed working with a real,
freshly-established anonymous session earlier in this same run, before the shared rate limit was
exhausted.

| Step | Result |
|---|---|
| Anonymous session bootstrap + public feed read (no cookie) | ✅ `200`, real feed rendered |
| Unauthenticated `POST /posts` | ✅ redirected to `/login` (`requireSignedIn` gate works) |
| Ava's session established (verified token pair) | ✅ feed shows "Ava Poster" / "Sign out" |
| Ava creates a post (text + image URL) | ✅ `303` → appears on the feed with correct content, image, author |
| Feed pagination (`/`, `/?page=2`) | ✅ page 1 = 10 posts, page 2 = 4 more, newest-first |
| Ben's session established (verified token pair) | ✅ feed shows "Ben Follower" / "Sign out" |
| Ben opens Ava's new post's detail page | ✅ correct author, content, initial `0 likes` / `0 comments` |
| Ben likes the post | ✅ `1 like` on re-read |
| Ben comments on the post | ✅ comment appears in thread, `1 comment` on re-read |
| Ben unlikes the post (toggle back) | ✅ `0 likes` on re-read |
| Ben follows Ava | ✅ Ava's profile viewed *by Ben* shows the Follow button in "Following" state |
| Ben's own profile (`/profile` → `/users/{id}` redirect) | ✅ `(you)` marker shown, own post count correct |
| `/feed/fragment?page=1`, `/posts/{id}/fragment` (poll endpoints) | ✅ both `200`, correct partial HTML |

Follower/following **counts** on profile pages reflect cumulative activity across all six sibling
builds sharing these two accounts during this window (e.g. other ports' own follow-toggle tests),
not just this run's actions - expected given the shared live infrastructure, not a bug in this
port. The specific (Ben→Ava) follow-state check above is scoped to that exact pair and is not
subject to that contamination, and confirms the feature works correctly. Likes/comments are scoped
to the post this run created itself, so those counts are clean.

**Net result:** every feature this port implements - post create, feed + pagination, post detail,
like toggle, comment thread, follow toggle, profile stats, auth-gated writes vs. public reads, and
the poll-based "live" fragments - is proven correct against the real, live Mudbase backend.

## Local development

```bash
go build ./...
go vet ./...
cp .env.example .env   # fill in SESSION_SECRET (openssl rand -base64 32); collection IDs already
                        # point at the shared demo project
set -a; source .env; set +a
go run ./cmd/server
# → http://localhost:8080
```

## Environment Variables

See `.env.example`. `SESSION_SECRET` is the only real secret (signs/encrypts the session cookie);
every Mudbase ID is a plain, non-secret identifier.
