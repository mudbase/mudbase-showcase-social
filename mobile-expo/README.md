# Mudbase Showcase — Social (Expo / React Native)

The same realtime social micro-blog as [`../web`](../web), reimplemented for mobile against the
real [`mudbase-sdk`](https://github.com/mudbase/mudbase-sdk) JavaScript/TypeScript client — auth,
feed, likes, comments, follows, and live realtime updates, all backed by the real Mudbase project
`../web` already uses, with **zero custom backend**.

Stack: Expo (SDK 57) + TypeScript (strict) + Expo Router + NativeWind (Tailwind) + TanStack Query
+ Zustand + React Hook Form + Zod + `expo-secure-store` + `socket.io-client` + `expo-image-picker`.

## Prerequisite: clone the SDK as a sibling directory

The real `mudbase-sdk` has **not** been published to the npm registry — this app depends on it as
a local `file:` path, which means it must exist on disk at a predictable relative location before
`npm install` will succeed.

Clone it **next to** this repo (`mudbase-showcase-social`), at the same parent directory level —
not inside it:

```
some-parent-directory/
├── mudbase-showcase-social/        ← this repo (you already have it)
│   └── mobile-expo/                ← you are here
│       └── package.json            ← "mudbase-sdk": "file:../../mudbase-sdk/javascript"
└── mudbase-sdk/                    ← clone this as a sibling
    └── javascript/
```

```bash
# from some-parent-directory/, i.e. one level above mudbase-showcase-social/
git clone https://github.com/mudbase/mudbase-sdk.git

# the SDK ships as TypeScript source with no committed dist/ — build it once
cd mudbase-sdk/javascript
npm install   # runs its own "prepare" script (tsc), producing dist/
```

## Setup

```bash
cd mobile-expo
npm install
cp .env.example .env
# fill in your own provisioned Mudbase project's IDs — see ../web/plan/build-plan.md for the
# exact posts/comments/likes/follows collection field & permission shapes
npm run start
```

Then press `i` (iOS simulator), `a` (Android emulator), or scan the QR code with Expo Go / a
development build on a physical device.

## What's implemented

| Feature | Screen(s) | Notes |
|---|---|---|
| Guest browsing, no signup required | `app/(tabs)/index.tsx` | Bootstraps an anonymous session on cold start so the feed's public-read permission resolves — same as web. |
| Sign in (customer accounts) / sign out | `app/login.tsx`, `app/(tabs)/profile.tsx` | No registration UI — optional per the build brief; use an already-verified account. |
| Feed: paginated posts, pull-to-refresh, realtime | `app/(tabs)/index.tsx`, `src/components/feed/FeedList.tsx` | `useInfiniteQuery` + `FlatList` pagination; `usePostsLive` subscribes to the `posts` collection's Socket.IO room for live `db:create`/`db:update`. |
| Post composer: text + optional image | `src/components/feed/PostComposer.tsx` | `expo-image-picker` → attempted real bucket upload; degrades to text-only with an inline notice if the account's role can't reach a bucket (see "Known limitations"). |
| Post detail: comments thread + composer + like toggle | `app/posts/[id].tsx` | Comments sorted oldest-first, matching a normal thread. |
| Profile: own posts, follower/following counts, follow/unfollow | `app/(tabs)/profile.tsx`, `app/users/[userId].tsx` | Shared `ProfileScreenContent`; follow button hides itself on your own profile. |
| Auth-gated actions, public read | throughout | Posting/liking/commenting/following redirect to `/login` when not signed in; reading never requires it. |

## Live smoke test (2026-07-31, real project, two real accounts)

Fully verified end-to-end against the live backend (`6a6cf79dd07caabbbdfbe9c5`): session
validation, post creation, paginated feed reads, cross-account comment/like/follow, counter
updates, profile reads, the documented bucket-upload constraint, and a real Socket.IO `db:create`
event delivered live from one account's write to the other's open subscription. Along the way this
build also hit — and worked through — the platform's IP-wide auth rate limit from several sibling
language ports being built concurrently on the same machine, and independently confirmed the
platform's refresh-token reuse-detection response (proof the security control `src/api/client.ts`
depends on is real, not just a client-side assumption). See `plan/build-plan.md` → "Live smoke
test" for the full step-by-step results table.

## Deviations from the web reference app

**Realtime uses `socket.io-client` directly (kept, not dropped).** The sibling
`mudbase-showcase-ecommerce/mobile-expo` port avoided this dependency on mobile and polled
instead. This app's task brief explicitly required Socket.IO realtime for the feed, and
`socket.io-client` bundled and compiled cleanly under Metro/Hermes for this app with no RN-specific
transport shim needed (React Native provides the `WebSocket`/`XMLHttpRequest` globals both of its
transports use) — see `src/lib/socket.ts`, ported near-verbatim from
`web/src/lib/mudbase-socket.ts`.

**Guest anonymous browsing is kept (not simplified away).** Unlike the ecommerce mobile port's
login-first design, this app bootstraps an anonymous session so "public read" actually behaves
like the web app's, per this task's explicit instruction.

**No registration screen.** Optional per the task brief; the two provided, already-verified test
accounts are used directly via plain login instead, to avoid contending with this project's
3/hour/IP registration limit alongside several sibling ports being built on the same machine.

## Known limitations (real Mudbase platform constraints, verified live — same as web)

**Post images attempt a real upload, but gracefully degrade.** `rbacCheck("file","create")` (both
bucket listing-with-intent-to-upload and file upload) only allows the org-level system roles
owner/admin/developer — every project end-user, including a real, verified `customer` account,
always carries system role `viewer`. A live check against this exact project during this build
returned `buckets: []` for a customer-role JWT (reachable, not 403 — just empty), consistent with
that constraint. `src/api/client.ts`'s `uploadPostImage()` is fully implemented (not a stub) via a
direct authenticated `fetch` with a real RN multipart body — the generated SDK's own
`FilesApi.uploadFiles()` JSON-stringifies the file array into a single `Blob` rather than real
multipart parts, a generator gap, the same reason `web/src/lib/mudbase.ts` hand-rolls its own
upload method instead of using a generated one. `PostComposer.tsx` catches the expected failure and
still creates the text-only post.

**No `users` collection, so profile display names are best-effort.** Identical to web:
`useResolvedDisplayName` tries the most recent post's `authorName`, then any `followingName`
recorded by a follower, then falls back to "Member".

**Access tokens are short-lived (~30 min); refresh tokens are single-use.** `src/api/client.ts`
retries exactly once on a `401` via `refreshToken()`, deduping concurrent 401s behind one in-flight
refresh promise — ported faithfully from `web/src/lib/mudbase.ts`'s `refreshInFlight` pattern.
Verified live during this build's own smoke test, including the reuse-detection edge: replaying an
already-rotated refresh token correctly returns "Session has been invalidated. Please sign in
again." rather than silently succeeding.

**`expo-secure-store` has no real web fallback.** Its `ExpoSecureStore.web.ts` module ships every
method as `undefined`, not a `localStorage` shim — `src/api/secureStorage.ts` routes to
`window.localStorage` on `Platform.OS === "web"` instead, purely as a local QA fallback (never a
production path — no OS keychain exists in a browser).

## Local development

```bash
npm install
npx tsc --noEmit      # type-check (strict, clean)
npx expo-doctor       # environment / dependency health check
npm run start
```

## Deploy / distribute

Not deployed anywhere by default — this is a client app. Build with
[EAS Build](https://docs.expo.dev/build/introduction/) once you have your own Apple/Google
developer accounts and have set the `EXPO_PUBLIC_*` env vars in your EAS build profile, matching
`.env.example`.
