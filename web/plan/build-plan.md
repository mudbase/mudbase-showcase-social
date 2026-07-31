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

7. **RESOLVED during this build: the 4 collections initially had no role permissions configured
   (`permissions: []` on all of them), which blocked every project end-user - even a real,
   verified `customer` - from writing.** Found via `GET /api/projects/{projectId}/
   permissions-matrix` (readable with a plain `customer` JWT, since `project:read` allows the
   `viewer` system role every project end-user carries): all four of `posts`/`comments`/`likes`/
   `follows` came back with an empty `permissions` array, and a fully verified `customer` account
   got `403 Insufficient permissions` on `POST posts`. This required org owner/admin access
   (`PATCH /api/projects/:projectId/multi-role/roles/:roleSlug/collections/:collectionId/
   permissions`, gated by `requireOwnerOrAdmin`) that this build's own credentials (`pk_` key +
   project ID only) could not reach - the project owner granted `customer` role
   `create/read/update/delete`, `dataScope: "all"` on all four collections directly via the
   org-owner API. Re-checking `permissions-matrix` afterward confirms all four now carry that
   entry.

8. **RESOLVED: `POST .../data` (create) on `comments`, `likes`, and `follows` initially returned
   `500 {"error":"Failed to create data"}` for every payload tried** (including both real
   Ava/Ben ids and freshly-generated dummy ObjectId strings) **while `posts` create worked
   fine.** Ruled out permissions (finding #7's grant covers all four collections identically) and
   field-naming/payload shape (empty-body requests against each of the three correctly 400 with
   the exact expected field names, and a malformed-hex dummy id correctly 400s too - both prove
   the request reached `document.save()` before failing). Root cause, confirmed by the project
   owner: the shared MongoDB Atlas cluster backing the whole Mudbase platform had hit its
   hard 500-collection cap (an Atlas Flex-tier, cluster-wide limit - nothing specific to this
   project or these three collections; `posts`' underlying Mongo collection likely already
   existed from earlier testing, while `comments`/`likes`/`follows` needed to be freshly
   materialized on first insert and couldn't be). Fixed by the project owner dropping 20
   confirmed-orphaned collections elsewhere on the cluster to free capacity - not an app bug,
   and not something fixable from this app's code or this build's credentials. Re-verified live
   afterward: all three collections now create successfully - see "Live smoke test results".

## Data Models (Mudbase Collections — already provisioned, used as-is, not recreated)

### posts — `6a6cf7d0d07caabbbdfbe9db`
`authorId` (string), `authorName` (string), `content` (string), `imageUrl` (string, optional),
`likesCount` (number), `commentsCount` (number), plus `_id`/`createdAt`/`updatedAt`.
Permissions: `customer` role → create/read/update/delete, `dataScope: "all"` (granted live, see
finding #7). Anonymous (`viewer`, no `customRole`) → read only. **Fully verified working live**:
two posts created by two different accounts, sort/pagination/counter updates and both realtime
event types all confirmed - see "Live smoke test results" below.

### comments — `6a6cf7d1d07caabbbdfbe9f1`
`postId` (string), `authorId` (string), `authorName` (string), `content` (string).
One row per comment; sorted `createdAt` ascending in the UI (oldest first, normal thread order).
Permissions granted identically to `posts` (finding #7). **Fully verified working live** - see
"Live smoke test results" below.

### likes — `6a6cf81ed07caabbbdfbea20`
`postId` (string), `userId` (string). One row per (postId, userId) pair - this collection type
has no compound unique index, so uniqueness is enforced at the application layer: every toggle
re-queries `{postId, userId}` immediately before creating/deleting (see `useToggleLike`), which is
a reasonable (not airtight) guard against a double-click/double-tab race, per the task's own
"check-then-act is fine for a demo" instruction. **Fully verified working live** - see "Live smoke
test results" below.

### follows — `6a6cf81ed07caabbbdfbea32`
`followerId` (string), `followingId` (string), `followingName` (string, optional - denormalized
at write time so a profile page can resolve a display name for a user who has never posted; see
"Known limitations"). Same check-then-act uniqueness guard as likes (`useToggleFollow`).
**Fully verified working live** - see "Live smoke test results" below.

## Live smoke test results (2026-07-31, against the real project, after finding #7's permission grant and finding #8's Atlas capacity fix)

Two real accounts, both registered, both real-email-verified (verification link retrieved and
followed via Gmail), both logged in for a real JWT: `mudhaxk+mbsocial1@gmail.com` ("Ava Poster")
and `mudhaxk+mbsocial2@gmail.com` ("Ben Follower"), password `SocialTest123!` for both.

| Step | Result |
|---|---|
| Ava creates a post with an image URL | ✅ `201`, `imageUrl` stored, correct shape |
| Ava creates a second post (no image) | ✅ `201` - confirms the first wasn't a fluke |
| Ben creates a post (used for the second realtime round below) | ✅ `201` |
| Feed read: `sort=-createdAt`, all three posts | ✅ correct order (newest first), correct `pagination.total` |
| Ben comments on Ava's post | ✅ `201` |
| Ben likes Ava's post (check-then-act: query-then-create) | ✅ `200` empty check, then `201` create |
| Ben follows Ava | ✅ `201` |
| Ava comments on / likes / follows Ben (second round, for realtime check below) | ✅ `201` × 3 |
| `PATCH posts` counter updates (`likesCount`/`commentsCount`) after each write | ✅ all succeed, reflected on re-read |
| Post detail: comments for Ava's post, sorted oldest-first | ✅ Ben's comment present, correct content |
| `useMyLikedPostIds`-equivalent read (Ben's liked postIds) | ✅ contains Ava's post id |
| `useMyFollowingIds`-equivalent read (Ben's following ids) | ✅ contains Ava's id + denormalized name |
| `useFollowCounts`-equivalent reads | ✅ Ava: 1 follower / 0 following; Ben: 0 followers / 1 following |
| Ava's profile post count | ✅ 2 (her two posts) |
| Realtime: Ava subscribed to `posts`, Ben creates a post via REST | ✅ Ava's socket receives `db:create` with the correct document, live, within ~1.5s |
| Realtime: Ava subscribed to `posts`, Ben PATCHes `likesCount` via REST | ✅ Ava's socket receives `db:update` with the correct new value, live |
| Realtime: Ben subscribed to `comments`+`likes`+`follows`, Ava writes to all three via REST | ✅ Ben's socket receives all three `db:create` events live, correctly scoped to each `collectionId` |

**Net result:** the entire app-to-Mudbase contract this app relies on - post/comment/like/follow
create, read, sort, pagination, counter updates, follower/following counts, denormalized display
names, and realtime `db:create`/`db:update` on every collection this app touches - is proven
correct against the real, live backend with two independent, real-email-verified accounts.
`useToggleLike`/`useCreateComment`/`useToggleFollow`/`usePostsLive` all issue exactly the request
shapes exercised here. No code changes were needed once the two infrastructure issues (findings
#7 and #8) were resolved on the platform side.

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
