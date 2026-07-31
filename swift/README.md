# Mudbase Showcase — Social (SwiftUI / iOS)

A production-shaped SwiftUI iOS micro-blog built entirely on top of [Mudbase](https://www.mudbase.dev)
— zero custom backend — reimplementing the same reference app ("Field Notes") as the companion
Next.js app in `../web/`: same four collections (`posts`, `comments`, `likes`, `follows`), same
permissions model, same auth flow. Auth, the feed, post detail, and profiles all talk directly to
`cloud.mudbase.dev` through the real generated Mudbase Swift SDK.

## Why SPM, not an `.xcodeproj`

This package is deliberately `.xcodeproj`-free — same rationale as the sibling
`../../mudbase-showcase-ecommerce/swift` port this app's architecture is ported from. Since Xcode
14, you can open a `Package.swift` directly and run an `executableTarget` that defines a SwiftUI
`App` (`@main`) as a real iOS app on a Simulator or device — Xcode synthesizes the Info.plist/
bundle at build time, no project file needed. `swift build` from the CLI also succeeds on plain
macOS — the `platforms` list in `Package.swift` includes `.macOS(.v14)` purely so this can be
verified without Xcode; `PhotosPicker`/`PhotosUI` (used by the post composer) is available on both
platforms at these versions, and small compatibility shims cover the few places SwiftUI itself
differs (`Support/PlatformCompat.swift`).

## Setup

1. **Clone the SDK as a sibling directory.** From the same parent directory that contains this
   monorepo (`mudbase-showcase-social/`):
   ```bash
   git clone https://github.com/mudbase/mudbase-sdk.git
   ```
   You should end up with:
   ```
   parent/
     mudbase-showcase-social/
       swift/            <- this package (Package.swift lives here)
       web/
       ...
     mudbase-sdk/
       swift/            <- the SDK package Package.swift references
       ...
   ```

2. **The SwiftPM identity-collision workaround symlink is already committed.** This app's own SPM
   package directory is named `swift` (see the monorepo layout above) and the SDK's own Swift
   subdirectory is *also* named `swift`. SwiftPM computes a local path dependency's package
   "identity" from the last path component of the path you give it, with no way to override that —
   so a plain `.package(path: "../../mudbase-sdk/swift")` would give this app's own package and its
   SDK dependency the *same* identity ("swift"), and dependency resolution would silently conflate
   them (`error: product 'MudbaseSDK' required by package 'swift' target 'MudbaseShowcaseSocial'
   not found in package 'MudbaseSDK'`). `mudbase-showcase-social/mudbase-sdk-swift` is a relative
   symlink (`-> ../mudbase-sdk/swift`) that already exists at this monorepo's root for exactly this
   reason — the same workaround the ecommerce Swift port established first (see that port's README
   "Setup" step 2 for the full writeup). `Package.swift` references `../mudbase-sdk-swift`, not
   `../../mudbase-sdk/swift`.

3. **Configure.** Copy `Config.example.plist` to `Config.plist` (same directory) — it already has
   this showcase's real, already-provisioned project and collection IDs filled in, so no values
   need to be looked up:
   ```bash
   cp Config.example.plist Config.plist
   ```
   | Key | Value |
   |---|---|
   | `MudbaseProjectId` | `6a6cf79dd07caabbbdfbe9c5` |
   | `MudbaseBaseURL` | `https://cloud.mudbase.dev` (default, rarely needs changing) |
   | `PostsCollectionId` | `6a6cf7d0d07caabbbdfbe9db` |
   | `CommentsCollectionId` | `6a6cf7d1d07caabbbdfbe9f1` |
   | `LikesCollectionId` | `6a6cf81ed07caabbbdfbea20` |
   | `FollowsCollectionId` | `6a6cf81ed07caabbbdfbea32` |

   None of these are secrets — a project/collection ID isn't sensitive (same rationale as
   `../web/.env.example`). `Config.plist` is still gitignored to keep this out of history as a
   matter of convention; there is no API key or other server-only credential in this app at all.
   `AppConfig.load` also reads `MUDBASE_PROJECT_ID` / `MUDBASE_POSTS_COLLECTION_ID` / etc.
   environment variables as a fallback, convenient for `swift run` during development; if neither
   source resolves every required key, the app renders a "Configuration required" screen instead of
   crashing (see `ConfigurationRequiredView.swift`).

4. **Open and run.**
   ```bash
   open Package.swift
   ```
   In Xcode: pick an iOS Simulator (or a physical device) as the run destination from the scheme
   selector, then Run. If you add `Config.plist` to the project navigator, make sure it's added to
   the `MudbaseShowcaseSocial` target's "Copy Bundle Resources" build phase (Xcode does this
   automatically when you drag the file in with "Add to target" checked).

## What's implemented

- **Auth** — email/password login and self-signup (always `customer`, this project's one role),
  plus an **anonymous guest session** so the feed is publicly browsable before signing in (see
  "Guest browsing" below — this is the one significant architectural difference from the
  ecommerce Swift port). Session bootstrap from Keychain on launch, sign-out. Token pair stored in
  the Keychain via `Support/KeychainTokenStore.swift` — never `UserDefaults`. A 401 from an
  expired access token is transparently refreshed and retried once, for *every* authenticated call
  in the app (reads under the guest session included, not just a signed-in customer's writes) —
  see `Networking/AccessTokenCoordinator.swift`.
- **Feed** — paginated post list ("Load more" on scroll), pull-to-refresh, a background poll for
  new posts every 8 seconds while the tab is on screen (see "Realtime" below), and the post
  composer (text + optional image).
- **Post composer** — a real `PhotosPicker` attempt to upload the picked image to this project's
  public bucket, with a graceful, honest fallback to a manual "Image URL" field if that 403s (the
  expected, documented outcome for this project's `customer` role — see "Known limitations").
- **Post detail** — full post, comments (oldest-first), a comment composer, a like toggle, and a
  follow toggle on the post's author.
- **Profile** — the Profile tab shows the signed-in user's own profile (resolved display name,
  follower/following/post counts, their posts, sign-out); tapping any author's name/avatar
  anywhere in the app pushes that same profile screen for them, with a follow/unfollow button
  (hidden on your own profile).
- **Auth-gated writes, public reads** — every collection read works under the anonymous guest
  session; posting, liking, commenting, and following are gated server-side by this project's own
  Mudbase collection permissions (verified live — see `plan/build-plan.md`), and this app's own
  `AppUser.isGuest` checks are UX routing (switch to the Profile tab's sign-in screen), not the
  security boundary.

## Guest browsing (the one architectural difference from the ecommerce Swift port)

The ecommerce Swift port's `SessionStore` requires a real signed-in user before the app shows
anything — that app's README explicitly calls this out as a deliberate simplification, since its
products collection requires `authenticated` (any logged-in role), not public read. This app's own
task brief requires "auth-gated writes / public reads," matching `../web/`'s actual behavior
(verified there live: every collection read 401s with zero auth at all — even the project's own
`pk_` publishable key — so an anonymous session is the only way a guest ever sees a feed).
`SessionStore.bootstrap()` here therefore falls back to `AuthenticationAPI.createAnonymousSession`
when there's no stored real session, and that guest session's token pair is persisted through the
exact same `KeychainTokenStore` + `AccessTokenCoordinator` machinery as a real one (confirmed in
the SDK: `CreateAnonymousSession200Response` carries its own `refreshToken`, so the 401-refresh-
retry policy applies identically to a guest's reads and a signed-in customer's writes). See
`plan/build-plan.md` "Deviations from the ecommerce Swift port" for the full reasoning.

## Architecture

```
Sources/MudbaseShowcaseSocial/
  App/            @main entry point
  Config/         AppConfig (Config.plist + env var loader)
  Support/        Keychain, API error mapping, platform shims, navigation reference types,
                  relative-time formatting, the shared SocialActionOutcome enum
  Networking/     Thin wrappers over the generated SDK's async calls (auth, generic collection CRUD)
  Models/         Post, Comment, AppUser — decoded from Mudbase JSON
  Services/       SessionStore, TabRouter (both @MainActor ObservableObject), PostsService,
                  CommentsService, LikesService, FollowsService, ImageUploadService
  ViewModels/     One @MainActor ObservableObject per screen
  Views/          SwiftUI views, grouped by feature area
```

`SessionStore` and `TabRouter` are the two app-wide stores (created once in the `App` struct and
injected via `.environmentObject`); every other view model is constructed explicitly by its owning
view (passed `config` and, where relevant, the current user) rather than reached for via
`@EnvironmentObject`, so each screen's real dependencies stay visible at its call site — same
convention the ecommerce Swift port uses.

## The Mudbase Swift SDK, exactly as generated

Every Mudbase call in this app goes through the real generated `MudbaseSDK` async/await methods —
none of the signatures below were guessed; each was read from
`../mudbase-sdk/swift/Sources/MudbaseSDK/APIs/*.swift` before being used:

- `AuthenticationAPI.createAnonymousSession`, `.loginLocalUser`, `.getLocalSession`,
  `.refreshToken`, `.logoutLocalUser`
- `MultiRoleFeatureAPI.registerWithRole(role:registerWithRoleRequest:)`
- `DataAPI.listData` / `.getData` / `.createData` / `.updateData` / `.deleteData`
- `BucketsAPI.listBuckets` / `FilesAPI.uploadFiles` (the post composer's image upload attempt)

`AuthGateway.currentUser()` reads `AuthenticationAPI.getLocalSession(projectId:)` rather than the
web app's own hand-rolled `client.getSession()` call (`GET /api/auth/session?projectId=`) —
deliberately: the generated SDK's equivalent of that exact URL, `getCurrentSession()`, takes no
`projectId` parameter at all and returns the org-level `User` model (`owner`/`admin`/`member`/
`viewer` roles only), which can never surface this project's `customer` custom role or an
anonymous session's `isAnonymous` flag. `getLocalSession` is the call that actually round-trips
this project's Multi-Role data — the same choice the ecommerce Swift port made, confirmed by
reading both API implementations side by side rather than assumed.

## Realtime

`../web/`'s `usePostsLive` subscribes to the `posts` collection's Socket.IO room for live
`db:create`/`db:update` events. There is no official Mudbase realtime client outside JavaScript,
and the sibling `go`/`python`/`ruby` ports of this same reference app already established the
precedent of substituting periodic polling rather than vendoring an unofficial, unaudited
Socket.IO Swift library as a new SwiftPM dependency. `FeedViewModel.pollLoop(currentUser:)`
re-fetches page 1 of the feed every 8 seconds while `FeedView` is on screen (a structured
`Task.sleep` loop inside a SwiftUI `.task`, automatically cancelled when the tab isn't visible) and
merges any post not already in the list in at the front, deduped by `_id` — the same
dedupe-by-id principle the web app's `prependPost`/`updatePostEverywhere` use via
`queryClient.setQueryData`.

## Verification

There is no iOS Simulator in this build environment, so verification is a headless Swift Testing
suite (`Tests/ManualLiveFlowTests/ManualLiveFlowTests.swift`) that exercises this app's own
`Services`/`Networking` layer — the exact types the SwiftUI views and view models call — directly
against the real, live `cloud.mudbase.dev` project, the same approach the ecommerce Swift port
uses. It's disabled by default (a plain `swift test` never makes network calls or writes real
documents); run it explicitly with:

```bash
RUN_LIVE_FLOW_TEST=1 swift test --filter ManualLiveFlowTests
```

It logs into both already-verified accounts supplied for this build
(`mudhaxk+mbsocial1@gmail.com` / `mudhaxk+mbsocial2@gmail.com`, password `SocialTest123!`),
confirms an anonymous session can read the feed but not create a post (403), has one account post
and the other comment/like/follow, verifies every counter and cross-account read reflects those
writes, forces a 401 to confirm the refresh-and-retry policy actually recovers a call rather than
just existing in code, then toggles the like/follow back off.

**Result:** `Test fullSocialFlow() passed after 13.939 seconds` — zero failures against the real,
live project. Full step-by-step results, and one real (non-bug) finding along the way — a
pre-existing `follows` row from the web app's own earlier live smoke test made the follow-toggle
step's "clean slate" assumption wrong, fixed by normalizing state before asserting — are in
`plan/build-plan.md` "Live verification results".

This project's `/api/auth/*` endpoints are rate-limited per IP (a real, shared budget across every
language port's own verification runs against this project), so `login` can occasionally `429`.
`ManualLiveFlowTests.resolveSession` accepts an optional pre-minted access/refresh token pair per
account via `AVA_ACCESS_TOKEN`/`AVA_REFRESH_TOKEN`/`BEN_ACCESS_TOKEN`/`BEN_REFRESH_TOKEN`
environment variables and uses those instead of calling `login` when they're set — the same
"fallback pre-minted tokens" contingency the task brief this app was built from anticipated:

```bash
RUN_LIVE_FLOW_TEST=1 \
AVA_ACCESS_TOKEN=... AVA_REFRESH_TOKEN=... \
BEN_ACCESS_TOKEN=... BEN_REFRESH_TOKEN=... \
swift test --filter ManualLiveFlowTests
```

## Known limitations (real platform/SDK constraints, not bugs)

- **Post images upload for real when the signed-in account's role permits it; this project's
  `customer` role does not.** `rbacCheck("file","create")` (bucket/file creation) only allows the
  org-level system roles owner/admin/developer — every project end-user, including a real,
  verified `customer`, is permanently system role `viewer`. Verified live on both this app and the
  ecommerce Swift port. The composer's `PhotosPicker` flow makes the real attempt anyway (see
  `ImageUploadService`) and falls back to a plain URL field on the expected 403, rather than
  skipping straight to the fallback.
- **No `users` collection** — every author/commenter/follower name in this data model is
  denormalized onto the row that references them. `FollowsService.resolvedDisplayName` ports
  `useResolvedDisplayName`'s exact fallback chain: most recent post's `authorName` → any
  `followingName` recorded by a follower → the literal string `"Member"`.
- **Likes/follows have no compound unique index** — `LikesService.toggle`/`FollowsService.toggle`
  use the same check-then-act guard (`GET` immediately before `POST`/`DELETE`) as the web app's
  `useToggleLike`/`useToggleFollow`. Reasonable, not airtight, protection against a double-tap
  race — matches the task's own framing of this as fine for a demo.
- **No email-verification deep-link screen.** This app has no associated-domain/universal-links
  configuration in scope for this build, so `RegisterView` shows the same "check your inbox, then
  sign in" message the web app shows immediately after registering, but there is no in-app way to
  complete that link — the user finishes verification in their email client, then returns to this
  app and signs in normally. This doesn't block the app's primary path (the two pre-verified
  accounts above), only fresh self-registration.
- **Certificate pinning and biometric auth are out of scope**, same call as the ecommerce Swift
  port's README for the same reason — a focused reimplementation, not a production hardening pass.
  Keychain-only token storage is implemented as a baseline correctness requirement.
- **The SwiftPM package-identity collision** described in "Setup" step 2 — a genuine SwiftPM
  constraint (identity = last path component, no override), not a bug in this app's manifest.
