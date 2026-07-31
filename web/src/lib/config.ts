function requireEnv(name: string, value: string | undefined): string {
  if (!value) throw new Error(`Missing required environment variable: ${name}`)
  return value
}

export const MUDBASE_PROJECT_ID = requireEnv(
  "NEXT_PUBLIC_MUDBASE_PROJECT_ID",
  process.env.NEXT_PUBLIC_MUDBASE_PROJECT_ID,
)
export const MUDBASE_URL = process.env.NEXT_PUBLIC_MUDBASE_URL ?? "https://cloud.mudbase.dev"

// Project publishable key - see .env.example for why this is currently unused by any request
// (kept for parity with the platform dashboard and forward-compatibility).
export const MUDBASE_API_KEY = process.env.NEXT_PUBLIC_MUDBASE_API_KEY ?? ""

export const POSTS_COLLECTION_ID = requireEnv(
  "NEXT_PUBLIC_POSTS_COLLECTION_ID",
  process.env.NEXT_PUBLIC_POSTS_COLLECTION_ID,
)
export const COMMENTS_COLLECTION_ID = requireEnv(
  "NEXT_PUBLIC_COMMENTS_COLLECTION_ID",
  process.env.NEXT_PUBLIC_COMMENTS_COLLECTION_ID,
)
export const LIKES_COLLECTION_ID = requireEnv(
  "NEXT_PUBLIC_LIKES_COLLECTION_ID",
  process.env.NEXT_PUBLIC_LIKES_COLLECTION_ID,
)
export const FOLLOWS_COLLECTION_ID = requireEnv(
  "NEXT_PUBLIC_FOLLOWS_COLLECTION_ID",
  process.env.NEXT_PUBLIC_FOLLOWS_COLLECTION_ID,
)
