"use client"

import { useParams } from "next/navigation"
import { useAuth } from "@/hooks/useAuth"
import { useDocument } from "@/hooks/useCollection"
import { useComments } from "@/hooks/useComments"
import { useMyLikedPostIds } from "@/hooks/useLikes"
import { useMyFollowingIds } from "@/hooks/useFollows"
import { POSTS_COLLECTION_ID } from "@/lib/config"
import { PostCard } from "@/components/feed/PostCard"
import { CommentList } from "@/components/comments/CommentList"
import { CommentComposer } from "@/components/comments/CommentComposer"
import { Separator } from "@/components/ui/separator"
import type { Post } from "@/types/post"

export default function PostDetailPage(): React.JSX.Element {
  const params = useParams<{ id: string }>()
  const postId = params.id
  const { user, isAuthenticated } = useAuth()

  const postQuery = useDocument<Post>(POSTS_COLLECTION_ID, postId)
  const commentsQuery = useComments(postId)
  const likedPostIds = useMyLikedPostIds(isAuthenticated ? user?.id : undefined)
  const followingIds = useMyFollowingIds(isAuthenticated ? user?.id : undefined)

  if (postQuery.isLoading) {
    return <p className="container max-w-2xl py-16 text-center text-sm text-muted-foreground">Loading post…</p>
  }

  if (postQuery.isError || !postQuery.data) {
    return <p className="container max-w-2xl py-16 text-center text-sm text-destructive">This post isn&apos;t available.</p>
  }

  const post = postQuery.data

  return (
    <div className="container max-w-2xl space-y-6 py-8">
      <PostCard
        post={post}
        liked={likedPostIds.data?.has(post._id) ?? false}
        followingAuthor={followingIds.data?.has(post.authorId) ?? false}
        linkToDetail={false}
      />
      <Separator />
      <div className="space-y-4">
        <h2 className="text-sm font-semibold text-muted-foreground">Comments</h2>
        <CommentComposer postId={post._id} />
        {commentsQuery.isLoading ? (
          <p className="py-6 text-center text-sm text-muted-foreground">Loading comments…</p>
        ) : (
          <CommentList comments={commentsQuery.data?.data ?? []} />
        )}
      </div>
    </div>
  )
}
