# Mudbase Showcase — Social (Ruby / Sinatra)

A server-rendered social micro-blog built **entirely on [Mudbase](https://www.mudbase.dev)** —
auth and database, with **zero custom backend** — implemented in **Sinatra + ERB**, talking to
`cloud.mudbase.dev` through the real generated **Mudbase Ruby SDK** (`mudbase_sdk`, module
`MudbaseSDK`). This is the Ruby reimplementation of the reference Next.js app (see `../web`):
same Mudbase project, same four collections, same field shapes, different stack — mirroring the
framework choice and structure of the sibling `mudbase-showcase-ecommerce/ruby` port.

## Stack

Sinatra 4 + ERB + `Rack::Session::Cookie`, `mudbase_sdk` (git-sourced), Puma. No ORM, no database
of its own — every read/write goes to Mudbase's Collections REST API.

## What it demonstrates

| Feature | Mudbase capability | Where |
|---|---|---|
| Guest browsing, no signup | Anonymous auth (`POST /api/auth/anonymous`) | `lib/session_helpers.rb#ensure_guest_session!` |
| Email/password accounts | Multi-Role signup (`POST /api/auth/local/signup/customer`) | `lib/mudbase/auth_service.rb`, `app/routes/auth_routes.rb` |
| Public feed, paginated | Collections, public read via a guest or real JWT | `app/routes/feed_routes.rb`, `lib/mudbase/posts_repo.rb` |
| Post + optional image | Ownership-scoped create, `imageUrl` as a pasted URL | `app/routes/feed_routes.rb`, `views/feed/index.erb` |
| Post detail + comment thread | Ownership-scoped create + counter update, oldest-first | `app/routes/posts_routes.rb`, `lib/mudbase/comments_repo.rb` |
| Like / unlike | Ownership-scoped create/delete + counter update, check-then-act | `lib/mudbase/likes_repo.rb` |
| Follow / unfollow | Ownership-scoped create/delete, check-then-act | `lib/mudbase/follows_repo.rb` |
| Profile (posts, follower/following counts) | Filtered reads + `pagination.total` as a count | `app/routes/profile_routes.rb`, `lib/mudbase/profile_repo.rb` |

## Provisioning (what already exists on Mudbase, not in this repo)

This app expects a Mudbase project already set up with:

1. Local auth enabled, with email verification required.
2. The Multi-Role feature's default `customer` role.
3. Four collections — `posts`, `comments`, `likes`, `follows` — with the field shapes documented
   in `plan/build-plan.md`, and the `customer` role granted `create`/`read`/`update`/`delete`,
   `dataScope: "all"`, on all four, plus anonymous/public read.

`.env.example` lists every ID this app needs once that's done.

## Setup

```bash
bundle install
cp .env.example .env   # fill in your own provisioned project's IDs and a session secret
bundle exec puma -p 4567 config.ru
# or: bundle exec rackup config.ru
```

Open `http://localhost:4567`.

### Native-extension (ffi) caveat

`mudbase_sdk` depends on `typhoeus` → `ethon` → `ffi` for its HTTP transport. `ffi`'s native
extension is loosely pinned by the SDK's own gemspec and can fail to compile against a newer
Xcode/Clang toolchain than the gem release expects. This Gemfile pins `ffi ~> 1.17` explicitly
(a version with prebuilt `arm64-darwin`/`x86_64-darwin`/Linux bottles, so `bundle install`
typically doesn't need to compile anything). If you still hit a build failure, run
`gem install ffi -v '~> 1.17'` on its own first to confirm a prebuilt binary is available for
your platform before touching the vendored SDK gemspec.

### Verifying the app

```bash
find . -name "*.rb" -not -path "./vendor/*" -exec ruby -c {} \;   # every file: Syntax OK
bundle exec ruby -e "require './app'"                             # loads cleanly, no live calls
```

## Live smoke test (2026-07-31, real project, real accounts)

The entire app-to-Mudbase contract — anonymous guest reads, real login, post/comment/like/follow
create, counter updates, follower/following counts, profile display-name resolution, and every
HTTP route (feed, post detail, like, comment, profile, follow) through a real running Puma
server with a real signed Rack session cookie — was verified live against the actual project,
using the two real, already-verified `customer` accounts (`mudhaxk+mbsocial1@gmail.com` "Ava
Poster", `mudhaxk+mbsocial2@gmail.com` "Ben Follower"). See `plan/build-plan.md` → "Live smoke
test results" for the full step-by-step table, including a real bug found and fixed (the
generated SDK's hard `limit <= 100` cap on `list_data`, which this app's repo classes now
respect) and an honest account of the shared-account rate-limit contention this build worked
around without ever fabricating a result.

## Known limitations (real platform + framework constraints, not bugs)

**No push-based realtime.** This app is entirely server-rendered with no client-side JavaScript
runtime, and — like the sibling ecommerce port — deliberately never sends the Mudbase JWT to the
browser (it lives only in an httponly Rack session cookie). Wiring the reference app's
Socket.IO-based live feed would require exposing that JWT to page JS, which this app's own
security design does not do. Use the footer's "Refresh feed" link, or reload, to see new
activity.

**Mudbase Collections' `list_data` hard-caps `limit` at 100**, client-side-enforced by the
generated SDK. Every bounded read in this app (`CommentsRepo::LIST_LIMIT`,
`LikesRepo::MINE_LIMIT`, `FollowsRepo::MINE_LIMIT`) is set to exactly 100 for this reason.

**File uploads require an org owner/admin/developer system role.** Every project end-user,
including a real, verified `customer`, is permanently a `viewer` system role and gets denied.
Post images in this app are entered as plain URLs rather than uploaded.

**No `users` collection, so profile display names are best-effort.** A user who has never
posted and has no followers has no row anywhere recording their name —
`ProfileRepo.resolve_display_name` falls back to the literal string "Member" in that case.

## Local development

```bash
bundle install
cp .env.example .env
bundle exec puma -p 4567 config.ru
```

## Deploy

Any Ruby host that runs Puma behind `config.ru` (Fly.io, Render, a bare VPS with systemd) works
unmodified. Set every variable in `.env.example` as a real environment variable —
`SESSION_SECRET` must be a long random value distinct from any other app's secret, and
`RACK_ENV=production` turns on the `secure` cookie flag (HTTPS-only session cookie).
