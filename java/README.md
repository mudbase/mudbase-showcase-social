# Mudbase Showcase — Social (Java / Spring Boot edition)

A realtime social micro-blog built **entirely on [Mudbase](https://www.mudbase.dev)** — auth,
database, no custom backend of any kind — reimplemented in **Spring Boot + Thymeleaf**
(server-rendered, no client-side JS framework). This is a companion to the reference Next.js app
at `../web`: same Mudbase project, same four collections, same business rules; see
`plan/build-plan.md` for what deliberately differs (no realtime layer, no registration UI) and why.

## Stack

Java 17, Spring Boot 3.3 (Web MVC, not WebFlux), Thymeleaf, Bean Validation. The only outbound HTTP
this app makes is the real Mudbase Java SDK against `cloud.mudbase.dev` — no other services, no
database of its own.

## Setup

### 1. Install the Mudbase SDK to your local Maven repository (one-time, mandatory)

The SDK is **not published to Maven Central** — it lives at
[github.com/mudbase/mudbase-sdk](https://github.com/mudbase/mudbase-sdk), subdirectory `java/`.
Clone it as a **sibling** of this repo (same parent directory as `mudbase-showcase-social/`), then
install it into `~/.m2`:

```bash
# from the same parent directory that contains mudbase-showcase-social/
git clone https://github.com/mudbase/mudbase-sdk.git

cd mudbase-sdk/java && mvn install
```

This installs `dev.mudbase:mudbase-sdk:2.0.0` into your local repo — already done on any machine
that previously set up the sibling `mudbase-showcase-ecommerce/java` port, since it's the exact
same artifact.

### 2. Configure environment variables

```bash
cp .env.example .env
# fill in your provisioned project's IDs
set -a && source .env && set +a
```

See `.env.example` for the full list. You need a Mudbase project already provisioned with local
auth, the Multi-Role feature's `customer` role, and the four collections (`posts`, `comments`,
`likes`, `follows`) shaped as documented in `../web/plan/build-plan.md`, with the `customer` role
granted `create/read/update/delete`, `dataScope: "all"` on all four — this app assumes that
provisioning already exists, exactly like the reference web app does.

### 3. Build and run

```bash
cd mudbase-showcase-social/java
mvn clean install   # verify it builds clean
mvn spring-boot:run
```

Visit `http://localhost:8080`.

## What's implemented

| Page | Route | Notes |
|---|---|---|
| Feed | `GET /` | Paginated (`?page=`), newest first; composer visible when signed in; public, no sign-in required to read |
| Post creation | `POST /posts` | Content (≤500 chars) + optional image URL; auth-gated |
| Post detail | `GET /posts/{id}` | Full post, comments oldest-first, like toggle; public read |
| Comments | `POST /posts/{id}/comments` | Content ≤300 chars; auth-gated |
| Like toggle | `POST /posts/{id}/like` | Check-then-act against `likes`; auth-gated |
| Profile | `GET /users/{userId}` | Resolved display name, follower/following/post counts, that user's posts, follow button; public read |
| Follow toggle | `POST /users/{userId}/follow` | Check-then-act against `follows`; auth-gated |
| My profile | `GET /profile` | Redirects to `/users/{currentUserId}`; auth-gated |
| Login / Logout | `GET/POST /login`, `POST /logout` | Email + password only — see "Known limitations" for why there's no registration UI |

Session/auth: the Mudbase-issued JWT is stored server-side in the Spring `HttpSession` — it is
never sent to the browser (pages are plain server-rendered HTML with a shared stylesheet, no
client JS at all beyond ordinary form submissions).

## Architecture notes

- **`mudbase/`** wraps the generated SDK: `MudbaseDataClient` (thin `DataApi` wrapper with
  document-shape normalization and pagination-aware `listPage`/`count`), `MudbaseAuthClient`
  (login/logout/anonymous-session/refresh), `DocumentMapper` (the `Map<String,Object>` <-> domain
  conversions), `PageResult` (pagination metadata carrier).
- **`domain/`** holds plain, immutable value types (`Post`, `Comment`, `ProfileView`) with
  `fromDocument(Map)` factories and `with*` immutable-update copies for viewer-relative flags
  (`likedByViewer`, `followingAuthor`) that are never stored on the document itself.
- **`service/`** is where every Mudbase call happens, always passing the caller's own bearer token
  — Mudbase's collection permissions (public read, `customer`-only write) are the real security
  boundary, not anything in this app.
- **`auth/`** bridges the `HttpSession` to Mudbase: `SessionAuthService` holds the current
  `AuthSession` and includes the already-fixed 401-recovery logic ported from the sibling
  ecommerce app (see "Known limitations").
- **Public feed/detail/profile browsing without sign-in** uses a lazily-created anonymous Mudbase
  session (`AuthenticationApi.createAnonymousSession`), cached in the `HttpSession` for its
  lifetime — satisfies the collections' "authenticated role, read-only" permission before a real
  account exists, the same mechanism the reference Next.js app uses on first visit.
- **Write gating is per-route, not a path-subtree interceptor.** Unlike the ecommerce port's
  `/orders/**`/`/seller/**` `HandlerInterceptor`s, every gated action here (`POST /posts`,
  `POST /posts/{id}/comments`, `POST /posts/{id}/like`, `POST /users/{userId}/follow`) shares a URL
  prefix with a public `GET`, so each controller method checks
  `sessionAuthService.signedInUser(session)` directly. `GET /profile` — the one route that's
  entirely gated — uses the same inline check for consistency rather than a one-route interceptor.

## Known limitations (real platform constraints, inherited from the reference web app)

**No registration/email-verification UI.** The task's feature list for this port is explicit:
"Login (both accounts) ... auth-gated writes / public reads" — registration is out of scope here
(unlike the ecommerce Java port, which did require it). Both provided accounts are already
real-email-verified `customer` accounts.

**No realtime feed updates.** The reference web app's live-updating feed (Socket.IO
`subscribe:collection` + `db:create`/`db:update`) is a browser-only enhancement on top of a fully
working page; a Java Socket.IO client in a request/response MVC app would add an entire
event-loop/session-broadcast subsystem outside this port's task scope. Every page reflects the
latest server state on every request/navigation — the difference from the web app is "refresh to
see it," not "cannot see it."

**Post images are a pasted URL, not a file upload.** Same `rbacCheck("file","create")` constraint
documented in `../web/README.md` — every project end-user carries system role `viewer`, which can
never pass the org-owner/admin/developer-only bucket/file-create check.

**No `users` collection — profile display names are best-effort.** `ProfileService
#resolveDisplayName` mirrors the reference web app's `useResolvedDisplayName` exactly: the user's
most recent post's `authorName`, else the first non-blank `followingName` recorded by anyone who
follows them, else the literal string `"Member"`.

**`AuthenticationApi.loginLocalUser` fails with a 500 for every real Multi-Role account on this SDK
version.** Same root cause the sibling `mudbase-showcase-ecommerce/java` port already found and
fixed: the generated `LoginLocalUser200ResponseUser` Gson model doesn't declare `customRole`, which
every Multi-Role login response actually carries, so Gson hard-fails on the unknown property.
`MudbaseAuthClient#login` in this app uses the identical fix (raw call + lenient Jackson parsing)
rather than rediscovering it.

**`DataApi.listData` also fails against the live API for the same reason.** Every list call in
this app (`MudbaseDataClient#listRaw`/`listPage`) bypasses the generated method with the same
raw-call-plus-lenient-Jackson pattern, for the same documented `hasMore`-field mismatch.

**A single page render that needs more than one Mudbase call could spuriously "expire" a session
that was just successfully refreshed — ported pre-fixed, not rediscovered.** This app's
`GET /users/{userId}` makes at least four sequential `MudbaseDataClient` calls from one
`HttpSession`-derived token snapshot (resolve display name, follower count, following count, post
list) — the exact multi-call shape that triggered this bug in the ecommerce app's seller
dashboard. `SessionAuthService#recoverFromUnauthorized` was ported already carrying the fix (a
token mismatch means "the session already holds something newer — retry with that," not "give
up") rather than reintroducing the original bug. See that method's javadoc for the full history.

**No Spring Security / CSRF tokens.** Every state-changing endpoint is a plain `POST` handled by a
`@Controller` method with Bean Validation; there is no CSRF token or session-fixation protection
beyond what Spring Boot's Tomcat defaults provide. Reasonable for a reference/demo app; Mudbase's
own collection permissions remain the actual authorization boundary regardless. Every
user-suppliable `redirect` parameter (login, like toggle, follow toggle) is validated by
`support/RedirectSupport` against open-redirect abuse — only a same-origin relative path is ever
honored.

## Local development

```bash
mvn spring-boot:run
```

Thymeleaf template caching is disabled by default in this repo's `application.properties`
(`THYMELEAF_CACHE=false`) so edits to `.html` files under `src/main/resources/templates` show up on
refresh without a restart.

## Verification performed

`mvn clean install` builds clean (Java 26 JDK, `--release 17` cross-compilation via the Spring Boot
parent's `java.version` property — same toolchain the sibling ecommerce port already validated).

The full flow was exercised end-to-end against the **real**, live, provisioned Mudbase project
(`cloud.mudbase.dev`, project `6a6cf79dd07caabbbdfbe9c5`), using the two provided pre-verified
accounts — no mocks, no stubs:

| Step | Result |
|---|---|
| Ava logs in through the running app (`POST /login`) | ✅ `302` |
| Ava's `/profile` resolves her real userId (`GET /profile` → `302 /users/{id}`) | ✅ |
| Ava creates a post with content + an image URL (`POST /posts`) | ✅ `302`, post appears at the top of the feed (`GET /`) |
| Post detail page renders the same content (`GET /posts/{id}`) | ✅ `200` |
| Submitting an empty comment shows the Bean Validation error, no Mudbase write attempted | ✅ |
| Ava comments on her own post; thread renders oldest-first with correct singular "1 comment" text | ✅ |
| Ava likes her own post: counter `0→1`, filled heart, `liked` class applied | ✅ |
| Ava un-likes: counter `1→0`, hollow heart, `liked` class removed | ✅ |
| Ava's own profile page: post count increments correctly after her new post | ✅ |
| A guest with no session can read the feed and post detail, sees "Sign in to post" instead of the composer | ✅ |
| A guest attempting to like a post is redirected to `/login` | ✅ |
| Ben logs in, comments on Ava's post, likes it, and follows Ava (cross-account verification) | ⚠️ blocked by a shared-IP rate limit — see note below |

**Rate-limit note.** `POST /api/auth/local/login` and `POST /api/auth/anonymous` share one
20-requests/900-second bucket, keyed per IP. This machine's IP was concurrently running several
other sibling-port builds' own live smoke tests against the same bucket at the same time (this
build observed `csharp/`, `go/`, `mobile-expo/`, `mobile-flutter/`, `python/`, `ruby/`, and `swift/`
directories all appear as freshly-created siblings mid-build, and a `php/` port land on `main`) —
every real login attempt (Ava's, Ben's, and this test's own rate-limit probes) draws from that same
shared budget. Ava's login succeeded on the first attempt once the bucket had headroom, and her
entire flow above (post, comment, like toggle both directions, profile counts) was verified
end-to-end through the real API with zero mocking. Ben's login was retried against the live bucket
for several minutes during this build and stayed `429` throughout that window (other concurrent
sibling builds kept re-consuming the shared budget faster than its 900s window could clear) — this
is an external, shared-infrastructure constraint of testing ten ports against one project's rate
limits concurrently on one machine, not a defect in this app. Ben's code path is identical to
Ava's (same `AuthController`/`PostController`/`ProfileController`, no per-account branching, no
role split in this single-role app), and `FollowService`'s read paths (`countFollowers`,
`countFollowing`, `isFollowedByViewer`) were already exercised live via Ava's own profile view. A
re-run of this app once the shared bucket is quiet (e.g. `mvn spring-boot:run` a few minutes after
the other sibling ports finish their own testing) would be expected to complete Ben's leg
identically to Ava's — nothing in the code path differs.
