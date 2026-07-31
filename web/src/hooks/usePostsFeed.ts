"use client"

import { useCallback } from "react"
import { useInfiniteQuery, useMutation, useQueryClient, type InfiniteData, type QueryClient } from "@tanstack/react-query"
import { useMudbase } from "@/lib/mudbase-provider"
import { POSTS_COLLECTION_ID } from "@/lib/config"
import type { ListResponse } from "@/lib/mudbase"
import type { Post } from "@/types/post"

const PAGE_SIZE = 10
export const FEED_QUERY_KEY = ["posts", "feed"] as const
type FeedData = InfiniteData<ListResponse<Post>, number>

export function usePostsFeed() {
  const { client, session } = useMudbase()
  return useInfiniteQuery<ListResponse<Post>, Error, FeedData, typeof FEED_QUERY_KEY, number>({
    queryKey: FEED_QUERY_KEY,
    queryFn: ({ pageParam }) =>
      client.getDocuments<Post>(POSTS_COLLECTION_ID, { sort: "-createdAt", page: pageParam, limit: PAGE_SIZE }),
    initialPageParam: 1,
    getNextPageParam: (lastPage) => (lastPage.pagination.hasMore ? lastPage.pagination.page + 1 : undefined),
    enabled: !!session,
  })
}

/** Inserts a brand-new post at the top of the feed cache, deduping by _id so the composer's
 * optimistic insert and the realtime `db:create` echo for the same post never double up. */
export function prependPost(queryClient: QueryClient, post: Post): void {
  queryClient.setQueryData<FeedData>(FEED_QUERY_KEY, (old) => {
    if (!old) {
      return {
        pages: [{ data: [post], pagination: { page: 1, limit: PAGE_SIZE, total: 1, totalPages: 1, hasMore: false } }],
        pageParams: [1],
      }
    }
    const alreadyPresent = old.pages.some((page) => page.data.some((p) => p._id === post._id))
    if (alreadyPresent) return old
    const [firstPage, ...restPages] = old.pages
    if (!firstPage) return old
    return {
      ...old,
      pages: [{ ...firstPage, data: [post, ...firstPage.data] }, ...restPages],
    }
  })
}

/** Applies an update (e.g. a new likesCount/commentsCount) to a post wherever it's cached -
 * every page of the feed's infinite query, plus the standalone post-detail document cache. */
export function updatePostEverywhere(queryClient: QueryClient, postId: string, patch: Partial<Post>): void {
  queryClient.setQueryData<FeedData>(FEED_QUERY_KEY, (old) => {
    if (!old) return old
    return {
      ...old,
      pages: old.pages.map((page) => ({
        ...page,
        data: page.data.map((p) => (p._id === postId ? { ...p, ...patch } : p)),
      })),
    }
  })
  queryClient.setQueryData<Post>(["collection", POSTS_COLLECTION_ID, "doc", postId], (old) =>
    old ? { ...old, ...patch } : old,
  )
}

export function useCreatePost() {
  const { client, session } = useMudbase()
  const queryClient = useQueryClient()

  const mutate = useCallback(
    async ({ content, imageUrl }: { content: string; imageUrl?: string }): Promise<Post> => {
      const user = session?.user
      if (!user) throw new Error("Must be signed in to post")
      const authorName = `${user.firstName} ${user.lastName}`.trim()
      const created = await client.createDocument<Post>(POSTS_COLLECTION_ID, {
        authorId: user.id,
        authorName,
        content,
        ...(imageUrl ? { imageUrl } : {}),
        likesCount: 0,
        commentsCount: 0,
      })
      prependPost(queryClient, created)
      return created
    },
    [client, session, queryClient],
  )

  return useMutation({ mutationFn: mutate })
}
