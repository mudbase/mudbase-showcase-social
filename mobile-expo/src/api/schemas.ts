import { z } from "zod";

/**
 * Runtime validation for every Mudbase response shape this app touches.
 *
 * Several of the generated `mudbase-sdk` response models under-describe the
 * real JSON the platform returns — e.g. `CreateAnonymousSession200ResponseUser`
 * and `LoginLocalUser200ResponseUser` both omit `customRole`, even though the
 * live API includes it on every project-scoped session response (verified by
 * the reference web app at web/src/lib/mudbase.ts's `UserObject` interface,
 * and by the sibling `mudbase-showcase-ecommerce/mobile-expo` port's own
 * `schemas.ts`, which documents the identical gap against the same generated
 * SDK). Rather than casting past the generated types with `as`, every SDK
 * response is widened to `unknown` (always assignable, no cast needed) and
 * parsed through one of these schemas instead.
 */

// ─── Auth / User ────────────────────────────────────────────────────────────

export const mudbaseUserSchema = z.object({
  id: z.string(),
  email: z.string(),
  firstName: z.string(),
  lastName: z.string(),
  customRole: z.string().nullable().optional(),
  emailVerified: z.boolean().optional(),
  isAnonymous: z.boolean().optional(),
});
export type MudbaseUser = z.infer<typeof mudbaseUserSchema>;

export const authResultSchema = z.object({
  message: z.string().optional(),
  token: z.string().optional(),
  refreshToken: z.string().optional(),
  expiresIn: z.number().optional(),
  requireVerification: z.boolean().optional(),
  user: mudbaseUserSchema.optional(),
});
export type AuthResult = z.infer<typeof authResultSchema>;

// ─── Documents (Collections) ───────────────────────────────────────────────

export const documentBaseSchema = z.object({
  _id: z.string(),
  createdAt: z.string(),
  updatedAt: z.string(),
});

export const postSchema = documentBaseSchema.extend({
  authorId: z.string(),
  authorName: z.string(),
  content: z.string(),
  imageUrl: z.string().optional(),
  likesCount: z.number(),
  commentsCount: z.number(),
});
export type Post = z.infer<typeof postSchema>;

export const commentSchema = documentBaseSchema.extend({
  postId: z.string(),
  authorId: z.string(),
  authorName: z.string(),
  content: z.string(),
});
export type Comment = z.infer<typeof commentSchema>;

export const likeSchema = documentBaseSchema.extend({
  postId: z.string(),
  userId: z.string(),
});
export type Like = z.infer<typeof likeSchema>;

export const followSchema = documentBaseSchema.extend({
  followerId: z.string(),
  followingId: z.string(),
  followingName: z.string().optional(),
});
export type Follow = z.infer<typeof followSchema>;
