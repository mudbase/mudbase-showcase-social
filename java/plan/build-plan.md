# Build Plan — Mudbase Showcase: Social (Java / Spring Boot edition)
Generated: 2026-07-31
Mode: brownfield-adjacent (1 of 10 language/platform ports — reimplements `../web`'s data model
and API contract in a different stack, following the sibling `mudbase-showcase-ecommerce/java`
port's established architecture)
Type: server-rendered web app (fullstack via BaaS, no custom backend)
Stack: Java 17, Spring Boot 3.3 (Web MVC, not WebFlux), Thymeleaf, Bean Validation — matches the
ecommerce showcase's Java port framework choice, per the task's explicit instruction.

## Stack Decisions

- **Spring Boot + Thymeleaf, server-rendered, no client-side JS framework** — mirrors
  `mudbase-showcase-ecommerce/java` exactly: the JWT lives in the servlet `HttpSession`, never
  reaches the browser; pages are plain HTML with a shared CSS file, no SPA bundle.
- **The real Mudbase Java SDK (`dev.mudbase:mudbase-sdk:2.0.0`)**, already installed in this
  machine's local Maven repository (`~/.m2/repository/dev/mudbase/mudbase-sdk/2.0.0`) from the
  ecommerce port's setup — no re-clone/re-install needed for this build.
- **No realtime (Socket.IO) layer.** The reference web app's realtime feed update is a
  browser-only enhancement (`usePostsLive`) on top of a fully-functional page that still works via
  plain reads; the task's explicit feature list for this port (Login, feed, composer, post detail
  with comments/like, profile with follow) does not include realtime, and a Java Socket.IO client
  in a request/response MVC app would add an entire event-loop/session-broadcast subsystem with no
  corresponding requirement. Every page still reflects the latest server state on every request/
  navigation — the only difference from the web app is "refresh to see a friend's new like," not
  "cannot see it at all."
- **No registration/email-verification UI.** The task's feature list is explicit: "Login (both
  accounts) ... auth-gated writes / public reads" — registration is not listed, unlike the
  ecommerce Java port's task (which did require it). Both provided accounts are already
  real-email-verified and ready to log in. Skipping registration also sidesteps the reference app's
  own documented verification-gate friction (`EMAIL_VERIFICATION_REQUIRED`, no in-app resend) for
  zero functional loss against this port's actual scope.
- **Token-holding pattern, session-key shape, and the 401-recovery fix are ported verbatim from
  `mudbase-showcase-ecommerce/java`'s `auth/SessionAuthService.java`**, per the task's explicit
  instruction to read and not repeat that project's fixed bug. See "Auth flow and the
  refresh-recovery fix" below for why the fix matters here too, not just in the ecommerce app.

## Real-Project Verification (reused from the reference web app + this build's own live checks)

Every one of the following was already confirmed live against the real project
(`6a6cf79dd07caabbbdfbe9c5`) by `../web/plan/build-plan.md` before this port started — the two
apps talk to the same Mudbase project, so none of it needed to be re-discovered from scratch, only
re-verified where the Java SDK's own generated models could introduce a *new* failure mode (see
"SDK-specific findings" below):

1. Signup role slug is `customer` — irrelevant to this port (no registration UI), but confirms both
   provided accounts are real `customer`-role Multi-Role accounts.
2. Every collection read requires *some* JWT — an anonymous session is bootstrapped on first guest
   page load, exactly like the web app and the ecommerce Java port's `SessionAuthService
   #publicReadToken`.
3. Anonymous ("viewer") sessions cannot write to any of the 4 app collections — 403, matching this
   app's "auth-gated writes, public reads" requirement with no extra app-side role check needed.
4. All four collections (`posts`, `comments`, `likes`, `follows`) already carry `customer` role
   `create/read/update/delete`, `dataScope: "all"` permissions (task states this was already
   granted — re-confirmed live during this build's own smoke test, see below).
5. `likes`/`follows` have no compound unique index — uniqueness is a check-then-act app-level guard
   (query `{postId,userId}` / `{followerId,followingId}` immediately before create/delete), ported
   identically into `LikeService`/`FollowService`.

### SDK-specific findings (this build's own, following the ecommerce Java port's established fixes)

6. **`AuthenticationApi.loginLocalUser` still fails with a 500 for a real Multi-Role account on
   this SDK version.** Same root cause the ecommerce Java port already documented and fixed: the
   generated `LoginLocalUser200ResponseUser` Gson model doesn't declare `customRole`, which every
   Multi-Role login response actually carries, and Gson hard-fails
   (`IllegalArgumentException`) on the unknown property. `MudbaseAuthClient#login` in this app uses
   the identical fix: a raw call over the SDK's shared `OkHttpClient`, parsed leniently with a
   Jackson `@JsonIgnoreProperties(ignoreUnknown = true)` DTO instead of the strict generated model.
   Confirmed live: `POST /api/auth/local/login` for both Ava and Ben returns a `user` object with
   both `role` and `customRole` present.
7. **`DataApi.listData` still fails against the live API for the same `hasMore`-field reason the
   ecommerce port found.** Every list call in this app (`MudbaseDataClient#listRaw`/`listPage`)
   bypasses the generated method with the same raw-call-plus-lenient-Jackson pattern. Confirmed
   live: `GET .../posts/data?page=1&limit=1` returns a `pagination` object containing `hasMore`.
8. **The multi-call-token-mismatch bug from the ecommerce port's `SessionAuthService
   #recoverFromUnauthorized` is a real risk here too, and was ported pre-fixed rather than
   rediscovered.** This app's `GET /users/{userId}` profile page makes *at least four* sequential
   `MudbaseDataClient` calls from one `HttpSession`-derived token snapshot (resolve display name,
   follower count, following count, that user's posts) — the exact multi-call shape that triggered
   the bug in the ecommerce app's seller dashboard. Porting the buggy "token mismatch = give up"
   version would have reintroduced a spurious "session expired" logout on this app's single busiest
   read page the first time any signed-in viewer's access token happened to expire mid-request.
   The fixed version (a mismatch means "the session already holds something newer — retry with
   that") was used from the first line of this file, per the task's explicit instruction.

## Data Models (Mudbase Collections — already provisioned, used as-is)

Identical field shapes to `../web/plan/build-plan.md` — this port creates no new collections:

- **posts** — `6a6cf7d0d07caabbbdfbe9db`: `authorId`, `authorName`, `content`, `imageUrl?`,
  `likesCount`, `commentsCount`, plus `_id`/`createdAt`/`updatedAt`.
- **comments** — `6a6cf7d1d07caabbbdfbe9f1`: `postId`, `authorId`, `authorName`, `content`.
- **likes** — `6a6cf81ed07caabbbdfbea20`: `postId`, `userId`.
- **follows** — `6a6cf81ed07caabbbdfbea32`: `followerId`, `followingId`, `followingName?`.

No JSON-encoded array/object fields exist in this data model (unlike the ecommerce port's order
line items / shipping address), so `mudbase/JsonFields.java` was not needed here — every field is a
flat string/number, YAGNI applies.

## Auth Flow and the Refresh-Recovery Fix

```
First visit (no token)  → POST /api/auth/anonymous → guest session (role: viewer, customRole: null)
                                                     → can read feed/post detail/profiles, cannot write
Login                   → POST /api/auth/local/login → 200 + token/refreshToken for a verified customer
                                                     → SessionAuthService.establish() stores both in HttpSession
Logout                  → POST /api/auth/logout (best-effort revoke) + HttpSession attribute cleared
Token expiry mid-request → MudbaseDataClient#execute retries once: SessionAuthService
                            #recoverFromUnauthorized exchanges the stored refresh token for a new
                            access token and the original call is silently re-issued. A second
                            call in the same request that also 401s (because the first call's
                            refresh already rotated the session forward) is NOT treated as
                            unrecoverable - it retries with the session's now-current token
                            instead. See SessionAuthService's class/method javadoc (ported from
                            the ecommerce app, not re-derived) for the full reasoning.
```

## UI Pages / Routes

| Route | Method | Auth | Notes |
|---|---|---|---|
| `/` | GET | public (anonymous session) | Feed, newest first, paginated (`?page=`), composer visible when signed in |
| `/posts` | POST | required | Create a post (content + optional image URL) |
| `/posts/{id}` | GET | public | Post detail: full post, comments oldest-first, like toggle |
| `/posts/{id}/comments` | POST | required | Add a comment |
| `/posts/{id}/like` | POST | required | Toggle like (check-then-act against `likes`) |
| `/users/{userId}` | GET | public | Profile: resolved display name, follower/following/post counts, that user's posts, follow button |
| `/users/{userId}/follow` | POST | required | Toggle follow (check-then-act against `follows`) |
| `/profile` | GET | required | Redirects to `/users/{currentUserId}` |
| `/login`, `/logout` | GET/POST | — | Email+password sign-in only (see "Stack Decisions" for why no register/verify) |

Auth gating on write routes is a controller-level check (`sessionAuthService.signedInUser(session)`
empty → `redirect:/login?redirect=...`), not a `HandlerInterceptor` covering a whole path subtree —
unlike the ecommerce port's `/orders/**`/`/seller/**` gates, every gated action here shares a URL
prefix with a public GET (e.g. `POST /posts/{id}/like` vs `GET /posts/{id}`), so a per-route check
is the correct granularity rather than a path-pattern interceptor. `GET /profile` is the one
route that is *itself* entirely gated, handled with the same inline check for consistency rather
than introducing a one-route-only interceptor (YAGNI).

## Known Limitations (real platform constraints, inherited from the reference web app)

**Post images are a pasted URL, not a file upload.** Same `rbacCheck("file","create")` constraint
documented in `../web/README.md` — every project end-user carries system role `viewer`, which can
never pass the org-owner/admin/developer-only bucket/file-create check. `PostComposerRequest` uses
a plain, optionally-blank `imageUrl` string field validated with Hibernate Validator's `@URL`.

**No `users` collection — profile display names are best-effort.** `ProfileService
#resolveDisplayName` mirrors `useResolvedDisplayName` exactly: most recent post's `authorName`,
else the first non-blank `followingName` recorded by anyone who follows that user, else the
literal string `"Member"`.

**No realtime feed updates.** See "Stack Decisions" above — a page reflects the latest data on
every request/navigation; it does not push updates into an already-open tab. Not in this port's
task scope, unlike the reference web app.

## Security Implementation

- Bean Validation (`@NotBlank`, `@Size`, `@URL`, `@Email`) on every form: post content ≤ 500 chars,
  comment content ≤ 300 chars — matching the reference web app's own zod schemas exactly.
- Authentication: Mudbase-issued JWT (access + refresh), held server-side in the Spring
  `HttpSession` — never sent to the browser. 401 → refresh → retry-once, deduped per request (see
  "Auth Flow" above).
- Authorization: enforced server-side by Mudbase's own collection permissions (`customer`-only
  create/update/delete, public read). This app's own `signedInUser` checks are UX gating (redirect
  to `/login`), not the security boundary — identical posture to the reference web app and the
  ecommerce Java port.
- Secrets: `MUDBASE_PROJECT_ID` and the four collection IDs are public identifiers, not secrets —
  there is no API key or credential of any kind in this app's configuration, since every request
  authenticates with a per-user JWT obtained through the login/anonymous-session endpoints.
- No Spring Security / CSRF tokens — same documented, deliberate scope limitation as the ecommerce
  Java port for a reference/demo app; Mudbase's own collection permissions remain the real
  authorization boundary regardless.

## Environment Variables

See `.env.example`. `MUDBASE_URL`, `MUDBASE_PROJECT_ID`, and the four
`MUDBASE_*_COLLECTION_ID` values, plus `PORT`/`APP` server wiring. No API key — every Mudbase call
in this app authenticates with a JWT (anonymous-guest or real customer), matching the reference
web app's own finding that the `pk_` publishable key is not a working credential on this backend.

## File Tree

```
mudbase-showcase-social/java/
├── pom.xml, .env.example, .gitignore, README.md
├── plan/build-plan.md
├── src/main/java/dev/mudbase/showcase/social/
│   ├── SocialApplication.java
│   ├── auth/ (AuthSession, SessionAuthService)
│   ├── config/ (MudbaseProperties, MudbaseClientFactory)
│   ├── domain/ (Post, Comment, ProfileView)
│   ├── mudbase/ (AuthResult, DocumentMapper, MudbaseApiException, MudbaseAuthClient,
│   │             MudbaseDataClient, PageResult)
│   ├── service/ (AuthService, PostService, CommentService, LikeService, FollowService,
│   │             ProfileService)
│   ├── support/ (Formatting, ViewModelHelper)
│   └── web/ (AuthController, FeedController, PostController, ProfileController,
│              GlobalExceptionHandler, dto/{LoginRequest, PostComposerRequest, CommentRequest})
└── src/main/resources/
    ├── application.properties
    ├── static/css/app.css
    └── templates/ (fragments/layout, index, posts/detail, posts/not-found, users/profile,
                     auth/login, error)
```

## Live Smoke Test Results

`mvn clean install` builds clean. See README.md "Verification performed" for the full table.
Summary: Ava's full flow (login → post → feed → detail → comment → like-toggle-on →
like-toggle-off → profile counts) was proven end-to-end through the running app against the real
Mudbase project. Cross-account verification (Ben commenting/liking/following on Ava's post) hit a
real, external, shared-IP Mudbase auth rate limit (`POST /api/auth/local/login` and
`POST /api/auth/anonymous` share one 20-requests/900s bucket) — this machine's IP was concurrently
running several other sibling-port builds' own live smoke tests against the same bucket at the
same time (confirmed: a `csharp/`, `go/`, `mobile-expo/`, `mobile-flutter/`, `python/`, `ruby/`,
and `swift/` directory all appeared as freshly-created siblings during this build, and a `php/`
port was committed to `main` mid-build). This is a platform/infrastructure constraint of testing
ten ports against one project's rate limits concurrently, not a defect in this app — see README
"Verification performed" for exactly what was and wasn't reachable given it.
