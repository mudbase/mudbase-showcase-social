"use client"

import { useCallback } from "react"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { useMudbase } from "@/lib/mudbase-provider"
import { LIKES_COLLECTION_ID, POSTS_COLLECTION_ID } from "@/lib/config"
import { updatePostEverywhere } from "@/hooks/usePostsFeed"
import type { Like } from "@/types/like"
import type { Post } from "@/types/post"

const MY_LIKES_QUERY_KEY = (userId: string) => ["likes", "mine", userId] as const
// Demo-scale cap: this app has no pagination UI for "posts I've liked", so one bounded page
// covers every like the seeded/smoke-tested accounts will ever create.
const MINE_LIMIT = 500

/** The signed-in user's own liked-post ids, fetched once and reused by every LikeButton in the
 * feed - avoids one query per rendered post. */
export function useMyLikedPostIds(userId: string | undefined) {
  const { client } = useMudbase()
  return useQuery<Set<string>>({
    queryKey: MY_LIKES_QUERY_KEY(userId ?? ""),
    queryFn: async () => {
      const res = await client.getDocuments<Like>(LIKES_COLLECTION_ID, { filter: { userId }, limit: MINE_LIMIT })
      return new Set(res.data.map((like) => like.postId))
    },
    enabled: !!userId,
  })
}

export function useToggleLike(post: Post, userId: string | undefined) {
  const { client } = useMudbase()
  const queryClient = useQueryClient()

  const mutate = useCallback(async (): Promise<{ liked: boolean; likesCount: number }> => {
    if (!userId) throw new Error("Must be signed in to like a post")

    // Check-then-act against the server (not just the local cache) right before mutating -
    // reasonable protection against a double-click/double-tab race creating two like rows for
    // the same (postId, userId), since this collection type has no compound unique index.
    const existing = await client.getDocuments<Like>(LIKES_COLLECTION_ID, {
      filter: { postId: post._id, userId },
      limit: 1,
    })
    const existingLike = existing.data[0]

    if (existingLike) {
      await client.deleteDocument(LIKES_COLLECTION_ID, existingLike._id)
      const likesCount = Math.max(0, post.likesCount - 1)
      await client.updateDocument<Post>(POSTS_COLLECTION_ID, post._id, { likesCount })
      return { liked: false, likesCount }
    }

    await client.createDocument<Like>(LIKES_COLLECTION_ID, { postId: post._id, userId })
    const likesCount = post.likesCount + 1
    await client.updateDocument<Post>(POSTS_COLLECTION_ID, post._id, { likesCount })
    return { liked: true, likesCount }
  }, [client, post, userId])

  return useMutation({
    mutationFn: mutate,
    onSuccess: ({ liked, likesCount }) => {
      if (!userId) return
      updatePostEverywhere(queryClient, post._id, { likesCount })
      queryClient.setQueryData<Set<string>>(MY_LIKES_QUERY_KEY(userId), (old) => {
        const next = new Set(old ?? [])
        if (liked) next.add(post._id)
        else next.delete(post._id)
        return next
      })
    },
  })
}
