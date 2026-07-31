"use client"

import { useCallback } from "react"
import { useMutation, useQueryClient } from "@tanstack/react-query"
import { useMudbase } from "@/lib/mudbase-provider"
import { useDocuments } from "@/hooks/useCollection"
import { COMMENTS_COLLECTION_ID, POSTS_COLLECTION_ID } from "@/lib/config"
import { updatePostEverywhere } from "@/hooks/usePostsFeed"
import type { Comment } from "@/types/comment"
import type { Post } from "@/types/post"

/** Oldest first, like a normal comment thread - newest replies land at the bottom. */
export function useComments(postId: string) {
  return useDocuments<Comment>(COMMENTS_COLLECTION_ID, { filter: { postId }, sort: "createdAt", limit: 200 })
}

export function useCreateComment(postId: string) {
  const { client, session } = useMudbase()
  const queryClient = useQueryClient()

  const mutate = useCallback(
    async (content: string): Promise<Comment> => {
      const user = session?.user
      if (!user) throw new Error("Must be signed in to comment")
      const authorName = `${user.firstName} ${user.lastName}`.trim()

      const created = await client.createDocument<Comment>(COMMENTS_COLLECTION_ID, {
        postId,
        authorId: user.id,
        authorName,
        content,
      })

      // Re-read the post immediately before incrementing so a burst of concurrent comments
      // (e.g. two tabs) doesn't have both writers increment from the same stale count - same
      // check-then-act guard style as useToggleLike/useToggleFollow.
      const currentPost = await client.getDocument<Post>(POSTS_COLLECTION_ID, postId)
      const commentsCount = currentPost.commentsCount + 1
      await client.updateDocument<Post>(POSTS_COLLECTION_ID, postId, { commentsCount })
      updatePostEverywhere(queryClient, postId, { commentsCount })

      return created
    },
    [client, session, postId, queryClient],
  )

  return useMutation({
    mutationFn: mutate,
    onSuccess: () => {
      // Prefix-invalidate every query for this collection rather than reconstructing the exact
      // key useDocuments built - simpler, and still only touches this collection's cache.
      queryClient.invalidateQueries({ queryKey: ["collection", COMMENTS_COLLECTION_ID] })
    },
  })
}
