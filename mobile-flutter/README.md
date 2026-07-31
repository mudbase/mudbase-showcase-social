# Mudbase Showcase — Social (Flutter)

A Flutter reimplementation of the [Mudbase Showcase social micro-blog](../web) — realtime feed,
likes, comments, and follows — talking directly to `cloud.mudbase.dev` through the real, generated
**Mudbase Dart SDK** (`mudbase_sdk`, [github.com/mudbase/mudbase-sdk](https://github.com/mudbase/mudbase-sdk),
`dart/` subdirectory), with **zero custom backend**.

## Stack

Flutter + Dart, Riverpod (`flutter_riverpod`, no code generation) for state, go_router for
navigation, `flutter_secure_storage` for the auth token, `socket_io_client` for the realtime feed.
See "Architecture decisions" below for why plain Riverpod rather than the `riverpod_generator`/
`freezed` combo this project's `flutter/SKILL.md` otherwise defaults to.

## Setup

The Mudbase Dart SDK is **not published to pub.dev** — `pubspec.yaml` references it as a relative
path dependency assuming a sibling-clone layout:

```yaml
mudbase_sdk:
  path: ../../mudbase-sdk/dart
```

`mobile-flutter/` sits one level inside the `mudbase-showcase-social` repo, so reaching a flat
sibling of that repo takes exactly two `../` segments (`mobile-flutter/` → `mudbase-showcase-social/`
→ parent → `mudbase-sdk/dart`).

Before anything else, clone `mudbase-sdk` as a sibling of `mudbase-showcase-social` itself (same
parent directory):

```bash
# from the directory that contains mudbase-showcase-social/
git clone https://github.com/mudbase/mudbase-sdk.git
```

So the layout looks like:

```
some-parent-dir/
├── mudbase-sdk/
│   └── dart/                  ← the SDK pubspec.yaml lives here
└── mudbase-showcase-social/
    └── mobile-flutter/        ← this app
```

Then:

```bash
cd mobile-flutter

# First time only (or after upgrading Flutter) - generates/refreshes the
# android/, ios/, etc. platform folders. Safe to re-run; it only fills in
# missing platform scaffolding, it does not touch lib/ or pubspec.yaml.
flutter create .

flutter pub get

cp dart_define.example.json dart_define.json
# dart_define.example.json already contains this showcase's real,
# already-provisioned project/collection IDs (they're public, not secrets -
# see "Security" below) - override only if pointing at your own project.

flutter run --dart-define-from-file=dart_define.json
```

### Config (`--dart-define-from-file`, this project's Flutter convention)

Never a runtime `.env` file — every value is read via `String.fromEnvironment` in
`lib/config/env_config.dart`. `dart_define.example.json` documents every key:

| Key | Required | Notes |
|---|---|---|
| `MUDBASE_PROJECT_ID` | yes | Not a secret - same as the web app's `NEXT_PUBLIC_MUDBASE_PROJECT_ID`. |
| `POSTS_COLLECTION_ID` | yes | |
| `COMMENTS_COLLECTION_ID` | yes | |
| `LIKES_COLLECTION_ID` | yes | |
| `FOLLOWS_COLLECTION_ID` | yes | |
| `MUDBASE_BASE_URL` | no (defaults to `https://cloud.mudbase.dev`) | |

`main()` calls `EnvConfig.assertConfigured()` before `runApp` and fails fast with a clear message
if any required key is missing, rather than surfacing a confusing 404/401 on the first screen that
reads an empty collection ID.

There is **no secret of any kind in this app** — every value above is safe to ship in a mobile
bundle (see "Security" below).

## What it demonstrates

| Feature | Mudbase capability | Where |
|---|---|---|
| Email/password accounts, always `customer` | Multi-Role signup, `POST /api/auth/local/signup/customer` | `lib/features/auth/`, `lib/core/auth_service.dart` |
| Email verification gate | `EMAIL_VERIFICATION_REQUIRED`, `RegisterScreen`'s "check your inbox" state | `lib/features/auth/register_screen.dart` |
| Paginated feed | Collections read, server-side `page`/`limit`/`sort` + `pagination.hasMore` | `lib/features/feed/`, `posts` collection |
| **Realtime feed updates** | Socket.IO `subscribe:collection` + `db:create`/`db:update` | `lib/core/mudbase_socket_service.dart`, `lib/features/feed/feed_controller.dart` |
| Post + optional image | Ownership-scoped create, `imageUrl` as a pasted URL | `lib/features/feed/widgets/post_composer_sheet.dart` |
| Like / unlike | Ownership-scoped create/delete + counter `PATCH`, check-then-act | `lib/data/repositories/like_repository.dart` |
| Comment thread | Ownership-scoped create + counter `PATCH`, oldest-first | `lib/data/repositories/comment_repository.dart` |
| Follow / unfollow | Ownership-scoped create/delete, check-then-act | `lib/data/repositories/follow_repository.dart` |
| Profile (posts, follower/following counts) | Filtered reads + `pagination.total` as a count | `lib/features/profile/` |

## Auth flow (a deliberate simplification vs. the web app)

The web app supports anonymous guest browsing that lets anyone read the feed before signing up.
This mobile app requires sign-in (login or register) before browsing at all — the task brief
explicitly allowed either approach, and installing a mobile app is already a bigger commitment than
opening a web page, so the anonymous-guest flow's main value (browse-before-committing) is weaker
here. This also means there is no "silent anonymous session" dance to port.

Self-signup is always the `customer` role — there is only one application role in this app (see
`plan/build-plan.md`).

## Realtime

`FeedScreen`'s `FeedController` subscribes to the `posts` collection's Socket.IO room on load:
`MudbaseSocketService.connect(token)` → `subscribe:collection {projectId, collectionId}` →
`db:create` (prepend, deduped by `id` against the composer's own insert of the same post) /
`db:update` (patch whichever cached copy exists). Same contract as the web app's
`usePostsLive`/`mudbase-socket.ts`, ported to Dart via `socket_io_client`. **Confirmed live** during
this build: a second account creating a post over plain REST arrived over the first account's
socket connection as a `db:create` event within under a second (see `plan/build-plan.md`).

Unlike the sibling ecommerce Flutter port (which explicitly opted out of realtime), this app
implements it because its own brief calls for a live feed.

## Live smoke test (2026-07-31, real project, this build)

The entire app-to-Mudbase contract is confirmed working end-to-end against the live backend with
the two provided test accounts (`mudhaxk+mbsocial1@gmail.com` "Ava Poster",
`mudhaxk+mbsocial2@gmail.com` "Ben Follower") — **twice**: once with plain `curl` (plus a Node.js
`socket.io-client` probe for realtime) to pin down the exact contract before any Dart was written,
and again by actually running `tool/manual_test.dart` (`dart run`, no Flutter SDK required) through
this app's own `AuthService`/`MudbaseDataService`/repository code. See `plan/build-plan.md` → "Live
Smoke Test Results" and "Testing Note" for the full step-by-step tables, exact outcomes, and an
honest accounting of the handful of expected non-passes (auth-endpoint rate limiting from repeated
test runs, and a check-then-act follow toggle correctly unfollowing because a prior test run had
already left the two accounts following each other) — none of them are app bugs.

## Known limitations (real platform constraints, verified live, not bugs)

**Post images are a pasted URL, not a file upload.** Confirmed live this build:
`GET /api/bucket/projects/{id}/buckets` returns `buckets: []` (no bucket provisioned), and
independently, `rbacCheck("file","create")` (both bucket creation and file upload) only allows the
org-level system roles owner/admin/developer — every project end-user, including a real verified
`customer` account, always carries system role `viewer` and can never pass that check. The composer
uses a plain `imageUrl` text field instead of a picker — same real constraint the ecommerce showcase
documents for product images.

**No `users` collection, so profile display names are best-effort.** Every author/commenter/
follower name in this data model is denormalized onto the row that references them (`authorName`,
`followingName`) rather than looked up from a central users table — there isn't one.
`ProfileController._resolveDisplayName` best-efforts a name from that user's most recent post,
falling back to any `followingName` recorded by someone who follows them, falling back to the
literal string "Member" if neither exists yet.

**No in-app email-verification resend or deep-link completion.** The resend endpoint requires a
valid JWT, which an unverified account cannot obtain (login is blocked until verified) — there is
no accessible path around this from a project end-user's own permissions, and this pass doesn't
implement a deep-link handler for the emailed verification link either (it completes in whatever
app opens that link, same as it would on the web).

**Like/follow uniqueness is check-then-act, not a compound unique index** (this collection type has
no compound unique index) — reasonable for a demo, not airtight. A real duplicate follow row from
an earlier concurrent test session was observed live during this build's own verification, which is
direct evidence the caveat is real, not theoretical (see `plan/build-plan.md`).

## Architecture decisions

- **Riverpod without code generation.** `flutter/SKILL.md`'s default stack uses
  `riverpod_generator` + `freezed` + `build_runner`. This app uses plain `Notifier`/`AsyncNotifier`
  classes and hand-written model classes instead, for the same reason as the sibling ecommerce
  port: this environment has no Flutter SDK installed to iteratively verify `build_runner` output
  locally — every provider and model here is verifiable by `dart analyze` alone (and, for the
  Flutter-free layer, actually was — see `plan/build-plan.md` "Testing Note").
- **Realtime via `socket_io_client`, confirmed against the real package source.** Since this
  environment can't run `flutter pub get`, the exact API shape of `Socket.on`/`off`/`onConnect`/
  `OptionBuilder` was confirmed by fetching the real, pub-cache-resolved package source (version
  2.0.3+1, matching `pubspec.yaml`) rather than guessed from memory or documentation alone.
- **A shared `LikedPostIdsController`** (not a plain query) backs every `LikeButton` across the
  feed, post-detail, and profile screens with one fetch, and exposes `markLiked()` so a toggle
  anywhere in the app updates every other screen's cache immediately instead of forcing a
  re-fetch — mirrors the web app's `useMyLikedPostIds`, adapted for Riverpod's imperative-update
  model.

## Testing

`test/models/` and `test/core/formatters_test.dart` + `test/core/mudbase_exception_test.dart` use
plain `package:test` (not `flutter_test`) specifically so they run with **plain `dart test`,
independent of the Flutter SDK** — and they were: **25/25 passed** in this build (see
`plan/build-plan.md` "Testing Note" for exactly how, since this project's own `pubspec.yaml` can't
`pub get` without Flutter installed either).

`test/features/auth_controller_test.dart` uses `flutter_test`/`ProviderContainer` with a fake
`AuthService`/`SecureTokenStorage`/`MudbaseSocketService` to exercise
`AuthController.callAuthorized`'s 401-refresh-retry path (including concurrent-refresh dedupe and
session teardown on a rejected refresh) without waiting for a real token to expire — mirrors the
ecommerce port's own test exactly, plus asserts the realtime socket connects/disconnects alongside
the session. This one genuinely needs the Flutter SDK and was not executed in this build environment
(same constraint documented throughout).

```bash
dart test test/models test/core   # runs today, no Flutter SDK needed
flutter test                      # runs test/features/ too, once Flutter is installed
```

`tool/manual_test.dart` is a standalone live smoke-test script against the real project — see
"Live smoke test" above; it was executed for real during this build via a scratch-package technique
documented in `plan/build-plan.md`, and will run directly with `dart run` (or `flutter pub get`
first) once Flutter is installed in a given environment.

## Verification

```bash
dart format --set-exit-if-changed .
dart analyze     # requires `flutter pub get` first once Flutter is installed
flutter test
```
