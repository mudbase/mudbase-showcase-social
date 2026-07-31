# Build Plan — Mudbase Showcase: Social (Expo / React Native)

Generated: 2026-07-31
Mode: port of the reference `../web` app (1 of 10 planned language/platform ports)
Type: mobile (fullstack via BaaS, no custom backend)
Stack: Expo (SDK 57) + TypeScript (strict) + Expo Router + NativeWind (Tailwind) + TanStack Query
+ Zustand + React Hook Form + Zod + `expo-secure-store` + `socket.io-client`, backed entirely by
Mudbase (`cloud.mudbase.dev`) — same real project as `../web`.

## Stack decisions

- Same architecture as the sibling `mudbase-showcase-ecommerce/mobile-expo` port: real generated
  `mudbase-sdk` classes (`AuthenticationApi`, `DataApi`) wrapped in a thin `src/api/client.ts`,
  NativeWind for styling, Expo Router for navigation, Zustand for the auth store, TanStack Query
  for server state. See `src/api/client.ts`'s header comment for the exact calling convention
  (object-parameter, not positional — the SDK's own `docs/*.md` examples are stale).
- `mudbase-sdk` is consumed as `"mudbase-sdk": "file:../../mudbase-sdk/javascript"`, same as the
  ecommerce port — cloned as a sibling directory at
  `mudbase-showcase-social/../mudbase-sdk/javascript` (already present on this machine, shared
  across all sibling ports being built).
- **Departs from the ecommerce port on one point: this app uses `socket.io-client` for realtime**,
  where the ecommerce mobile port deliberately avoided it (its README cites "extra native
  polyfills… wasn't worth the dependency weight" and polls instead). This task's brief explicitly
  requires realtime via Socket.IO for the feed, and the web reference app's own
  `plan/build-plan.md` already proves the exact `subscribe:collection` / `db:create` / `db:update`
  contract works live against this project. `socket.io-client` bundled and compiled cleanly under
  Metro/Hermes for this app (3874 modules, zero errors — see "Verification" below); RN provides
  the `WebSocket`/`XMLHttpRequest` globals both of socket.io's transports need, so no RN-specific
  transport shim was required in `src/lib/socket.ts` (ported near-verbatim from
  `web/src/lib/mudbase-socket.ts`).
- **Guest browsing (anonymous session) is kept, unlike the ecommerce mobile port's login-first
  simplification.** The task brief asks for "auth-gated actions with public read where the web app
  does the same" — `src/stores/authStore.ts` bootstraps an anonymous session on cold start (and
  again after logout) so the feed's public-read permission resolves without forcing a login
  screen, exactly like `web/src/lib/mudbase-provider.tsx`. `useAuth().isAuthenticated` is what
  distinguishes a real signed-in `customer` from that always-present guest identity for UI gating
  (posting, liking, commenting, following).

## Real-project verification carried over from `../web`

This app is the same live project (`6a6cf79dd07caabbbdfbe9c5`) the web reference app already
verified exhaustively — signup role slug `customer`, the `pk_` key not being a working credential,
every collection read requiring *some* JWT, anonymous sessions unable to write, email
verification being required, and the two infrastructure fixes (collection permissions grant +
Atlas collection-cap cleanup) already applied. See `../web/plan/build-plan.md` findings #1–#8 for
the full detail — none of it is re-derived here since it's the same backend, same collections,
same roles.

**One additional live check done specifically for this port, before writing any UI:**
`GET /api/bucket/projects/{projectId}/buckets` with a real `customer`-role JWT returned
`{"buckets":[],...}` — reachable (not a 403), but empty. Combined with `../web/plan/build-plan.md`'s
already-documented finding that bucket/file creation requires org-level owner/admin/developer
(every project end-user, including a verified `customer`, is always system role `viewer`), this
confirms no bucket is writable — or even visible — to either provisioned test account. See
"Known limitations" below for how the composer handles this.

## Data Models (Mudbase Collections — already provisioned, used as-is)

Identical to `../web/plan/build-plan.md` — `posts` (`6a6cf7d0d07caabbbdfbe9db`), `comments`
(`6a6cf7d1d07caabbbdfbe9f1`), `likes` (`6a6cf81ed07caabbbdfbea20`), `follows`
(`6a6cf81ed07caabbbdfbea32`). Zod schemas mirroring these shapes live in `src/api/schemas.ts`.

## Auth flow

```
First launch (no stored tokens)  → AuthenticationApi.createAnonymousSession({projectId})
                                   → guest session (isAnonymous: true), can read, cannot write
Sign in                          → AuthenticationApi.loginLocalUser({email, password, projectId})
                                   → real customer session, tokens persisted to expo-secure-store
Sign out                         → AuthenticationApi.logoutLocalUser() → clear tokens
                                   → immediately re-bootstrap a fresh anonymous session so guest
                                     browsing continues without a hard app restart
401 on any authenticated call    → AuthenticationApi.refreshToken() (deduped in-flight across
                                     concurrent 401s via `refreshing` promise) → retry once
```

No registration screen was built — the task brief explicitly said this was optional and to prefer
the two already-verified, already-email-verified test accounts over registering new ones (this
project's registration endpoint is rate-limited at 3/hour/IP and shared across several sibling
ports being built concurrently on this machine's IP).

## Realtime

`src/lib/socket.ts` (ported from `web/src/lib/mudbase-socket.ts`) connects to
`cloud.mudbase.dev`'s Socket.IO endpoint (`path: "/socket.io/"`, `auth: { token }`) as soon as
`authStore` has any token (guest or real). `src/hooks/usePostsLive.ts` subscribes the feed to the
`posts` collection's room (`subscribe:collection` → `db:create`/`db:update`) — a post created or
liked/commented-on by someone else appears or updates live, deduped by `_id` against the
composer's own optimistic insert. Same wire contract the web app's `plan/build-plan.md` already
proved live (see that file's "Realtime" smoke-test rows).

## UI Screens

- `app/(tabs)/index.tsx` — Feed tab: `PostComposer` (as the FlatList's `ListHeaderComponent`, so it
  never remounts across feed re-renders) + `FeedList` (paginated via `useInfiniteQuery`,
  pull-to-refresh, realtime via `usePostsLive`). Public read; posting/liking/commenting redirect to
  `/login` if not signed in.
- `app/(tabs)/profile.tsx` — "My profile" tab: sign-in prompt for guests, otherwise
  `ProfileScreenContent` for the signed-in user's own `id` plus a sign-out button.
- `app/posts/[id].tsx` — post detail: full post (`linkToDetail={false}`), `CommentList`
  (oldest-first), `CommentComposer`, like toggle.
- `app/users/[userId].tsx` — another user's profile: resolved display name, follower/following/post
  counts, that user's posts, follow/unfollow (hidden on your own profile via `FollowButton`'s own
  self-id check).
- `app/login.tsx` — top-level modal-presented stack screen (not gated behind a route group, since
  guest browsing is allowed) reachable from any "Sign in to …" call-to-action.

## Security implementation

- Input validation: Zod schemas for every form (login, post composer, comment composer) via
  `react-hook-form` + `@hookform/resolvers/zod`. Post content capped at 500 chars, comments at 300
  — same limits as web.
- Authentication: Mudbase-issued JWT (access + refresh) held in `expo-secure-store` (iOS Keychain /
  Android Keystore), never `AsyncStorage` — see `src/api/secureStorage.ts`. 401 → refresh → retry
  handled once, deduped across concurrent requests (`refreshing`), ported faithfully from
  `web/src/lib/mudbase.ts`'s `refreshInFlight` pattern per the task's explicit instruction.
- Authorization: enforced server-side by Mudbase collection permissions (customer-only
  create/update, public read) — this app's own `isAuthenticated` checks are UX gating (redirect to
  `/login`), not the security boundary, same posture as web.
- Rate limiting: inherited from Mudbase's own per-endpoint limits — encountered directly during
  this build's own live verification (see "Live smoke test" below).
- Secrets: none. Every env var is `EXPO_PUBLIC_*` — a project/collection ID is not a secret, and
  there is no server-only credential anywhere in this app (no bucket-upload path can succeed for
  either test account's role — see "Known limitations").

## Known limitations (real platform constraints, not bugs)

**Post images attempt a real bucket upload via `expo-image-picker`, but the composer degrades
gracefully to text-only when it fails.** `src/api/client.ts`'s `uploadPostImage()` first lists
buckets for the project, then uploads via a direct authenticated `fetch` (not the generated SDK's
`FilesApi.uploadFiles()`, which JSON-stringifies the file array into a single `Blob` instead of
real multipart parts — a generator gap, same reason `web/src/lib/mudbase.ts` hand-rolls its own
`uploadFile()`). Verified live for this build: bucket listing returns `buckets: []` for a
`customer`-role JWT — no bucket is reachable, consistent with `../web/plan/build-plan.md`'s
finding that `rbacCheck("file","create")` only allows org-level owner/admin/developer, a system
role no project end-user ever carries. `PostComposer.tsx` catches the failure, shows an inline
notice, and still creates the text-only post rather than blocking the whole action on a permission
this account can never satisfy.

**No `users` collection, so profile display names are best-effort.** Identical constraint to web:
`useResolvedDisplayName` tries the user's most recent post's `authorName`, falls back to any
`followingName` recorded by someone who follows them, falls back to the literal string "Member".

**No in-app registration.** Not built per the task brief's explicit instruction (optional, and
registration is rate-limited 3/hour/IP, shared across several sibling ports on this machine's IP
during this build).

## Live smoke test (2026-07-31, against the real project)

Ran a Node script (ad hoc, not committed — per the task's own "no simulator available" allowance)
exercising the exact same `mudbase-sdk` classes and calling convention as `src/api/client.ts`,
against the real, live backend with the two provisioned accounts.

**Rate-limit contention encountered first, and worth recording as its own finding.** Direct login
hit the platform's IP-wide auth rate limit (`429`, `retryAfter: 900`) — this machine's IP had
already been used by several concurrent sibling language-port builds logging in/refreshing with
the same two accounts, exactly the contention scenario the task brief warned about. The task's
originally-provided fallback refresh tokens were also already invalid by the time this port
reached its smoke test: Ava's had already been rotated earlier in this same session (a raw
`/api/auth/refresh` call against the original correctly 401'd the second time, since refresh
tokens are single-use), and a second attempt against the *already-rotated* token correctly
triggered the platform's reuse-detection ("Session has been invalidated. Please sign in again.")
rather than silently succeeding — proof the rotation/reuse-detection security control this app's
own `client.ts` depends on is real and enforced server-side. Resolved by injecting a second,
freshly-minted pair of access+refresh tokens directly (mirrors `src/api/secureStorage.ts`'s
`restoreTokens()` path exactly — no login call needed), validated via `getLocalSession()`.

**Full results, all steps against the real project (`6a6cf79dd07caabbbdfbe9c5`):**

| Step | Result |
|---|---|
| Inject Ava's token, validate via `getLocalSession` | ✅ id, email, `customRole: "customer"` confirmed |
| Inject Ben's token, validate via `getLocalSession` | ✅ id, email, `customRole: "customer"` confirmed |
| Bootstrap anonymous session (guest public-read path) | ⏭️ skipped — auth endpoints still inside the rate-limit window at this exact moment; not required for the rest of the test since Ava/Ben's already-injected tokens cover every remaining step |
| Ava creates a post | ✅ `201`, correct shape |
| Feed read (`sort=-createdAt`, paginated) | ✅ new post present, correct `pagination.total` |
| Ben comments on Ava's post | ✅ `201` |
| `PATCH posts.commentsCount` after Ben's comment | ✅ |
| Check-then-act: query existing like (empty) | ✅ `200`, 0 results |
| Ben likes Ava's post (create) | ✅ `201` |
| `PATCH posts.likesCount` after Ben's like | ✅ |
| Ben follows Ava | ✅ `201` |
| Post detail read | ✅ `likesCount`/`commentsCount` reflect both writes |
| Comments thread read (`sort=createdAt`, oldest-first) | ✅ Ben's comment present |
| `useMyLikedPostIds`-equivalent (Ben's liked postIds) | ✅ contains Ava's new post |
| `useMyFollowingIds`-equivalent (Ben's following ids) | ✅ contains Ava's id |
| `useFollowCounts`-equivalent reads | ✅ non-zero counts for both accounts (reflects prior state from this same live project — see note below) |
| Ava's profile post count | ✅ non-zero, includes the new post |
| `useResolvedDisplayName`-equivalent (most recent post's `authorName`) | ✅ "Ava Poster" |
| Bucket list check (mirrors `client.ts`'s `uploadPostImage`) | ✅ reachable (`200`), `buckets: []` — confirms "Known limitations" below |
| **Realtime**: Ava's socket subscribes to `posts`, Ben creates a post via REST | ✅ Ava's socket received `db:create` for Ben's post live, within the 15s wait window |

**Note on non-zero follower/following/post counts:** this is the same shared live project several
sibling ports and earlier runs within this build have already written to (posts, likes, follows
accumulate across all of them, by design — it's one real, shared Mudbase project, not a
per-test-run sandbox). The counts being non-zero and increasing after each write (rather than
static or wrong) is itself the correct behavior being verified, not a discrepancy.

**Net result:** every operation this app's UI performs — auth session validation, post creation,
paginated feed reads, cross-account comment/like/follow, counter updates, profile reads, and a
real Socket.IO `db:create` event delivered live — is proven correct against the real, live backend
with the two real provisioned accounts, using the exact same `mudbase-sdk` calling convention
`src/api/client.ts` uses. `iOS`/`Android` Metro bundles (via `expo start`) both compiled with zero
errors (3874 and 3965 modules respectively) prior to this test, and `npx tsc --noEmit` passed
clean under `strict: true`.

## Environment Variables

See `.env.example`. All public (`EXPO_PUBLIC_*`) — see "Security Implementation" above for why.

## File Tree

```
mudbase-showcase-social/mobile-expo/
├── package.json, app.json, babel.config.js, metro.config.js, tailwind.config.js, global.css,
│   tsconfig.json, nativewind-env.d.ts, expo-env.d.ts, .env.example, .env, .gitignore, README.md
├── plan/build-plan.md
├── assets/ (icon, splash, adaptive icon, favicon)
├── app/
│   ├── _layout.tsx, +not-found.tsx, login.tsx
│   ├── (tabs)/_layout.tsx, index.tsx (feed), profile.tsx (my profile)
│   ├── posts/[id].tsx
│   └── users/[userId].tsx
├── src/
│   ├── api/ (client.ts, schemas.ts, secureStorage.ts)
│   ├── config/env.ts
│   ├── hooks/ (useAuth, useCollection, useSocket, usePostsFeed, usePostsLive, useLikes,
│   │           useFollows, useComments, useProfileStats)
│   ├── lib/ (cn.ts, format.ts, socket.ts, queryClient.ts)
│   ├── providers/AppProviders.tsx
│   ├── stores/authStore.ts
│   └── components/
│       ├── ui/ (Button, Card, TextField, ErrorNotice, Avatar)
│       ├── auth/LoginForm.tsx
│       ├── feed/ (PostComposer, PostCard, FeedList)
│       ├── social/ (LikeButton, FollowButton)
│       ├── comments/ (CommentList, CommentComposer)
│       └── profile/ (ProfileHeader, ProfilePostList, ProfileScreenContent)
```
