"use client"

import { useAuth } from "@/hooks/useAuth"
import { useDocuments } from "@/hooks/useCollection"
import { useMyLikedPostIds } from "@/hooks/useLikes"
import { useMyFollowingIds } from "@/hooks/useFollows"
import { POSTS_COLLECTION_ID } from "@/lib/config"
import { PostCard } from "@/components/feed/PostCard"
import type { Post } from "@/types/post"

// Demo scale: one bounded page, no further pagination UI on a profile - a single showcase
// account will never accumulate enough posts to need it.
const PROFILE_POSTS_LIMIT = 100

export function ProfilePostList({ userId }: { userId: string }): React.JSX.Element {
  const { user, isAuthenticated } = useAuth()
  const postsQuery = useDocuments<Post>(POSTS_COLLECTION_ID, {
    filter: { authorId: userId },
    sort: "-createdAt",
    limit: PROFILE_POSTS_LIMIT,
  })
  const likedPostIds = useMyLikedPostIds(isAuthenticated ? user?.id : undefined)
  const followingIds = useMyFollowingIds(isAuthenticated ? user?.id : undefined)

  if (postsQuery.isLoading) {
    return <p className="py-10 text-center text-sm text-muted-foreground">Loading posts…</p>
  }

  if (postsQuery.isError) {
    return <p className="py-10 text-center text-sm text-destructive">Couldn&apos;t load this user&apos;s posts.</p>
  }

  const posts = postsQuery.data?.data ?? []

  if (posts.length === 0) {
    return <p className="py-10 text-center text-sm text-muted-foreground">No posts yet.</p>
  }

  return (
    <div className="space-y-4">
      {posts.map((post) => (
        <PostCard
          key={post._id}
          post={post}
          liked={likedPostIds.data?.has(post._id) ?? false}
          followingAuthor={followingIds.data?.has(post.authorId) ?? false}
        />
      ))}
    </div>
  )
}
