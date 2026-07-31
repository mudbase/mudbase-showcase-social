"use client"

import { useAuth } from "@/hooks/useAuth"
import { usePostsFeed } from "@/hooks/usePostsFeed"
import { usePostsLive } from "@/hooks/usePostsLive"
import { useMyLikedPostIds } from "@/hooks/useLikes"
import { useMyFollowingIds } from "@/hooks/useFollows"
import { PostCard } from "@/components/feed/PostCard"
import { Button } from "@/components/ui/button"

export function FeedList(): React.JSX.Element {
  const { user, isAuthenticated } = useAuth()
  const feed = usePostsFeed()
  usePostsLive(true)
  const likedPostIds = useMyLikedPostIds(isAuthenticated ? user?.id : undefined)
  const followingIds = useMyFollowingIds(isAuthenticated ? user?.id : undefined)

  const posts = feed.data?.pages.flatMap((page) => page.data) ?? []

  if (feed.isLoading) {
    return <p className="py-12 text-center text-sm text-muted-foreground">Loading feed…</p>
  }

  if (feed.isError) {
    return <p className="py-12 text-center text-sm text-destructive">Couldn&apos;t load the feed. Try refreshing.</p>
  }

  if (posts.length === 0) {
    return <p className="py-12 text-center text-sm text-muted-foreground">No posts yet - be the first to share something.</p>
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
      {feed.hasNextPage && (
        <div className="flex justify-center pt-2">
          <Button variant="outline" onClick={() => feed.fetchNextPage()} disabled={feed.isFetchingNextPage}>
            {feed.isFetchingNextPage ? "Loading…" : "Load more"}
          </Button>
        </div>
      )}
    </div>
  )
}
