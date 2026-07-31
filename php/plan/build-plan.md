# Build Plan — Mudbase Showcase: Social (PHP port)

Generated: 2026-07-31
Mode: port (1 of 10 language/platform ports of `../web`, the reference implementation)
Type: web (server-rendered, fullstack via BaaS, no custom backend)
Stack: Plain PHP 8.1+ (no framework), the real generated `mudbase/sdk` Composer package, PHP's
built-in dev server. Mirrors `../../mudbase-showcase-ecommerce/php`'s architecture exactly — same
`AppContext`/`MudbaseClient`/`Router`/`View` scaffolding, same session-based auth model.

## Stack Decisions

- Plain PHP, PSR-12-ish, `declare(strict_types=1)` everywhere — matches the ecommerce PHP port's
  brief and this project's own instruction to mirror its architecture.
- Server-rendered, session-based auth: the Mudbase JWT pair lives in native `$_SESSION`, not a
  browser `localStorage` — a request-scoped `AppContext` (src/Http/AppContext.php) replaces the
  reference app's React `useMudbase()` context.
- Real generated `mudbase/sdk` PHP package (composer path-repo `../../mudbase-sdk/php`, same as the
  ecommerce port) — no hand-rolled HTTP client. `src/Mudbase/MudbaseClient.php` is a thin wrapper
  exposing exactly the operations this app needs (auth, collection CRUD, email verification),
  ported near-verbatim from the ecommerce port's client (same 401→refresh→retry-once behavior via
  `callApi()`, same `listDataRequest()` workaround for the SDK's lossy typed list-response model —
  see that class's docblock).
- No Socket.IO / realtime client. The reference Next.js app subscribes to `posts`/`comments`/
  `likes`/`follows` over Socket.IO for live updates (see `../web/src/hooks/usePostsLive.ts`); a
  server-rendered PHP app has no persistent client connection to attach a socket to, and the SDK
  ships no realtime client. This mirrors the ecommerce PHP port's own "Known limitations" — it also
  has no Socket.IO client and instead short-polls one specific fragment (seller order queue). This
  app takes the simpler route used for everything else in that port: a normal full-page reload
  shows the latest state. See "Known limitations" below.
- Post images are a pasted URL, not a file upload — same real platform constraint as both sibling
  apps (`rbacCheck("file","create")` only allows org-level owner/admin/developer; every project
  end-user is system role `viewer`). Not re-verified live again here since the reference app's
  `plan/build-plan.md` already confirmed it against this exact project.

## CRITICAL bug fixed from day one (per task instruction)

`GET /api/auth/local/session` omits the `isAnonymous` key entirely for anonymous sessions rather
than sending `false` (confirmed in the ecommerce PHP port's own `AppContext::isSignedIn()`
docblock, carried forward here unchanged). A bare `($user['isAnonymous'] ?? false) !== true` check
would treat every anonymous guest as signed in. Fixed identically to the ecommerce port:
`AppContext::isSignedIn()` additionally requires `($user['customRole'] ?? null) !== null` —
Mudbase only ever assigns a `customRole` ("customer") to a real registered account; anonymous
sessions always come back with `customRole: null`.

## Multi-step flow consistency (per task instruction)

Two write flows in this app are multi-step (a primary write + a denormalized counter PATCH on
`posts`), so a failure partway through must never leave the app claiming success while the data is
actually half-applied:

- **Like/unlike** (`PostController::toggleLike`): create/delete the `likes` row, then PATCH
  `posts.likesCount`. If the PATCH fails **after** a brand-new like row was just created, the like
  row is rolled back (best-effort delete) before the error is surfaced — otherwise the user would
  have an orphaned like that never counts and no visible error explaining why. The delete-then-PATCH
  direction (unlike) has no equivalent rollback-of-a-delete (undelete isn't a thing); instead, if
  that PATCH fails, the error path still redirects to the post, which re-reads the real `likesCount`
  from the server on next load rather than trusting anything client-side — there is nothing to roll
  back because the like row is already correctly gone.
- **Comment creation** (`PostController::comment`): create the comment, then PATCH
  `posts.commentsCount`. Unlike likes, the comment itself is real user content — rolling it back
  (deleting a just-posted comment) because a *counter* PATCH failed would destroy more than it
  protects. Instead, if the counter PATCH fails, the flash message explicitly says the comment
  posted but the count may be briefly stale, rather than a generic success message that implies
  everything completed cleanly. Both paths redirect to the same post either way, so the comment
  itself is always visible regardless of which branch ran.
- **Follow/unfollow** (`ProfileController::toggleFollow`) and **post creation**
  (`FeedController::create`) are single-step writes with no derived counter to keep in sync
  (follower/following counts are computed live via `pagination.total`, not stored) — no rollback
  logic needed for either.

## Data Models (Mudbase Collections — already provisioned, used as-is, not recreated)

Identical to `../web/plan/build-plan.md` — see that file for the full verification log (role slug,
permissions grant, Atlas capacity fix, live smoke test against the real two-account setup). Quick
reference:

- `posts` (`6a6cf7d0d07caabbbdfbe9db`): `authorId`, `authorName`, `content`, `imageUrl?`,
  `likesCount`, `commentsCount`.
- `comments` (`6a6cf7d1d07caabbbdfbe9f1`): `postId`, `authorId`, `authorName`, `content`.
- `likes` (`6a6cf81ed07caabbbdfbea20`): `postId`, `userId` — one row per pair, uniqueness enforced
  app-side via check-then-act (query `{postId,userId}` immediately before create/delete).
- `follows` (`6a6cf81ed07caabbbdfbea32`): `followerId`, `followingId`, `followingName?` — same
  check-then-act guard as likes.

`customer` role has create/read/update/delete (`dataScope: "all"`) on all four; anonymous
(`viewer`, `customRole: null`) has read-only.

## Auth Flow

```
First request (no session)  → establishAnonymousSession() → guest session (viewer, customRole null)
                                                            → can read the feed/posts/comments, cannot write
Register                    → POST /api/auth/local/signup/customer (agreedToTerms required)
                                                            → 201, no token, requireVerification: true
                                                            → verification email queued
Verify                      → GET /verify-email?token=...  → app calls UsersApi::verifyEmail()
Login                       → POST /api/auth/local/login   → 403 EMAIL_VERIFICATION_REQUIRED until verified
                                                            → 200 + token/refreshToken once verified
Logout                      → POST /api/auth/logout (revokes token), session regenerated
```

Every real page load re-bootstraps from `$_SESSION` (no re-validation round trip per request,
matching the ecommerce port's rationale — a stateless SPA revalidates once per client mount, this
server-rendered app would otherwise cost one Mudbase round trip per page view). A 401 raised
mid-request (expired access token, refresh also failed) is caught by the front controller, which
clears the session and redirects back to the same URL to re-bootstrap as a fresh guest.

## UI Pages / Routes

| Route | Method | Controller | Notes |
|---|---|---|---|
| `/` | GET | `FeedController::index` | Composer (auth-gated) + paginated feed, `?page=` |
| `/posts` | POST | `FeedController::create` | Create post; auth-gated; redirects to `/` |
| `/posts/{id}` | GET | `PostController::show` | Post detail + comments (oldest-first) + like toggle |
| `/posts/{id}/comments` | POST | `PostController::comment` | Auth-gated |
| `/posts/{id}/like` | POST | `PostController::toggleLike` | Auth-gated, check-then-act + rollback (see above) |
| `/users/{userId}` | GET | `ProfileController::show` | Resolved display name, counts, that user's posts, follow button |
| `/users/{userId}/follow` | POST | `ProfileController::toggleFollow` | Auth-gated, check-then-act, no-op on self |
| `/profile` | GET | `ProfileController::me` | Redirect to `/users/{currentUserId}`; redirects to `/login` if signed out |
| `/login`, `/register` | GET/POST | `AuthController` | Register shows "check your inbox", never assumes a session |
| `/verify-email` | GET | `AuthController::verifyEmail` | Completes the emailed link (`?token=`) |
| `/logout` | POST | `AuthController::logout` | |

## Known Limitations (real platform constraints, not bugs — same as reference app)

- **Post images are a pasted URL, not an upload** — `rbacCheck("file","create")` blocks every
  project end-user; see reference app's `plan/build-plan.md` for the live-verified 403.
- **No realtime.** No Socket.IO client in the PHP SDK and no persistent connection to attach one to
  in a server-rendered app — a normal page reload/redirect-after-write shows the latest state
  instead. The ecommerce PHP port took the same position for everything except one short-polled
  fragment; this app doesn't add that complexity for a feature the task didn't call for.
- **No `users` collection** — display names are resolved the same way as the reference app
  (`ProfileController` tries the user's most recent post's `authorName`, then any recorded
  `followingName`, then falls back to the literal string "Member").
- **No in-app email-verification resend** — same reason as the reference app: the resend endpoint
  requires a valid JWT, which an unverified account can never obtain.

## Security Implementation

- CSRF: every state-changing form includes `Csrf::field()`; every POST controller action calls
  `Csrf::verify($_POST['_csrf'] ?? null)` before doing anything else (ported verbatim from the
  ecommerce port's `Http/Csrf.php`).
- Authentication: Mudbase JWT pair in native PHP session (`$_SESSION`), never in a cookie/JS-visible
  store. Session id regenerated on every privilege change (login/register/logout).
- Authorization: enforced server-side by Mudbase collection permissions (customer-only
  create/update, public read) — this app's own `isSignedIn()`/redirect-to-login checks are UX
  gating, not the security boundary.
- Output escaping: every dynamic value rendered through `View::escape()` (`htmlspecialchars`,
  `ENT_QUOTES`) — no raw `<?=` of user content anywhere.
- Secrets: none client-exposed — this is a server-rendered app, so unlike the reference Next.js
  app's `NEXT_PUBLIC_*` env vars, nothing here is bundled into a browser payload at all. `.env`
  holds the project/collection IDs server-side only.

## Environment Variables

See `.env.example`.

## File Tree

```
mudbase-showcase-social/php/
├── composer.json, .env.example, .gitignore, README.md
├── plan/build-plan.md
├── public/
│   ├── index.php, router.php
│   └── assets/style.css
└── src/
    ├── bootstrap.php, Config.php, Router.php, View.php
    ├── Http/ (AppContext, Csrf, Flash, Response)
    ├── Mudbase/ (MudbaseClient, MudbaseApiError)
    ├── Controllers/ (AuthController, FeedController, PostController, ProfileController)
    └── views/ (layout, home, post_detail, profile, login, register, verify_email,
                errors/not_found, errors/server_error)
```
