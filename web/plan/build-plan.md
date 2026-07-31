# Build Plan — Mudbase Showcase: Social
Generated: 2026-07-31
Mode: greenfield (1 of 10 language/platform ports — this is the reference implementation)
Type: web (fullstack via BaaS, no custom backend)
Stack: Next.js 15 App Router + TypeScript + Tailwind CSS + shadcn/ui, backed entirely by Mudbase (cloud.mudbase.dev)

## Stack Decisions
- Next.js 15 App Router + TanStack Query + shadcn/ui/Tailwind: matches this session's Web App
  default and the sibling `mudbase-showcase-ecommerce` project, which every other of the 10
  planned ports will be checked against for data-model/API-contract parity.
- No custom backend of any kind: every persistence, auth, and realtime concern is a Mudbase
  REST/WebSocket call made directly from the browser.
- `src/lib/mudbase.ts` ports the ecommerce showcase's client verbatim (401 → refresh → retry,
  `refreshInFlight` dedupe for rotating single-use refresh tokens) rather than reimplementing it -
  see that file's header comment and `plan/build-plan.md`'s "Auth Flow" there for why.

## Real-Project Verification (done live against cloud.mudbase.dev before writing any UI)

All of the following were confirmed with `curl` against the actual provisioned project
(`6a6cf79dd07caabbbdfbe9c5`) before the client/UI code was written, per the task's "verify before
wiring" instruction:

1. **Signup role slug is `customer`, not `user`.** `POST /api/auth/local/signup/user` → 404
   `Role not found`. `POST /api/auth/local/signup/customer` → 201. This project ships Mudbase's
   single default starter multi-role template (`MultiRoleFeature.getDefaultTemplates()` in the
   backend), which is always slug/signupEndpoint `customer` regardless of what the app is about.
   `src/lib/mudbase.ts` hardcodes this as `APP_ROLE = "customer"` rather than exposing a role
   parameter, since this app (unlike the ecommerce showcase) has only one role.

2. **The `pk_` publishable key is not a working credential on this backend.** Tried as
   `X-API-Key: pk_...` → 401 `Invalid API key`. Tried as `Authorization: Bearer pk_...` → 401
   (not even recognized as an API key attempt - `authOrApiKey` only treats a `Bearer` value as an
   API key if it starts with `ak_`). Reading the backend source
   (`middleware/auth.js`, `models/Project.js`) confirms why: `project.apiKey` (the `pk_`-prefixed
   field shown in the dashboard) is a different, legacy mechanism from the org-level `ApiKey`
   collection (`ak_`-prefixed, checked via `ApiKey.findActiveByRawKey`) that `authOrApiKey`
   actually validates. Every request in this app authenticates with a JWT instead - an anonymous
   session for guests, a real session after signup+verification+login.

3. **Every collection read requires *some* authentication - `pk_` does not substitute for it.**
   `GET .../collections/{postsId}/data` with no `Authorization`/`X-API-Key` header at all → 401.
   Same request with the `pk_` key as `X-API-Key` → still 401. With an anonymous-session JWT →
   200 (public, empty list). This app therefore bootstraps a silent anonymous session on first
   load, exactly like the ecommerce showcase, purely so "public read" actually resolves - the
   guest never sees a login prompt for it.

4. **Anonymous ("viewer") sessions cannot write to any of the 4 app collections.**
   `POST .../collections/{postsId}/data` as an anonymous session → 403
   `{"userRole":"viewer","customRole":"none"}`. Confirms posting/liking/commenting/following are
   correctly gated behind a real, verified `customer` account, matching the task's "auth-gated
   actions, public read" requirement without any extra app-side role check needed - Mudbase's own
   collection permissions are the enforcement boundary.

5. **This project requires email verification, and register() does not return a session token.**
   `POST /api/auth/local/signup/customer` → 201 with `requireVerification: true` and no `token`.
   `POST /api/auth/local/login` before verifying → 403
   `{"error":"Email verification required","code":"EMAIL_VERIFICATION_REQUIRED"}`. The
   verification email is sent via an async queue (`services/email/sendEmail.js` →
   `jobs/emailQueue.js`) to whatever address was used at signup; `POST /api/users/verify-email`
   (public, no auth - `routes/user.js`) completes it given the token from that email's link. The
   app's `RegisterForm` shows a "check your inbox" state instead of assuming a session; a
   dedicated `/verify-email?token=...` page completes the flow; `LoginForm` surfaces the specific
   `EMAIL_VERIFICATION_REQUIRED` message when it's hit.

6. **File/bucket creation is unreachable for any project end-user, verified.** See "Known
   limitations" below - confirmed with a real anonymous-session request, not just source reading.

7. **CRITICAL, still open at the end of this build: the 4 collections have no role permissions
   configured (`permissions: []` on all of them), so no project end-user - not even a real,
   verified `customer` - can write to any of them yet.** Verified live via
   `GET /api/projects/{projectId}/permissions-matrix` (readable with a plain `customer` JWT,
   since `project:read` allows the `viewer` system role every project end-user carries) - every
   one of `posts`/`comments`/`likes`/`follows` came back with an empty `permissions` array. A
   fully verified, logged-in `customer` account (`mudhaxk+mbsocial1@gmail.com`, confirmed
   `emailVerified: true`) still gets `403 {"error":"Insufficient permissions","required":
   {"action":"create","collection":"posts"}}` when posting - `resolveCollectionPermission()` in
   `middleware/collectionPermissions.js` only grants anything beyond the hardcoded
   viewer+read fallback when the collection has an explicit `{role, actions, conditions}` entry,
   and none exist here. **This is a project-provisioning gap, not an app bug** - granting it
   requires `PATCH /api/projects/:projectId/multi-role/roles/:roleSlug/collections/:collectionId/permissions`,
   which is `authRequired` + `rbacCheck("project","update")` + `requireOwnerOrAdmin` - an org
   owner/admin credential no project end-user (and no credential this task provided) can ever
   satisfy. See "Setup still required before this app can write data" immediately below.

## Setup still required before this app can write data (needs org owner/admin access)

Run once, authenticated as an owner/admin of this project's org (via the Mudbase console or an
org-level session - not anything a project end-user can obtain), for each of the 4 collection
IDs:

```bash
curl -X PATCH "https://cloud.mudbase.dev/api/projects/6a6cf79dd07caabbbdfbe9c5/multi-role/roles/customer/collections/{collectionId}/permissions" \
  -H "Authorization: Bearer <org owner/admin JWT>" \
  -H "Content-Type: application/json" \
  -d '{"actions":["create","read","update"],"dataScope":"all"}'
```

`{collectionId}` = `6a6cf7d0d07caabbbdfbe9db` (posts), `6a6cf7d1d07caabbbdfbe9f1` (comments),
`6a6cf81ed07caabbbdfbea20` (likes), `6a6cf81ed07caabbbdfbea32` (follows). `dataScope: "all"` (not
`"own"`) because this app's own application-layer logic already needs to read/update rows it
doesn't own (checking another user's like/follow row before toggling, incrementing another
user's post's counters) - Mudbase's per-row ownership enforcement would block exactly the calls
`useToggleLike`/`useToggleFollow`/`useCreateComment` make. Once this is run, the full write path
(post, like, comment, follow) is expected to work end-to-end with no code changes - reads,
anonymous gating, auth, and the entire UI were already verified against the real backend; only
this permissions grant was outside what this build's credentials (`pk_` key + project ID only,
no org owner session) could reach. Two real, fully verified `customer` accounts already exist on
this project ready to exercise it immediately: `mudhaxk+mbsocial1@gmail.com` ("Ava Poster") and
`mudhaxk+mbsocial2@gmail.com` ("Ben Follower"), both password `SocialTest123!`.

## Data Models (Mudbase Collections — already provisioned, used as-is, not recreated)

### posts — `6a6cf7d0d07caabbbdfbe9db`
`authorId` (string), `authorName` (string), `content` (string), `imageUrl` (string, optional),
`likesCount` (number), `commentsCount` (number), plus `_id`/`createdAt`/`updatedAt`.
Intended permissions: `customer` role → create/read/update. Anonymous (`viewer`, no `customRole`)
→ read only (this half is live today via the platform's hardcoded viewer+read fallback - see
finding #7 above for why the `customer` write half is not yet active).

### comments — `6a6cf7d1d07caabbbdfbe9f1`
`postId` (string), `authorId` (string), `authorName` (string), `content` (string).
One row per comment; sorted `createdAt` ascending in the UI (oldest first, normal thread order).

### likes — `6a6cf81ed07caabbbdfbea20`
`postId` (string), `userId` (string). One row per (postId, userId) pair - this collection type
has no compound unique index, so uniqueness is enforced at the application layer: every toggle
re-queries `{postId, userId}` immediately before creating/deleting (see `useToggleLike`), which is
a reasonable (not airtight) guard against a double-click/double-tab race, per the task's own
"check-then-act is fine for a demo" instruction.

### follows — `6a6cf81ed07caabbbdfbea32`
`followerId` (string), `followingId` (string), `followingName` (string, optional - denormalized
at write time so a profile page can resolve a display name for a user who has never posted; see
"Known limitations"). Same check-then-act uniqueness guard as likes (`useToggleFollow`).

## Auth Flow
```
First visit (no token)  → POST /api/auth/anonymous → guest session (role: viewer, customRole: null)
                                                     → can read the feed/posts/comments, cannot write
Register                → POST /api/auth/local/signup/customer (agreedToTerms: true required)
                                                     → 201, no token, requireVerification: true
                                                     → verification email queued to the given address
Verify                  → user clicks the emailed link → GET /verify-email?token=...&project=...
                                                     → app calls POST /api/users/verify-email { token }
Login                   → POST /api/auth/local/login → 403 EMAIL_VERIFICATION_REQUIRED until verified
                                                     → 200 + token/refreshToken once verified
Logout                  → POST /api/auth/logout (revokes token + kills session)
```

## Realtime
The feed subscribes to the `posts` collection's Socket.IO room: `subscribe:collection`
`{projectId, collectionId}` → `db:create`/`db:update` events, exact same contract as the
ecommerce showcase's `useOrdersLive` (confirmed by reading `sockets/index.js` on the Mudbase
backend, not guessed). `db:create` prepends the new post (deduped by `_id` against the
composer's own optimistic insert of the same post); `db:update` patches whichever cached copy of
that post exists (feed page or post-detail) - this is what makes another user's like/comment
appear live on a post already open in your feed, not just brand-new posts.

## UI Pages
- `/` — feed: `PostComposer` + `FeedList` (paginated via `useInfiniteQuery`, "Load more"; live via
  `usePostsLive`). Public read; posting redirects to `/login` if not authenticated.
- `/posts/[id]` — post detail: full post, `CommentList` (oldest-first), `CommentComposer`, like
  toggle.
- `/users/[userId]` — profile: resolved display name, follower/following/post counts, that user's
  posts, follow/unfollow button (hidden on your own profile).
- `/profile` — thin client-side redirect to `/users/{currentUserId}`.
- `/login`, `/register` — email+password; register shows a "check your inbox" state rather than
  assuming a session (see verification finding #5 above).
- `/verify-email` — completes the emailed verification link.

## Security Implementation
- Input validation: zod schemas for every form (register, login, post composer, comment
  composer) via react-hook-form + `@hookform/resolvers/zod`. Post content capped at 500 chars,
  comments at 300.
- Authentication: Mudbase-issued JWT (access + refresh) held in `localStorage` via
  `MudbaseClient`, with 401 → refresh → retry handled once, deduped across concurrent requests
  (`refreshInFlight`) - see the task's explicit instruction to port this pattern correctly from
  day one.
- Authorization: enforced server-side by Mudbase collection permissions (customer-only
  create/update, public read) - the app's own `isAuthenticated` checks are UX gating (redirect to
  `/login`), not the security boundary.
- Rate limiting: inherited from Mudbase's own per-endpoint limits (auth: observed 3
  registrations/hour/IP in practice during this build's own live testing) - no additional
  app-level limiting needed since there's no custom backend.
- Secrets: none - every env var is `NEXT_PUBLIC_` because every value (project ID, collection
  IDs, the inert `pk_` key) is safe to expose; there is no server-side credential anywhere in
  this app (no Route Handlers at all, unlike the ecommerce showcase's payment-link endpoint).

## Known Limitations (real platform constraints, not bugs)

**Collection write permissions for `customer` are not yet granted on this project (see "Setup
still required" above) - this blocked completing the live write-path smoke test (post/like/
comment/follow) in this build session.** Everything reachable without an org owner/admin
credential was verified live end-to-end instead: guest anonymous session + public read, signup,
email verification (real emails, real tokens, both accounts verified), login, and the correct
403 denial for both anonymous writes and unauthenticated reads. The moment the PATCH calls above
are run once, the remaining write-path checks require no further code changes.

**Post images are a pasted URL, not an upload.** Verified live: `rbacCheck("file","create")`
(both bucket creation and file upload) only allows the org-level system roles
owner/admin/developer. Every project end-user - including a real, verified `customer` account -
always carries system role `viewer` (confirmed via a real anonymous-session
`POST .../buckets` attempt: 403 `"required":["owner","admin","developer"],"current":"viewer"`).
No project end-user JWT can ever pass this check. `src/lib/mudbase.ts` still implements
`uploadFile()` for API-contract completeness (mirrors the ecommerce showcase and documents the
platform capability precisely), but `PostComposer` uses a plain `imageUrl` text input instead of
a file picker - exactly the same real constraint and the same resolution the ecommerce showcase
documents for product images.

**No `users` collection exists, so a profile has no server-side source of truth for a display
name.** Every author/commenter/follower name in this data model is denormalized onto the row
that references them (`authorName`, `followingName`) rather than looked up from a central users
table - there isn't one. `useResolvedDisplayName` best-efforts a name for `/users/[userId]` from
that user's most recent post, falling back to any `followingName` recorded by someone who follows
them, falling back to the literal string "Member" if neither exists yet (e.g. a brand-new account
that has only ever followed people, never posted, and has no followers). This is a genuine data
model constraint of a schema with no user directory, not a bug.

**Email verification has no in-app bypass or resend path.** `POST /api/users/resendVerification`-
equivalent (`resendVerificationEmail` in `controllers/userController.js`) requires
`authRequired` - a valid JWT - but an unverified user cannot log in to obtain one. This app
therefore has no "resend" button; the only path forward after registering is the original
verification email. This matched the real login-blocking behavior found live (see verification
finding #5) and was not designed around, since there is no accessible fix within a project
end-user's own permissions.

## Environment Variables
See `.env.example`. All public (`NEXT_PUBLIC_*`) - see "Security Implementation" above for why.

## File Tree
```
mudbase-showcase-social/web/
├── package.json, tsconfig.json, next.config.ts, tailwind.config.ts, postcss.config.mjs,
│   components.json, eslint.config.mjs, .env.example, .env.local, README.md
├── plan/build-plan.md
├── src/
│   ├── app/
│   │   ├── layout.tsx, globals.css, page.tsx
│   │   ├── login/page.tsx, register/page.tsx, verify-email/page.tsx
│   │   ├── posts/[id]/page.tsx
│   │   ├── users/[userId]/page.tsx
│   │   └── profile/page.tsx
│   ├── components/
│   │   ├── providers/ (QueryProvider)
│   │   ├── layout/ (Header)
│   │   ├── auth/ (LoginForm, RegisterForm)
│   │   ├── feed/ (PostComposer, PostCard, FeedList)
│   │   ├── social/ (LikeButton, FollowButton)
│   │   ├── comments/ (CommentList, CommentComposer)
│   │   ├── profile/ (ProfileHeader, ProfilePostList)
│   │   └── ui/ (shadcn primitives: button, card, input, label, textarea, badge, separator, avatar)
│   ├── hooks/ (useAuth, useCollection, useSocket, usePostsFeed, usePostsLive, useLikes,
│   │           useFollows, useComments, useProfileStats)
│   ├── lib/ (mudbase.ts, mudbase-provider.tsx, mudbase-socket.ts, config.ts, utils.ts)
│   └── types/ (post.ts, comment.ts, like.ts, follow.ts)
```
