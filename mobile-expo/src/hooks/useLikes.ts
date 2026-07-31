import { useCallback } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { mudbaseClient, MudbaseApiError } from "@/api/client";
import { LIKES_COLLECTION_ID, POSTS_COLLECTION_ID } from "@/config/env";
import { updatePostEverywhere } from "@/hooks/usePostsFeed";
import { likeSchema, postSchema, type Post } from "@/api/schemas";

const MY_LIKES_QUERY_KEY = (userId: string) => ["likes", "mine", userId] as const;
// Demo-scale cap: this app has no pagination UI for "posts I've liked", so one bounded page
// covers every like the two provisioned accounts will ever create.
const MINE_LIMIT = 500;

/** The signed-in user's own liked-post ids, fetched once and reused by every LikeButton in the
 * feed - avoids one query per rendered post. */
export function useMyLikedPostIds(userId: string | undefined) {
  return useQuery<Set<string>>({
    queryKey: MY_LIKES_QUERY_KEY(userId ?? ""),
    queryFn: async () => {
      const res = await mudbaseClient.listDocuments(likeSchema, LIKES_COLLECTION_ID, {
        filter: { userId },
        limit: MINE_LIMIT,
      });
      return new Set(res.data.map((like) => like.postId));
    },
    enabled: !!userId,
  });
}

export function useToggleLike(post: Post, userId: string | undefined) {
  const queryClient = useQueryClient();

  const mutate = useCallback(async (): Promise<{ liked: boolean; likesCount: number }> => {
    if (!userId) throw new MudbaseApiError("Must be signed in to like a post", 401);

    // Check-then-act against the server (not just the local cache) right before mutating -
    // reasonable protection against a double-tap race creating two like rows for the same
    // (postId, userId), since this collection type has no compound unique index (same guard
    // web/src/hooks/useLikes.ts uses).
    const existing = await mudbaseClient.listDocuments(likeSchema, LIKES_COLLECTION_ID, {
      filter: { postId: post._id, userId },
      limit: 1,
    });
    const existingLike = existing.data[0];

    if (existingLike) {
      await mudbaseClient.deleteDocument(LIKES_COLLECTION_ID, existingLike._id);
      const likesCount = Math.max(0, post.likesCount - 1);
      await mudbaseClient.updateDocument(postSchema, POSTS_COLLECTION_ID, post._id, { likesCount });
      return { liked: false, likesCount };
    }

    await mudbaseClient.createDocument(likeSchema, LIKES_COLLECTION_ID, { postId: post._id, userId });
    const likesCount = post.likesCount + 1;
    await mudbaseClient.updateDocument(postSchema, POSTS_COLLECTION_ID, post._id, { likesCount });
    return { liked: true, likesCount };
  }, [post, userId]);

  return useMutation({
    mutationFn: mutate,
    onSuccess: ({ liked, likesCount }) => {
      if (!userId) return;
      updatePostEverywhere(queryClient, post._id, { likesCount });
      queryClient.setQueryData<Set<string>>(MY_LIKES_QUERY_KEY(userId), (old) => {
        const next = new Set(old ?? []);
        if (liked) next.add(post._id);
        else next.delete(post._id);
        return next;
      });
    },
  });
}
