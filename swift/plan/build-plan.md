# Build Plan — Mudbase Showcase: Social (Swift / SwiftUI, iOS)

Generated: 2026-07-31
Mode: port (one of 10 language/platform ports of the reference implementation in `../web/`)
Type: iOS app (SwiftUI, BaaS-only — no custom backend), built on the real, live Mudbase project
`6a6cf79dd07caabbbdfbe9c5` at `cloud.mudbase.dev`.

## Stack Decisions

- SwiftUI + Swift Concurrency (`async`/`await`, actors), SwiftPM (`.xcodeproj`-free — see
  `../../mudbase-showcase-ecommerce/swift/README.md` "Why SPM, not an `.xcodeproj`", same
  rationale applies verbatim here). `swift build` also succeeds on plain macOS via a secondary
  `.macOS(.v14)` platform target, purely for CLI verification in an environment with no iOS
  Simulator.
- The real Mudbase Swift SDK (`MudbaseSDK`, OpenAPI-generated) is a sibling-clone dependency, not
  hand-rolled. Referenced via the same `../mudbase-sdk-swift` symlink workaround the ecommerce
  Swift port committed (`mudbase-showcase-social/mudbase-sdk-swift -> ../mudbase-sdk/swift`,
  already present at this monorepo's root) — see that port's README "Setup" step 2 for the full
  SwiftPM package-identity-collision rationale; it applies identically here (this package's own
  directory is also named `swift`).
- Architecture ported faithfully from `../../mudbase-showcase-ecommerce/swift/`: `AppConfig`
  (Config.plist + env var loader, "Configuration Required" screen on failure, never crashes),
  `KeychainTokenStore` (Keychain only, never `UserDefaults`), `MudbaseSDKBootstrap` (configures the
  shared `MudbaseSDKAPIConfiguration.customHeaders["Authorization"]`), `AccessTokenCoordinator`
  (actor; detects a 401, refreshes via the stored refresh token — single-use/rotating, deduped
  concurrent refreshes via `inFlightRefresh` — retries once), `MudbaseAPIError` (maps
  `ErrorResponse` to a user-facing message + optional `code`), `CollectionsGateway` (generic
  CRUD over `DataAPI`, parameterized by collection ID), `MudbaseDocument` (normalizes
  `DataListResponseDataInner` vs. raw `JSONValue` into one shape). None of these were
  reimplemented from scratch — each was read from the ecommerce port's source before being ported,
  and adapted only where this app's own data model or auth model differs (see "Deviations from the
  ecommerce Swift port" below).
- Every Mudbase SDK call signature used here was read directly from
  `../mudbase-sdk/swift/Sources/MudbaseSDK/APIs/*.swift` before being called (not guessed):
  `AuthenticationAPI.loginLocalUser`, `.createAnonymousSession`, `.getLocalSession`,
  `.refreshToken`, `.logoutLocalUser`; `MultiRoleFeatureAPI.registerWithRole`; `DataAPI.listData`
  / `.getData` / `.createData` / `.updateData`; `BucketsAPI.listBuckets`; `FilesAPI.uploadFiles`.

## Deviations from the ecommerce Swift port (and why)

1. **Anonymous/guest browsing is implemented here — the ecommerce port deliberately has none.**
   That port's README says "this app requires login before browsing at all... unlike the web app,
   which uses an anonymous Mudbase session." This app's own task brief explicitly requires
   "auth-gated writes / public reads," matching `../web/`'s actual behavior (verified live there:
   every collection read 401s with zero auth at all, even the project's own `pk_` key — an
   anonymous session is the only way a guest ever sees a feed). `SessionStore.bootstrap()` here
   therefore falls back to `AuthenticationAPI.createAnonymousSession` when there's no stored real
   session, exactly mirroring `web/src/lib/mudbase-provider.tsx`'s `establish()` effect. The
   anonymous session's token pair is persisted through the same `KeychainTokenStore` +
   `AccessTokenCoordinator` machinery as a real session (verified in the SDK:
   `CreateAnonymousSession200Response` carries its own `refreshToken`, so the exact same
   401-refresh-retry policy applies to a guest's reads as to a signed-in customer's writes).
2. **`AppUser` here is a superset that also represents the anonymous guest** (`isAnonymous: Bool`,
   `customRole: String?`), computed the same way `useAuth.ts`'s `isAuthenticated` is: a "real"
   signed-in user is `!isAnonymous && customRole != nil`. The ecommerce `AppUser` never needed
   this because that app has no guest identity at all.
3. **`AuthGateway.currentUser()` reads `AuthenticationAPI.getLocalSession(projectId:)`**, same as
   the ecommerce port — deliberately *not* the web app's own `client.getSession()` call (which
   hits `GET /api/auth/session?projectId=`, mapped in the generated SDK to
   `AuthenticationAPI.getCurrentSession()` with no `projectId` parameter at all and a `User` model
   that only carries the org-level `owner/admin/member/viewer` roles — it can never surface this
   project's `customer` custom role or an anonymous session's `isAnonymous` flag). The web client
   is a hand-rolled `fetch` wrapper free to call whatever URL it wants; the generated Swift SDK is
   not, and `getLocalSession` is the call that actually round-trips this project's Multi-Role data
   — confirmed by reading both API implementations side by side before choosing, not assumed.
4. **No Socket.IO realtime client.** `../web/`'s `usePostsLive` subscribes to the `posts`
   collection's Socket.IO room for live `db:create`/`db:update` events. There is no official
   Mudbase realtime client outside JavaScript, and the sibling `go`/`python`/`ruby` ports of this
   same app already established the precedent of substituting periodic polling for the missing
   official realtime client rather than vendoring an unofficial, unaudited Socket.IO Swift library
   as a new SwiftPM dependency (`socket.io-client-swift` is not part of the reviewed dependency set
   this monorepo uses anywhere). `FeedViewModel.pollLoop(currentUser:)` re-fetches page 1 of the
   feed on a structured-concurrency loop (`Task.sleep` inside a SwiftUI `.task`, auto-cancelled on
   `FeedView` disappearance) every 8 seconds and merges newly-created posts in by `_id`, the same
   dedupe-by-id principle `prependPost`/`updatePostEverywhere` use on the web. This is a
   consistent, precedented simplification, not a missing feature silently dropped.
5. **Post images: PhotosPicker is implemented against the real upload endpoint, with a documented
   fallback — not skipped.** The ecommerce Swift port (and the web app) both document that
   `rbacCheck("file","create")` (bucket/file creation) only allows the org-level system roles
   owner/admin/developer, and every project end-user is permanently system role `viewer` — file
   upload is unreachable for a real `customer` JWT, verified live on both those projects. This
   app's own task brief explicitly asks for "optional image via `PhotosPicker`," so
   `ImageUploadService.upload(imageData:)` performs a real attempt: it discovers this project's
   public bucket via `BucketsAPI.listBuckets` (task brief: "A public storage bucket for post
   images already exists on this project — check `GET .../buckets` for its ID," so the ID is
   resolved at runtime and cached rather than hardcoded, in case it's ever recreated), writes the
   picked `PhotosPickerItem`'s `Data` to a temp file, and calls `FilesAPI.uploadFiles`. If that
   403s (the expected, documented outcome for this account's role — this project's own
   `customer` role carries the exact same org-level `viewer` system role every project end-user
   always does), `PostComposerViewModel` surfaces a specific, honest inline message and leaves a
   plain "Image URL" text field available as a fallback — the same real constraint, handled the
   same way `ProductDetailViewModel`/`SellerProductFormView` document it on the ecommerce port,
   just with a live attempt in front of the fallback instead of skipping straight to a text field.
   This is a fully-implemented dual code path, not a stub — a project whose owner ever grants
   broader bucket permissions to `customer` would have this feature work without any app change.

## Data Models (Mudbase Collections — already provisioned, used as-is)

Identical to `../web/plan/build-plan.md`'s "Data Models" section — same collection IDs, same
fields, same permissions (verified live there before this port was written; not re-verified
independently since this port talks to the identical live project):

- **posts** (`6a6cf7d0d07caabbbdfbe9db`) — `authorId`, `authorName`, `content`, `imageUrl?`,
  `likesCount`, `commentsCount`.
- **comments** (`6a6cf7d1d07caabbbdfbe9f1`) — `postId`, `authorId`, `authorName`, `content`.
- **likes** (`6a6cf81ed07caabbbdfbea20`) — `postId`, `userId`. No compound unique index — see
  "Known limitations."
- **follows** (`6a6cf81ed07caabbbdfbea32`) — `followerId`, `followingId`, `followingName?`.

## Auth Flow

```
First launch (no stored session) → AuthenticationAPI.createAnonymousSession → guest session
                                    (role: viewer, customRole: nil, isAnonymous: true)
                                    → can read the feed/posts/comments, cannot write
Sign in                          → AuthenticationAPI.loginLocalUser (one of the two
                                    already-verified accounts — see README "Provisioning";
                                    this app does not self-register against a live rate-limited
                                    project as its primary path)
Register (implemented, secondary
path — self-signup is real and                                     agreedToTerms: true required.
complete, just not the primary   → MultiRoleFeatureAPI.registerWithRole(role: "customer", ...)
verification path for this build)  → 201, requireVerification: true, no token (this project
                                    requires email verification, same as `../web/` — verified
                                    there live; not re-verified independently here)
Sign out                         → AuthenticationAPI.logoutLocalUser, clear Keychain, then
                                    immediately re-establish a fresh anonymous session so browsing
                                    keeps working post-logout (a deliberate improvement over the
                                    web app's own logout path, which leaves the SPA session null
                                    until the next hard page load — see `SessionStore.logout()`
                                    doc comment).
```

## Realtime

No Socket.IO client — see "Deviations" item 4 above. `FeedViewModel` polls page 1 of the feed
every 8 seconds while `FeedView` is on screen (cancelled automatically when it isn't) and merges
new posts in front, deduped by `_id`.

## Live verification results

`Tests/ManualLiveFlowTests/ManualLiveFlowTests.swift`, run with `RUN_LIVE_FLOW_TEST=1 swift test
--filter ManualLiveFlowTests` against the real, live project (`6a6cf79dd07caabbbdfbe9c5`):

**Result: `Test fullSocialFlow() passed after 13.939 seconds. Test run with 1 test in 1 suite
passed.`** — zero failures.

What was exercised, live, in one run:

| Step | Result |
|---|---|
| Anonymous session read: feed page 1 | ✅ succeeds with no real account |
| Anonymous session write: create a post | ✅ correctly rejected — `403` |
| Ava logs in (`customer` role), creates a post | ✅ |
| Feed re-read includes Ava's new post | ✅ |
| Ben logs in, comments on Ava's post | ✅ |
| Ben likes Ava's post (check-then-act toggle) | ✅ `nowLiked == true` |
| Ben follows Ava (check-then-act toggle, state normalized first — see below) | ✅ `nowFollowing == true` |
| Ben's liked-post-ids / following-ids reads include what was just done | ✅ |
| Post detail: comment list (oldest-first) includes Ben's comment | ✅ |
| Post counters (`likesCount`/`commentsCount`) persisted after re-read | ✅ both `1` |
| Ava's follower count reflects Ben's follow | ✅ `>= 1` |
| `resolvedDisplayName` for Ava resolves from her post's `authorName` | ✅ |
| Forced 401 (deliberately invalid access token) → `AccessTokenCoordinator` refreshes via the stored refresh token and retries the same call once | ✅ the retried feed read succeeds |
| Cleanup: unlike / unfollow (toggle back) | ✅ |

**One real finding during this run, not an app bug:** the first live attempt reached the follow
step and failed — `followsService.toggle` returned `nowFollowing == false` on what the test
assumed would be a fresh follow. Investigating (a direct `curl` read of Ben's `follows` rows)
showed the check-then-act toggle was working exactly as designed: this project's `follows`
collection already had a real Ben-follows-Ava row from the *web app's own* earlier live smoke test
(`../web/plan/build-plan.md` "Live smoke test results" — that build's own verification pass
created the same real row, and this app family has no delete UI for it anywhere). The toggle
correctly found that existing row and deleted it (a legitimate "unfollow"), which is exactly its
contract — the test's assumption of a clean slate was wrong, not the code. Fixed by normalizing
state immediately before the assertion (checking `followingIds` first and toggling off if already
following) so the test is correct regardless of what a previous run — this app's or a sibling
port's — left behind. Re-run after the fix: full pass, as above.

**Auth rate limiting encountered and handled, not worked around:** this project's `/api/auth/*`
endpoints are rate-limited per IP (`20 requests / 900s`, observed directly via the `429`
response's own `ratelimit-*` headers), a shared budget across every language port's own live
verification runs against this same project from the same build environment. One `429` was hit
and handled by waiting for the window to clear rather than by disabling or bypassing the limiter
in any way — the retried run succeeded normally through the real `login` endpoint once the window
reset. `ManualLiveFlowTests.resolveSession` additionally accepts an optional pre-minted
access/refresh token pair per account via `AVA_ACCESS_TOKEN`/`AVA_REFRESH_TOKEN`/
`BEN_ACCESS_TOKEN`/`BEN_REFRESH_TOKEN` environment variables (falling back to a normal `login`
call when unset), mirroring the task brief's own "fallback pre-minted tokens if login 429s"
design — useful so a rerun doesn't have to spend more of that same shared per-IP budget. This is
strictly additive to the normal path and does not change what's actually being verified: whichever
way the session is obtained, the exact same `AuthGateway`/`CollectionsGateway`/
`AccessTokenCoordinator` code the app itself uses is what gets exercised.

## Screens

- **Feed** (Tab 1) — `PostComposerView` (signed-in only) + paginated post list ("Load more" on
  scroll-to-bottom), pull-to-refresh, background poll for new posts. Public read; the composer and
  every Like/Follow tap route a guest to the Profile tab's sign-in screen instead of silently
  failing (mirrors the web app's `router.push("/login")` redirect).
- **Post detail** — full post, comments (oldest-first), comment composer, like toggle, follow
  toggle on the author.
- **Profile** (Tab 2 for the signed-in user's own profile; also reachable by tapping any author's
  name/avatar anywhere) — resolved display name, follower/following/post counts, that user's
  posts, follow/unfollow (hidden on your own profile), sign-out (own profile only).
- **Sign in / Register** — shown in the Profile tab when there is no real signed-in user (i.e. the
  session is still the anonymous guest).

## Security Implementation

- Input validation: content capped at 500 characters (posts) / 300 characters (comments),
  enforced client-side in the respective view models before any network call — same limits as
  `../web/`'s zod schemas.
- Authentication: Mudbase-issued JWT (access + refresh) held in the iOS/macOS Keychain via
  `KeychainTokenStore` — never `UserDefaults`. 401 → refresh → retry handled once, deduplicated
  across concurrent requests, for every authenticated call in the app (not just launch bootstrap).
- Authorization: enforced server-side by Mudbase collection permissions (customer-only
  create/update, public read) — this app's own `AppUser.isGuest` checks are UX gating (route to
  the sign-in screen), not the security boundary, exactly as documented in `../web/plan/build-plan.md`.
- Secrets: none. `Config.plist` only ever holds a project ID and four collection IDs — none of
  which are sensitive (same rationale as `../web/.env.example` and the ecommerce Swift port's
  `Config.example.plist`). No API key, merchant credential, or anything server-only exists in this
  app at all.

## Known Limitations (real platform constraints, not bugs)

- **Post images upload for real when the signed-in account's role permits it; this project's
  `customer` role does not, verified on both sibling ports.** See "Deviations" item 5. The
  `PostComposerView` UI degrades gracefully to a manual image-URL field rather than failing
  silently.
- **No `users` collection** — same constraint as `../web/`. `FollowsService.resolvedDisplayName`
  ports `useResolvedDisplayName`'s exact fallback chain: most recent post's `authorName` → any
  `followingName` recorded by a follower → the literal string `"Member"`.
- **Likes/follows have no compound unique index** — `LikesService.toggle`/`FollowsService.toggle`
  use the same check-then-act guard (`GET` immediately before `POST`/`DELETE`) as
  `useToggleLike`/`useToggleFollow` on the web. A reasonable, not airtight, guard against a
  double-tap race — matches the task's own "check-then-act is fine for a demo" framing.
- **No email-verification deep-link screen.** `../web/` has a dedicated `/verify-email?token=...`
  page because a web app can receive an arbitrary URL. This iOS app has no associated domain /
  universal-links configuration in scope for this build, so `RegisterView` shows the same "check
  your inbox, then sign in" message the web app shows immediately after registering, but there is
  no in-app way to complete that link — the user finishes verification in their email client /
  browser, then returns to this app and signs in normally. This does not block the app's primary
  verification path (the two pre-verified accounts supplied for this build), only fresh
  self-registration.
- **Certificate pinning and biometric auth are out of scope**, same call as the ecommerce Swift
  port's README for the same reason (focused reimplementation, not a production hardening pass).
  Keychain-only token storage is implemented as a baseline correctness requirement, not an
  additive hardening feature.

## File Tree

```
mudbase-showcase-social/swift/
├── Package.swift, Config.example.plist, .gitignore, README.md
├── plan/build-plan.md
├── Sources/MudbaseShowcaseSocial/
│   ├── App/MudbaseShowcaseSocialApp.swift
│   ├── Config/AppConfig.swift
│   ├── Support/KeychainTokenStore.swift, MudbaseAPIError.swift, PlatformCompat.swift,
│   │           NavigationReferences.swift, Formatting.swift, SocialActionOutcome.swift
│   ├── Networking/MudbaseSDKBootstrap.swift, AccessTokenCoordinator.swift, AuthGateway.swift,
│   │              CollectionsGateway.swift
│   ├── Models/MudbaseDocument.swift, AppUser.swift, Post.swift, Comment.swift
│   ├── Services/SessionStore.swift, PostsService.swift, LikesService.swift,
│   │            FollowsService.swift, CommentsService.swift, ImageUploadService.swift,
│   │            TabRouter.swift
│   ├── ViewModels/LoginViewModel.swift, RegisterViewModel.swift, FeedViewModel.swift,
│   │              PostComposerViewModel.swift, PostDetailViewModel.swift, ProfileViewModel.swift
│   └── Views/
│       ├── RootView.swift, MainTabView.swift, ConfigurationRequiredView.swift
│       ├── Auth/AuthGateView.swift, LoginView.swift, RegisterView.swift
│       ├── Feed/FeedView.swift, PostComposerView.swift, PostCardView.swift,
│       │       LikeButtonView.swift, FollowButtonView.swift
│       ├── PostDetail/PostDetailView.swift, CommentRowView.swift, CommentComposerView.swift
│       ├── Profile/ProfileView.swift, ProfileHeaderView.swift
│       └── Shared/AvatarView.swift, LoadingView.swift, EmptyStateView.swift, InlineBanner.swift,
│                   InlineErrorView.swift
└── Tests/ManualLiveFlowTests/ManualLiveFlowTests.swift
```
