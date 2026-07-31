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
   in `plan/build-plan.md`, **and the `customer` role granted `create`/`read`/`update` on all
   four** (see the CRITICAL note immediately below — this last part was not yet done as of this
   build).

`.env.example` lists every ID this app needs once that's done.

> **CRITICAL — one setup step outstanding on the live project this was built against.**
> As of this build, all 4 collections on `cloud.mudbase.dev` project `6a6cf79dd07caabbbdfbe9c5`
> have `permissions: []` (verified live via `GET /api/projects/{id}/permissions-matrix`) — so no
> project end-user, including a real verified `customer` account, can create/update anything yet.
> This requires an org owner/admin credential to fix (`PATCH .../multi-role/roles/customer/
> collections/{collectionId}/permissions`), which is outside what a project end-user — or this
> build's given credentials (`pk_` key + project ID only) — can ever obtain. See
> `plan/build-plan.md` → "Setup still required before this app can write data" for the exact
> `curl` commands to run once, plus two already-registered, already-verified test accounts ready
> to use the moment it's done. Everything else was verified live end-to-end: anonymous session +
> public read, signup, real email verification (both test accounts), login, and correct 403
> denials for anonymous/unauthenticated writes.

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
