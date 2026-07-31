# Mudbase Showcase — Social (C# / ASP.NET Core)

A realtime social micro-blog built **entirely on [Mudbase](https://www.mudbase.dev)** — auth,
database, no realtime bridge (see "Known limitations") — using ASP.NET Core Razor Pages and the
real, generated [Mudbase C# SDK](https://github.com/mudbase/mudbase-sdk). This is a C#
reimplementation of the reference micro-blog that also exists at `../web` (Next.js) in this same
monorepo — same Mudbase project, same collections, same business logic, different stack. It
mirrors the folder layout, DI wiring, and service patterns of the sibling
`mudbase-showcase-ecommerce/csharp` port exactly (same framework choice: Razor Pages, not MVC).

## Stack

ASP.NET Core 8 (Razor Pages) + the real `Mudbase.Sdk` package (referenced as a sibling project,
not from NuGet — see "Setup" below). Server-side session (`Microsoft.AspNetCore.Session`) holds
the Mudbase JWT; it is never sent to client JS. Bootstrap 5 (via CDN) for styling — no build step,
no Node.js required.

## What it demonstrates

| Feature | Mudbase capability | Where |
|---|---|---|
| Guest browsing with no signup | Anonymous auth (`POST /api/auth/anonymous`) | `Services/MudbaseAuthService.cs` (`EnsureAnonymousSessionAsync`), bootstrapped by `Infrastructure/EnsureMudbaseSessionMiddleware.cs` |
| Email/password accounts | Multi-Role signup (`POST /api/auth/local/signup/customer`) | `Services/MudbaseAuthService.cs` (`RegisterCustomerAsync`) |
| Email verification gate | `POST /api/users/verify-email` via `IUsersApi.VerifyEmailAsync` | `Pages/VerifyEmail.cshtml(.cs)` |
| Public feed, paginated | Collections, public read (`GET .../data?page=&limit=`) | `Services/PostsService.cs`, `Pages/Index.cshtml(.cs)` |
| Post + optional image | Ownership-scoped create, `imageUrl` as a pasted URL | `Pages/Index.cshtml(.cs)` (`OnPostCreateAsync`) |
| Like / unlike | Ownership-scoped create/delete + counter update, check-then-act | `Services/LikesService.cs` |
| Comment thread | Ownership-scoped create + counter update, oldest-first | `Services/CommentsService.cs` |
| Follow / unfollow | Ownership-scoped create/delete, check-then-act | `Services/FollowsService.cs` |
| Profile (posts, follower/following counts, resolved display name) | Filtered reads + `pagination.total` as a count | `Services/ProfileService.cs`, `Pages/Users/Detail.cshtml(.cs)` |

## Setup

### 1. Clone the SDK as a sibling directory

The `.csproj` references the real Mudbase C# SDK via a relative `<ProjectReference>` — it is
**not published to NuGet**. It must be cloned as a sibling of `mudbase-showcase-social` (the repo
this `csharp/` folder lives in), i.e.:

```
<some-parent-directory>/
├── mudbase-showcase-social/     ← this repo (you are in csharp/ inside it)
└── mudbase-sdk/                 ← clone this next to it
```

```bash
cd <the directory containing mudbase-showcase-social>
git clone https://github.com/mudbase/mudbase-sdk.git
```

### 2. Provision a Mudbase project

This app expects a Mudbase project already set up with (same requirements as `../web`):

1. Local auth enabled, with email verification required.
2. The Multi-Role feature's default `customer` role (Mudbase's single-role starter template).
3. Four collections — `posts`, `comments`, `likes`, `follows` — with the field/permission shapes
   documented in `../web/plan/build-plan.md`, the `customer` role granted
   `create`/`read`/`update`/`delete`, `dataScope: "all"`, on all four.

### 3. Configure

Copy the `Mudbase` section from `appsettings.Example.json` into
`MudbaseShowcase.Social/appsettings.Development.json`, filling in your own project's IDs. In
production, set the equivalent `Mudbase__<Key>` environment variables (e.g.
`Mudbase__ProjectId=...`) instead of committing real values.

### 4. Build and run

```bash
cd MudbaseShowcase.Social
dotnet build
dotnet run
```

The app fails fast at startup with a clear message if any required `Mudbase:*` config value is
missing — see `Options/MudbaseOptions.cs`.

## Auth flow

```
First page load (no session token) → EnsureMudbaseSessionMiddleware → POST /api/auth/anonymous
                                    → guest session (role: viewer, customRole: null) - read only
Register    → POST /api/auth/local/signup/customer (agreedToTerms: true required)
            → 201, no token, requireVerification: true → "check your inbox" success state
Verify      → user clicks the emailed link → GET /VerifyEmail?token=...
            → IUsersApi.VerifyEmailAsync → POST /api/users/verify-email { token }
Login       → POST /api/auth/local/login → 403 EMAIL_VERIFICATION_REQUIRED until verified
            → 200 + token/refreshToken once verified → stored server-side in session
Logout      → POST /api/auth/logout (revokes token + kills session) → local session cleared regardless
```

## Known limitations (real platform constraints, not bugs — same as `../web`)

**Post images are a pasted URL, not a file upload.** `rbacCheck("file","create")` (both bucket
creation and file upload) only allows the org-level system roles owner/admin/developer. Every
project end-user — including a real, verified `customer` account — always carries system role
`viewer`. `PostDocument.ImageUrl` accepts a plain URL string; there is no upload UI, same
constraint the ecommerce showcase documents for product images.

**No `users` collection, so profile display names are best-effort.** `Services/ProfileService.cs`'s
`ResolveDisplayNameAsync` falls back through: the user's most recent post's `authorName` → any
`followingName` recorded by someone who follows them → the literal string `"Member"`. A user who
has never posted and has no followers has no row anywhere recording their name.

**No in-app email-verification resend.** The resend endpoint requires a valid JWT, which an
unverified account cannot obtain (login is blocked until verified) — there is no accessible path
around this from a project end-user's own permissions.

**Server-rendered pagination, not infinite scroll.** The web (Next.js) reference app uses
`useInfiniteQuery`/"Load more" against a client-side cache. This server-rendered Razor Pages port
uses a plain `page` query-string parameter with Prev/Next links instead — same underlying
`GET .../data?page=&limit=` contract, different UI idiom for a stateless request/response cycle.

**No realtime feed updates.** The web app subscribes to Mudbase's Socket.IO `db:create`/`db:update`
events so new posts/likes/comments appear live. Porting a persistent Socket.IO client connection
into a stateless, server-rendered Razor Pages request cycle is a meaningfully different
architecture (a background service + SignalR bridge to the browser, at minimum) and was out of
scope here, the same call the ecommerce C# port made for its seller dashboard. Pages reload their
data on each request/navigation instead.

**The generated SDK's token pipeline assumes one static token per app.** `HostConfiguration.AddTokens`
+ `UseProvider` are built for a server-to-server API key registered once at startup — this app has
many concurrent browser sessions, each with its own Mudbase JWT (anonymous guest or customer) that
changes over the app's lifetime. `Services/SessionBearerTokenProvider.cs` overrides the SDK's
`TokenProvider<BearerToken>` to resolve whichever JWT the *current* request's session holds, via
`IHttpContextAccessor`.

**Access tokens expire mid-session, transparently.** `Services/TokenRefreshHandler.cs` is a
`DelegatingHandler` attached to every one of the generated SDK's HttpClients (see `Program.cs`). On
a `401`, it exchanges the session's stored refresh token for a new access/refresh pair via
`POST /api/auth/refresh` (through a separate, handler-free `HttpClient` so the refresh call itself
can never recurse through this same pipeline) and retries the original request once with the new
token.

## Project layout

```
MudbaseShowcase.Social/
├── Program.cs                    ← DI wiring, incl. the Mudbase SDK's own DI extensions
├── appsettings.json               ← non-secret defaults + empty Mudbase:* placeholders
├── Options/MudbaseOptions.cs      ← strongly-typed config, fail-fast validation
├── Models/                        ← PostDocument, CommentDocument, LikeDocument, FollowDocument,
│                                     MudbaseSessionUser, AuthOutcome, PostCardViewModel
├── Services/                      ← MudbaseDataService (generic CRUD), MudbaseAuthService,
│                                     PostsService, CommentsService, LikesService, FollowsService,
│                                     ProfileService, session/token/JSON helpers
├── Infrastructure/                ← EnsureMudbaseSessionMiddleware (anonymous session bootstrap)
└── Pages/                         ← Index (feed), Posts/Detail, Users/Detail, Profile, Login,
                                       Register, Logout, VerifyEmail, Shared/_PostCard partial
```

## Verification

`dotnet build` passes with 0 errors, 0 warnings against the real `Mudbase.Sdk` project reference
(net8.0, `Nullable` enabled, `WarningsAsErrors` on the `nullable` category).

Live-smoke-tested end-to-end at runtime against `https://cloud.mudbase.dev` using the real,
already-provisioned project and the two pre-verified test accounts (Ava Poster, Ben Follower)
shared with every other per-language port of this showcase: post creation with an image, public
feed read, post detail, commenting, liking/unliking (including from a reused partial view on a
different page), following, and follower/following/post count updates on both accounts' profile
pages — see `plan/build-plan.md` → "Live smoke test results" for the full step-by-step table.

Two real bugs were found and fixed during that live test (both compile cleanly, so `dotnet build`
alone never would have caught them):

1. Razor Pages reserves the route-value key `"page"` internally for ambient page self-redirects;
   this app's pagination parameter was originally also named `page`, which corrupted
   `RedirectToPage(new { ... })` calls. Renamed to `pg` throughout.
2. The generated SDK's list-endpoint JSON converter (`DataListResponseDataInnerJsonConverter`)
   silently drops every collection-specific field — it only ever parses `_id`/`createdAt`/
   `updatedAt`. `Services/MudbaseDataService.cs`'s `ListAsync<T>` now parses the raw response body
   directly instead of trusting the SDK's typed list-item model, while still using the SDK for the
   authenticated HTTP call itself.

See `plan/build-plan.md` for the full write-up of both, including how they were diagnosed.
