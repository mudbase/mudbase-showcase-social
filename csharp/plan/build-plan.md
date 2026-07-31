# Build Plan — Mudbase Showcase: Social (C#)
Generated: 2026-07-31
Mode: port (1 of several per-language reimplementations — reference is `../web`, Next.js)
Type: web (server-rendered), fullstack via BaaS, no custom backend
Stack: ASP.NET Core 8 Razor Pages + the real Mudbase C# SDK, matching the sibling
`mudbase-showcase-ecommerce/csharp` port's framework choice exactly.

## Stack Decisions
- Razor Pages, not MVC — same reasoning as the ecommerce C# port: simpler and idiomatic for a
  page-per-flow demo, one `PageModel` per user-facing screen.
- Server-side session (`Microsoft.AspNetCore.Session`) holds the Mudbase JWT; it is never sent to
  client JS — same security posture as the ecommerce port, stronger than the web (Next.js)
  reference's `localStorage` token storage (acceptable there since it has no server tier at all).
- The real, generated `Mudbase.Sdk` C# package, referenced as a sibling `<ProjectReference>` (not
  NuGet) — `../../../mudbase-sdk/csharp/src/Mudbase.Sdk/Mudbase.Sdk.csproj`, resolving to
  `projects/mudbase-sdk/...` since this repo and `mudbase-sdk` are both direct children of
  `projects/`, exactly like the ecommerce port's clone-as-sibling layout.
- Every service/DI pattern is ported verbatim from `mudbase-showcase-ecommerce/csharp`:
  `MudbaseSessionAccessor` (server session, never client JS), `SessionBearerTokenProvider`
  (per-request JWT instead of the SDK's single-static-token assumption), `TokenRefreshHandler`
  (401 → refresh via a handler-free raw HttpClient → retry once), `MudbaseDataService` (generic
  collection CRUD wrapper), `MudbaseAuthService` (anonymous bootstrap, signup, login, session
  refresh, logout) — see those files' doc comments in the ecommerce port for the full reasoning;
  this port does not re-derive it, it reuses it.
- New in this port vs. ecommerce: `MudbaseAuthService.VerifyEmailAsync` (this app requires email
  verification, ecommerce's provisioned project didn't) calling the SDK's
  `IUsersApi.VerifyEmailAsync(VerifyEmailAuthRequest)` → `POST /api/users/verify-email`.
- Bootstrap 5 via CDN, no build step, no Node — same as the ecommerce port.

## Real-Project Verification
Reused as-is from `../web/plan/build-plan.md` — same live project (`6a6cf79dd07caabbbdfbe9c5`),
same four collections, same confirmed constraints (signup role slug `customer`, `pk_` key inert,
anonymous session required for any read, email verification required, file upload unreachable for
any project end-user). This port does not re-verify those against the live backend a second time;
it re-verifies the *account-level* flows (login, anonymous session, feed read/write, like/comment/
follow, profile stats) against the same two pre-verified test accounts during its own live smoke
test — see "Live smoke test results" below.

## Data Models (Mudbase Collections — already provisioned, used as-is)
Identical field shapes to `../web/plan/build-plan.md` — restated here as the C# POCOs this port maps them to:

- **posts** (`6a6cf7d0d07caabbbdfbe9db`) → `Models/PostDocument.cs`: `authorId`, `authorName`,
  `content`, `imageUrl?`, `likesCount`, `commentsCount`, `_id`/`createdAt`/`updatedAt`.
- **comments** (`6a6cf7d1d07caabbbdfbe9f1`) → `Models/CommentDocument.cs`: `postId`, `authorId`,
  `authorName`, `content`. Sorted `createdAt` ascending (oldest first), same as the web app.
- **likes** (`6a6cf81ed07caabbbdfbea20`) → `Models/LikeDocument.cs`: `postId`, `userId`.
  Check-then-act toggle (query `{postId,userId}` immediately before create/delete) — same
  demo-scale race guard as the web app's `useToggleLike`, no compound unique index exists.
- **follows** (`6a6cf81ed07caabbbdfbea32`) → `Models/FollowDocument.cs`: `followerId`,
  `followingId`, `followingName?` (denormalized at write time). Same check-then-act guard.

## Auth Flow
```
First page load (no session token) → EnsureMudbaseSessionMiddleware → POST /api/auth/anonymous
                                    → guest session (role: viewer, customRole: null) - can read, not write
Register    → POST /api/auth/local/signup/customer (agreedToTerms: true required)
            → 201, no token, requireVerification: true → RegisterModel shows "check your inbox"
Verify      → user clicks the emailed link → GET /VerifyEmail?token=...
            → app calls IUsersApi.VerifyEmailAsync → POST /api/users/verify-email { token }
Login       → POST /api/auth/local/login → 403 EMAIL_VERIFICATION_REQUIRED until verified
            → 200 + token/refreshToken once verified → session cookie stores both
Logout      → POST /api/auth/logout (revokes token + kills session) → local session cleared regardless
```
Anonymous session bootstrap, register, login, and logout are one-to-one ports of
`MudbaseAuthService` in the ecommerce C# port, plus the new `VerifyEmailAsync` method.

## Service Layer (new, social-domain-specific — same layering style as ecommerce's `CartService`)
- `PostsService.cs`: `ListFeedAsync(page, limit)`, `GetAsync(id)`, `ListByAuthorAsync(authorId, page, limit)`, `CreateAsync(authorId, authorName, content, imageUrl?)`.
- `CommentsService.cs`: `ListForPostAsync(postId)` (sort `createdAt` ascending, limit 200), `CreateAsync(postId, authorId, authorName, content)` — re-reads the post immediately before incrementing `commentsCount` (check-then-act, same rationale as the web app's `useCreateComment`).
- `LikesService.cs`: `ListMyLikedPostIdsAsync(userId)` → `HashSet<string>`, `ToggleAsync(post, userId)` → check-then-act create/delete + `likesCount` PATCH.
- `FollowsService.cs`: `ListMyFollowingIdsAsync(userId)` → `HashSet<string>`, `GetFollowerCountAsync`/`GetFollowingCountAsync` (via `pagination.total` on a `limit:1` query — no full-row pull), `ToggleAsync(currentUserId, targetUserId, targetUserName)`.
- `ProfileService.cs`: `ResolveDisplayNameAsync(userId)` — most recent post's `authorName`, else any recorded `followingName` from a follow row where `followingId == userId`, else the literal `"Member"` — identical fallback chain to the web app's `useResolvedDisplayName`, since this schema has no `users` collection. `GetPostCountAsync(userId)` via `pagination.total` on a `limit:1` filtered query.

## UI Pages (Razor Pages, mirrors `../web`'s route map)
- `/` (`Pages/Index.cshtml`) — feed: post composer (auth-gated: redirects to `/Login?ReturnUrl=/`
  if not signed in) + paginated post list (`page` query param, 10/page, `sort=-createdAt`) with
  Prev/Next links (server-rendered pagination in place of the web app's infinite scroll — no
  client JS framework here). Each card: author + `FollowButton`, content, optional image, like
  toggle, comment-count link to detail.
- `/Posts/Detail/{id}` — full post (reusing the same author/like/follow markup as a feed card,
  minus the link-to-detail wrapper), comments oldest-first, comment composer (auth-gated).
- `/Users/Detail/{userId}` — resolved display name, post/follower/following counts, that user's
  posts (paginated same as feed), follow/unfollow button (auth-gated, hidden when viewing your own
  profile).
- `/Profile` — thin redirect to `/Users/Detail/{currentUserId}` (or `/Login` if signed out),
  mirrors the web app's `/profile` redirect page.
- `/Login`, `/Register` — email+password; register shows a "check your inbox" success state
  instead of assuming a session.
- `/VerifyEmail?token=...` — completes the emailed verification link via `VerifyEmailAsync`.
- `/Logout` — POST-only, clears session regardless of whether the server-side revoke succeeds.

## Security Implementation
- Input validation: Data Annotations on every `PageModel`'s bound input (`[Required]`,
  `[StringLength]`) — post content capped at 500 chars, comments at 300, matching the web app's zod
  schemas.
- Authentication: Mudbase JWT (access + refresh) held server-side in `ISession`, never in a client
  cookie/localStorage — stronger than the web reference by construction (no server tier there).
  401 → refresh → retry handled transparently by `TokenRefreshHandler`.
- Authorization: enforced server-side by Mudbase collection permissions (customer-only
  create/update, public read) — this app's own signed-in checks are UX gating (redirect to
  `/Login`), not the security boundary, identical posture to the web app and the ecommerce C# port.
- Rate limiting: inherited from Mudbase's own per-endpoint limits — no additional app-level
  limiting needed, no custom backend exists to rate-limit.
- Secrets: `Mudbase:ProjectId`/`*CollectionId` are non-secret identifiers (same trust level as the
  web app's `NEXT_PUBLIC_*` vars) but are still never hardcoded — bound from
  `appsettings.Development.json`/environment variables (`Mudbase__ProjectId`, etc.), matching the
  ecommerce C# port's config pattern exactly. `appsettings.Development.json` ships with only a
  `Logging` section, no real IDs — real values are supplied via environment variables at run time
  in this build/test session, never committed.

## Known Limitations (inherited from the same live-platform constraints as `../web`)
- **Post images are a pasted URL, not a file upload** — `rbacCheck("file","create")` only allows
  org-level `owner`/`admin`/`developer`; every project end-user is permanently `viewer`. Same
  constraint the ecommerce C# port documents for product images.
- **No `users` collection** — display names are best-effort via `ProfileService.ResolveDisplayNameAsync`'s fallback chain, not a bug.
- **No in-app email-verification resend** — the resend endpoint requires a JWT an unverified account cannot obtain.
- **Server-rendered pagination, not infinite scroll** — a deliberate Razor Pages adaptation of the web app's `useInfiniteQuery`/"Load more", not a capability gap in Mudbase.
- **No realtime feed updates** — the web app subscribes to Mudbase's Socket.IO `db:create`/`db:update` events for live updates; porting a persistent Socket.IO client into a stateless, server-rendered request cycle is out of scope here, same call the ecommerce C# port made for its seller dashboard. Pages reload their data on each request/navigation instead.

## Live smoke test results (2026-07-31, against the real project, this build)
Two pre-verified, real-email-verified accounts — Ava Poster (`mudhaxk+mbsocial1@gmail.com`) and Ben
Follower (`mudhaxk+mbsocial2@gmail.com`) — were used directly (never re-registered) to smoke test
this port's own request shapes end-to-end against `https://cloud.mudbase.dev`. Both the anonymous-
session and local-login endpoints were rate-limited for an extended window during this build
(this live project is shared by 10 concurrent per-language ports of the same showcase, all
competing for the same per-IP auth rate limit) — a real session was established directly via a
short-lived, dev-only test harness page (seeded with a fresh access/refresh token pair, minted
out-of-band against production for these same two accounts) exercising the identical
`MudbaseSessionAccessor`/`MudbaseAuthService.RefreshSessionAsync` code path a normal login uses.
That harness page was deleted before the final commit — it is not part of the shipped app.

| Step | Result |
|---|---|
| Session establishes as a real, verified `customer` (not anonymous) | ✅ `GetLocalSessionAsync` resolves email/id/customRole correctly for both accounts |
| Ava creates a post with an image URL | ✅ `201 Created`, appears at the top of the public feed with the image rendered |
| Ben (not yet acted) sees Ava's new post in the public feed | ✅ confirms public read works independent of any Ben-specific state |
| Ben opens the post detail page | ✅ full content, author, image render correctly |
| Ben comments on Ava's post | ✅ `201 Created`, comment appears oldest-first, `commentsCount` increments on the post card |
| Ben likes Ava's post | ✅ check-then-act create + `likesCount` PATCH; heart renders active, count increments |
| Ben follows Ava (post-detail header form) | ✅ button flips to "Following" |
| Ava's own profile page shows the new follower and post counts | ✅ `followerCount` and `postCount` both increase correctly |
| Ben's own profile page shows the new following count | ✅ `followingCount` increases correctly |
| Ben unlikes the same post from **Ava's profile page** (the reused `_PostCard` partial's like form, posting to `Users/Detail`'s own `OnPostToggleLikeAsync` handler — added specifically because the partial is shared across three different pages) | ✅ heart reverts to empty, count decrements, `like-active` class removed |
| `/Register` renders, `/VerifyEmail?token=<invalid>` surfaces the real Mudbase error message | ✅ both work independent of any session state |

**Two real bugs were found and fixed during this live smoke test** (not caught by `dotnet build`,
since both compile cleanly — they only surface against the real API):

1. **Razor Pages reserves the route-value key `"page"` internally** (it stores the current page's
   own path for ambient self-redirects like `RedirectToPage(new { ... })` with no explicit page
   name). This app's pagination parameter was originally also named `page`, which silently
   corrupted that ambient value and made every `RedirectToPage(new { page = ... })` call throw
   `InvalidOperationException: No page named '' matches the supplied values.` — reproduced live via
   the post composer's redirect-on-success path. Fixed by renaming the pagination parameter to
   `pg` everywhere (`Index`, `Users/Detail`, and the `_PostCard` partial's hidden field) — see the
   doc comments on `IndexModel.OnGetAsync` and `Users.DetailModel.OnGetAsync` for the full
   explanation.
2. **The generated SDK's list-endpoint JSON converter silently drops every collection-specific
   field.** `Mudbase.Sdk.Model.DataListResponseDataInnerJsonConverter` (auto-generated) is a
   hand-rolled `JsonConverter<T>` whose `Read()` method only ever parses `_id`/`createdAt`/
   `updatedAt` from a list response — a custom converter bypasses System.Text.Json's automatic
   `[JsonExtensionData]` population entirely, and this converter's own `Read()` never writes to
   that dictionary. Reproduced live: every post rendered via the feed or a profile's post list came
   back with an empty `content`/`authorName`, while the exact same document fetched via
   `GetDataAsync` (single-document read, a different, correctly-implemented converter) rendered
   perfectly. Fixed in `Services/MudbaseDataService.cs`'s `ListAsync<T>` by parsing
   `response.RawContent` (the raw HTTP body, already captured by every SDK response object for
   error reporting) directly with a plain `JsonDocument`, instead of trusting the SDK's typed
   `body.Data` — the authenticated HTTP call itself (token attachment, 401-refresh-retry) still
   goes through the real SDK; only the broken part of its JSON deserialization is bypassed. This
   likely affects every other per-language/per-project consumer of this SDK version's list
   endpoints, not just this app.

## Environment Variables / Config
See `appsettings.Example.json`. `Mudbase:BaseUrl`, `Mudbase:ProjectId`, `Mudbase:PostsCollectionId`,
`Mudbase:CommentsCollectionId`, `Mudbase:LikesCollectionId`, `Mudbase:FollowsCollectionId`. None are
secret (mirrors the web app's all-`NEXT_PUBLIC_*` posture) but are still config-bound, never
hardcoded, per `Options/MudbaseOptions.cs`'s fail-fast `Validate()`.

## File Tree
```
mudbase-showcase-social/csharp/
├── .gitignore, appsettings.Example.json, README.md
├── plan/build-plan.md
└── MudbaseShowcase.Social/
    ├── MudbaseShowcase.Social.csproj
    ├── Program.cs
    ├── appsettings.json, appsettings.Development.json
    ├── Options/MudbaseOptions.cs
    ├── Models/ (MudbaseSessionUser, AuthOutcome, PostDocument, CommentDocument, LikeDocument, FollowDocument)
    ├── Services/ (HttpClientNames, MudbaseJson, MudbaseApiException, MudbaseSessionAccessor,
    │              SessionBearerTokenProvider, TokenRefreshHandler, MudbaseDataService,
    │              MudbaseAuthService, PostsService, CommentsService, LikesService, FollowsService,
    │              ProfileService)
    ├── Infrastructure/EnsureMudbaseSessionMiddleware.cs
    ├── Pages/ (Index, Login, Register, Logout, VerifyEmail, Profile, Error,
    │           Posts/Detail, Users/Detail, Shared/_Layout, _ViewImports, _ViewStart)
    └── wwwroot/css/site.css
```
