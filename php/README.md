# Mudbase Showcase — Social (PHP)

A realtime social micro-blog built **entirely on [Mudbase](https://www.mudbase.dev)** — auth,
database, and (where applicable) realtime — with **zero custom backend**, reimplemented as a
plain, server-rendered PHP application. This is a port of the reference Next.js app in `../web`;
see that project for the canonical data model and API contract.

## Stack

Plain PHP 8.1+ (no framework — no Laravel/Symfony), PHP's built-in dev server for local
development, and the real generated `mudbase/sdk` Composer package (the same SDK used by the
sibling `mudbase-showcase-ecommerce/php` port — this project mirrors that port's architecture:
`Router` → `Controllers` → `View` + plain `.php` view files, a request-scoped `AppContext`, and a
`MudbaseClient` wrapper around the SDK).

Auth is session-based: the Mudbase JWT pair lives in native PHP `$_SESSION`, not `localStorage` —
there is no client-side JavaScript auth flow at all in this app.

## What it demonstrates

| Feature | Mudbase capability | Where |
|---|---|---|
| Guest browsing with no signup | Anonymous auth (`POST /api/auth/anonymous`) | `src/bootstrap.php` |
| Email/password accounts | Multi-Role signup (`POST /api/auth/local/signup/customer`) | `src/Controllers/AuthController.php` |
| Email verification gate | `POST /api/users/verify-email`, `EMAIL_VERIFICATION_REQUIRED` | `AuthController::verifyEmail` |
| Public feed, paginated | Collections, public read (`GET .../data?page=&limit=`) | `src/Controllers/FeedController.php` |
| Post + optional image | Ownership-scoped create, `imageUrl` as a pasted URL | `FeedController::create` |
| Like / unlike | Ownership-scoped create/delete + counter PATCH, check-then-act, rollback on partial failure | `src/Controllers/PostController.php` |
| Comment thread | Ownership-scoped create + counter PATCH, oldest-first | `PostController::comment` |
| Follow / unfollow | Ownership-scoped create/delete, check-then-act | `src/Controllers/ProfileController.php` |
| Profile (posts, follower/following counts) | Filtered reads + `pagination.total` as a count | `src/Support/SocialLookups.php` |

## Known limitations (real platform constraints, not bugs — inherited from the reference app)

- **Post images are a pasted URL, not a file upload.** `rbacCheck("file","create")` (both bucket
  creation and file upload) only allows the org-level system roles owner/admin/developer. Every
  project end-user — including a real, verified `customer` account — always carries system role
  `viewer`. `MudbaseClient` does not implement `uploadFile()` at all here (unlike the ecommerce
  port) since nothing in this app's UI could ever call it successfully.
- **No realtime.** The reference Next.js app subscribes to `posts`/`comments`/`likes`/`follows`
  over Socket.IO for live updates. The generated PHP SDK ships no realtime client, and a
  server-rendered app has no persistent connection to attach one to — a normal page reload or
  redirect-after-write shows the latest state instead. See `plan/build-plan.md` for the fuller
  rationale (matches the ecommerce PHP port's own position on this).
- **The generated SDK hard-caps every list query's `limit` at 100 client-side** (confirmed by
  reading `DataApi::listDataRequest()` — `\InvalidArgumentException` for anything higher).
  `MudbaseClient::listDocuments()` silently clamps to this; every caller in this app already
  operates at demo scale, where 100 rows is functionally unbounded.
- **No `users` collection, so profile display names are best-effort.** A user who has never posted
  and has no followers has no row anywhere recording their name — `/users/{userId}` falls back to
  the literal string "Member" in that case. See `Support/SocialLookups::resolveDisplayName()`.
- **No in-app email-verification resend.** The resend endpoint requires a valid JWT, which an
  unverified account cannot obtain (login is blocked until verified) — there is no accessible way
  around this from a project end-user's own permissions.

## Multi-step flow consistency

Two write flows PATCH a denormalized counter on `posts` after a primary write. Both are designed
so a failure partway through never leaves the app claiming success while the data is actually
half-applied — see `plan/build-plan.md` "Multi-step flow consistency" for the full reasoning:

- **Like/unlike** rolls the just-created `likes` row back if the follow-up `likesCount` PATCH
  fails, rather than leaving an orphaned like that never counts.
- **Comment creation** never rolls back a comment that already saved — a counter-PATCH failure
  surfaces as "your comment posted, but the count may be briefly stale," not a false "everything
  worked" message, and not destruction of real user content either.

## Setup

This app expects a Mudbase project already provisioned with:

1. Local auth enabled, with email verification required.
2. The Multi-Role feature's default `customer` role (this project's single application role).
3. Four collections — `posts`, `comments`, `likes`, `follows` — with the field shapes documented in
   `plan/build-plan.md`, and the `customer` role granted `create`/`read`/`update`/`delete`,
   `dataScope: "all"`, on all four.

```bash
composer install
cp .env.example .env   # fill in your own provisioned project's IDs
php -S localhost:8080 -t public public/router.php
```

Then visit `http://localhost:8080`.

## Live smoke test (2026-07-31, real project, real account)

Run against the live, already-provisioned project (`6a6cf79dd07caabbbdfbe9c5`) with the real
`customer` account `mudhaxk+mbsocial2@gmail.com` ("Ben Follower"):

| Step | Result |
|---|---|
| Anonymous guest reads the feed | ✅ real cross-account posts rendered (from prior live testing of the reference app and sibling ports sharing this same project), correct like/comment counts, no fatal errors |
| Signed-in feed read, composer enabled | ✅ correct nav state (Profile/Sign out), composer un-disabled |
| Create a post | ✅ `303`, new post appears at the top of the feed on reload |
| Open that post's detail page | ✅ correct content, `♡ 0`, "No comments yet" |
| Like it | ✅ `303`, detail page reloads showing `♥ 1`, active state |
| Comment on it | ✅ `303`, comment appears, `commentsCount` incremented |
| Unlike it | ✅ `303`, reverts to `♡ 0` |
| View own profile | ✅ correct post/follower/following counts |
| View another user's profile | ✅ resolved display name, correct counts, correct "Following" button state |
| Unfollow that user | ✅ `303`, follower count decremented correctly on reload |
| CSRF-missing POST | ✅ flash "session expired," redirects, no fatal error |
| `GET` unknown path | ✅ `404` page, no fatal error |
| `GET /verify-email` with no token | ✅ handled error state, no fatal error |
| `GET /verify-email?token=bogus` | ✅ live call to Mudbase, correctly renders "Invalid verification token" |

One write flow (re-following the same user, to restore state after the unfollow test above) could
not be completed in this session: the shared test account's refresh token was invalidated
mid-session by Mudbase's reuse-detection ("Session has been invalidated. Please sign in again.").
This is expected — the same two fallback test accounts in this task are shared across all 10
concurrent language/platform ports of this showcase being built at the same time, and refresh
tokens are single-use or by design (rotate-on-use, invalidate-the-family-on-reuse). The
create/delete code path exercised by follow/unfollow is identical to the already-verified
like/comment/post creation paths (same `SocialLookups` check-then-act pattern), so this is a
credential-contention artifact of concurrent testing, not a defect in this app.

## Security

- CSRF token on every state-changing form, verified before any controller logic runs.
- Open-redirect guard (`Response::redirectToSafe()`) on every caller-supplied `redirectTo` value
  (like/follow/comment/login/register all carry the visitor back to wherever they clicked from).
- Session id regenerated on every privilege change (login, register).
- All dynamic output escaped via `View::escape()` — no raw interpolation of user content anywhere.
- Authorization is enforced server-side by Mudbase's own collection permissions; this app's
  `isSignedIn()` checks are UX gating (redirect to `/login`), not the security boundary.

## Environment Variables

See `.env.example`.
