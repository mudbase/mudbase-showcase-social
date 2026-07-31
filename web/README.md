# Mudbase Showcase — Social (web)

A realtime social micro-blog built **entirely on [Mudbase](https://www.mudbase.dev)** — auth,
database, and realtime — with **zero custom backend**. This is the reference implementation for
this showcase: the other 9 language/platform ports (see the repo root README) are built to match
this app's data model and API contract.

## Stack

Next.js 15 (App Router) + TypeScript (strict) + Tailwind + shadcn/ui + TanStack Query, talking
directly to `cloud.mudbase.dev` from the browser. There is no server-side code in this app at
all — no Route Handlers, no server actions that call Mudbase with a privileged credential. Every
request (including file-adjacent ones, see "Known limitations") is made with the signed-in user's
own JWT.

## What it demonstrates

| Feature | Mudbase capability | Where |
|---|---|---|
| Guest browsing with no signup | Anonymous auth (`POST /api/auth/anonymous`) | `src/lib/mudbase-provider.tsx` |
| Email/password accounts | Multi-Role signup (`POST /api/auth/local/signup/customer`) | `src/hooks/useAuth.ts` |
| Email verification gate | `POST /api/users/verify-email`, `EMAIL_VERIFICATION_REQUIRED` | `src/app/verify-email/page.tsx` |
| Public feed, paginated | Collections, public read (`GET .../data?page=&limit=`) | `src/hooks/usePostsFeed.ts` |
| Realtime feed updates | Socket.IO `subscribe:collection` + `db:create`/`db:update` | `src/hooks/usePostsLive.ts` |
| Post + optional image | Ownership-scoped create, `imageUrl` as a pasted URL | `src/components/feed/PostComposer.tsx` |
| Like / unlike | Ownership-scoped create/delete + counter PATCH, check-then-act | `src/hooks/useLikes.ts` |
| Comment thread | Ownership-scoped create + counter PATCH, oldest-first | `src/hooks/useComments.ts` |
| Follow / unfollow | Ownership-scoped create/delete, check-then-act | `src/hooks/useFollows.ts` |
| Profile (posts, follower/following counts) | Filtered reads + `pagination.total` as a count | `src/hooks/useProfileStats.ts` |

## Provisioning (what already exists on Mudbase, not in this repo)

This app expects a Mudbase project already set up with:

1. Local auth enabled, with email verification required (this app's UI assumes it is).
2. The Multi-Role feature's default `customer` role (Mudbase's single-role starter template —
   there is no separate seller/admin role in this app).
3. Four collections — `posts`, `comments`, `likes`, `follows` — with the field shapes documented
   in `plan/build-plan.md`, and the `customer` role granted `create`/`read`/`update`/`delete`,
   `dataScope: "all"`, on all four (confirmed live via `GET /api/projects/{id}/
   permissions-matrix` — see `plan/build-plan.md` finding #7).

`.env.example` lists every ID this app needs once that's done.

## Live smoke test (2026-07-31, real project, two real accounts)

`posts` create/read/sort/pagination/counter-update, and both `db:create` and `db:update`
realtime events, are all **confirmed working end-to-end** against the live backend with two
independently registered, real-email-verified `customer` accounts (`mudhaxk+mbsocial1@gmail.com`
"Ava Poster", `mudhaxk+mbsocial2@gmail.com` "Ben Follower" — see `plan/build-plan.md` → "Live
smoke test results" for the full table).

> **Still open:** `POST .../data` (create) on `comments`, `likes`, and `follows` currently
> returns a generic `500 {"error":"Failed to create data"}` for every payload tried — confirmed
> not a permissions issue (identical grant to `posts`, which works) and not a payload/field-name
> issue (an empty body correctly 400s with the exact expected field names on all three; a
> malformed id correctly 400s too). The failure is inside `document.save()` on the Mudbase
> backend itself, most likely a schema/index misconfiguration specific to these three
> collections. See `plan/build-plan.md` finding #8 for the full diagnostic — this needs
> server-side log/index access this build's credentials don't reach.

## Known limitations (real platform constraints, verified live, not bugs)

**Post images are a pasted URL, not a file upload.** `rbacCheck("file","create")` (both bucket
creation and file upload) only allows the org-level system roles owner/admin/developer. Every
project end-user — including a real, verified `customer` account — always carries system role
`viewer`, confirmed with a real anonymous-session bucket-create attempt (`403`,
`"required":["owner","admin","developer"],"current":"viewer"`). `src/lib/mudbase.ts` still
implements `uploadFile()` for API-contract completeness, but no UI in this app calls it — the
composer uses a plain URL text input instead. Same real constraint the ecommerce showcase
documents for product images.

**The project's `pk_` publishable key is not a working credential on this backend.** Tried as
both `X-API-Key` and `Authorization: Bearer` — 401 either way. `authOrApiKey` only recognizes
`ak_`-prefixed keys issued via the org-level API Keys feature; the `pk_` field shown in the
project dashboard is a separate, legacy mechanism with no corresponding auth check in this
backend version. Every request in this app authenticates with a JWT instead (see
`.env.example` for the full explanation). Kept in `.env.example`/`config.ts` for parity with the
dashboard, not because anything reads it.

**No `users` collection, so profile display names are best-effort.** A user who has never posted
and has no followers has no row anywhere recording their name — `/users/[userId]` falls back to
the literal string "Member" in that case. See `useResolvedDisplayName` and `plan/build-plan.md`.

**No in-app email-verification resend.** The resend endpoint requires a valid JWT, which an
unverified account cannot obtain (login is blocked until verified) — there is no accessible way
around this from a project end-user's own permissions. If a verification email doesn't arrive,
the only recourse today is registering again.

## Local development

```bash
npm install
cp .env.example .env.local   # fill in your own provisioned project's IDs
npm run dev
```

## Deploy

Every env var in `.env.example` is `NEXT_PUBLIC_` and safe to set directly as a Vercel
Production/Preview environment variable — there is no server-only secret anywhere in this app.
