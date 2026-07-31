import { useCallback } from "react";
import { useInfiniteQuery, useMutation, useQueryClient, type InfiniteData, type QueryClient } from "@tanstack/react-query";
import { mudbaseClient, MudbaseApiError } from "@/api/client";
import { POSTS_COLLECTION_ID } from "@/config/env";
import { postSchema, type Post } from "@/api/schemas";
import { useAuthStore } from "@/stores/authStore";

const PAGE_SIZE = 10;
export const FEED_QUERY_KEY = ["posts", "feed"] as const;

interface FeedPage {
  data: Post[];
  pagination: { page: number; limit: number; total: number; totalPages: number; hasMore: boolean };
}
type FeedData = InfiniteData<FeedPage, number>;

/** Paginated feed, newest first — mirrors web/src/hooks/usePostsFeed.ts's usePostsFeed. */
export function usePostsFeed() {
  return useInfiniteQuery<FeedPage, Error, FeedData, typeof FEED_QUERY_KEY, number>({
    queryKey: FEED_QUERY_KEY,
    queryFn: ({ pageParam }) =>
      mudbaseClient.listDocuments(postSchema, POSTS_COLLECTION_ID, { sort: "-createdAt", page: pageParam, limit: PAGE_SIZE }),
    initialPageParam: 1,
    getNextPageParam: (lastPage) => (lastPage.pagination.hasMore ? lastPage.pagination.page + 1 : undefined),
  });
}

/** Inserts a brand-new post at the top of the feed cache, deduping by _id so the composer's
 * optimistic insert and the realtime `db:create` echo for the same post never double up. */
export function prependPost(queryClient: QueryClient, post: Post): void {
  queryClient.setQueryData<FeedData>(FEED_QUERY_KEY, (old) => {
    if (!old) {
      return {
        pages: [{ data: [post], pagination: { page: 1, limit: PAGE_SIZE, total: 1, totalPages: 1, hasMore: false } }],
        pageParams: [1],
      };
    }
    const alreadyPresent = old.pages.some((page) => page.data.some((p) => p._id === post._id));
    if (alreadyPresent) return old;
    const [firstPage, ...restPages] = old.pages;
    if (!firstPage) return old;
    return {
      ...old,
      pages: [{ ...firstPage, data: [post, ...firstPage.data] }, ...restPages],
    };
  });
}

/** Applies an update (e.g. a new likesCount/commentsCount) to a post wherever it's cached -
 * every page of the feed's infinite query, plus the standalone post-detail document cache. */
export function updatePostEverywhere(queryClient: QueryClient, postId: string, patch: Partial<Post>): void {
  queryClient.setQueryData<FeedData>(FEED_QUERY_KEY, (old) => {
    if (!old) return old;
    return {
      ...old,
      pages: old.pages.map((page) => ({
        ...page,
        data: page.data.map((p) => (p._id === postId ? { ...p, ...patch } : p)),
      })),
    };
  });
  queryClient.setQueryData<Post>(["collection", POSTS_COLLECTION_ID, "doc", postId], (old) =>
    old ? { ...old, ...patch } : old,
  );
}

export function useCreatePost() {
  const queryClient = useQueryClient();

  const mutate = useCallback(
    async ({ content, imageUrl }: { content: string; imageUrl?: string }): Promise<Post> => {
      const user = useAuthStore.getState().user;
      if (!user || user.isAnonymous || !user.customRole) throw new MudbaseApiError("Must be signed in to post", 401);
      const authorName = `${user.firstName} ${user.lastName}`.trim();
      const created = await mudbaseClient.createDocument(postSchema, POSTS_COLLECTION_ID, {
        authorId: user.id,
        authorName,
        content,
        ...(imageUrl ? { imageUrl } : {}),
        likesCount: 0,
        commentsCount: 0,
      });
      prependPost(queryClient, created);
      return created;
    },
    [queryClient],
  );

  return useMutation({ mutationFn: mutate });
}
