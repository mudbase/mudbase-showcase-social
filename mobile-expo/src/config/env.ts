/**
 * All values here are read from EXPO_PUBLIC_* env vars — Expo's convention for
 * anything safe to bundle into the client binary. A project ID or collection ID
 * is not a secret (see web/.env.example's identical framing) — every request
 * this app makes authenticates with a JWT (anonymous session for guests, a real
 * session after login), never with a static key. There is no server-only
 * credential anywhere in this app, so nothing needs to live outside
 * EXPO_PUBLIC_*.
 */
function requireEnv(name: string, value: string | undefined): string {
  if (!value) {
    throw new Error(
      `Missing required environment variable: ${name}. Copy .env.example to .env and fill in your provisioned Mudbase project's IDs.`,
    );
  }
  return value;
}

export const MUDBASE_URL = process.env.EXPO_PUBLIC_MUDBASE_URL ?? "https://cloud.mudbase.dev";

export const MUDBASE_PROJECT_ID = requireEnv(
  "EXPO_PUBLIC_MUDBASE_PROJECT_ID",
  process.env.EXPO_PUBLIC_MUDBASE_PROJECT_ID,
);

export const POSTS_COLLECTION_ID = requireEnv(
  "EXPO_PUBLIC_POSTS_COLLECTION_ID",
  process.env.EXPO_PUBLIC_POSTS_COLLECTION_ID,
);

export const COMMENTS_COLLECTION_ID = requireEnv(
  "EXPO_PUBLIC_COMMENTS_COLLECTION_ID",
  process.env.EXPO_PUBLIC_COMMENTS_COLLECTION_ID,
);

export const LIKES_COLLECTION_ID = requireEnv(
  "EXPO_PUBLIC_LIKES_COLLECTION_ID",
  process.env.EXPO_PUBLIC_LIKES_COLLECTION_ID,
);

export const FOLLOWS_COLLECTION_ID = requireEnv(
  "EXPO_PUBLIC_FOLLOWS_COLLECTION_ID",
  process.env.EXPO_PUBLIC_FOLLOWS_COLLECTION_ID,
);
