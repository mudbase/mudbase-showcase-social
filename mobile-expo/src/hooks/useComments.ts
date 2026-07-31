import { useCallback } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { mudbaseClient, MudbaseApiError } from "@/api/client";
import { useDocuments } from "@/hooks/useCollection";
import { COMMENTS_COLLECTION_ID, POSTS_COLLECTION_ID } from "@/config/env";
import { updatePostEverywhere } from "@/hooks/usePostsFeed";
import { commentSchema, postSchema, type Comment } from "@/api/schemas";
import { useAuthStore } from "@/stores/authStore";

/** Oldest first, like a normal comment thread - newest replies land at the bottom. */
export function useComments(postId: string) {
  return useDocuments<Comment>(commentSchema, COMMENTS_COLLECTION_ID, { filter: { postId }, sort: "createdAt", limit: 200 });
}

export function useCreateComment(postId: string) {
  const queryClient = useQueryClient();

  const mutate = useCallback(
    async (content: string): Promise<Comment> => {
      const user = useAuthStore.getState().user;
      if (!user || user.isAnonymous || !user.customRole) {
        throw new MudbaseApiError("Must be signed in to comment", 401);
      }
      const authorName = `${user.firstName} ${user.lastName}`.trim();

      const created = await mudbaseClient.createDocument(commentSchema, COMMENTS_COLLECTION_ID, {
        postId,
        authorId: user.id,
        authorName,
        content,
      });

      // Re-read the post immediately before incrementing so a burst of concurrent comments
      // doesn't have both writers increment from the same stale count - same check-then-act
      // guard style as useToggleLike/useToggleFollow.
      const currentPost = await mudbaseClient.getDocument(postSchema, POSTS_COLLECTION_ID, postId);
      const commentsCount = currentPost.commentsCount + 1;
      await mudbaseClient.updateDocument(postSchema, POSTS_COLLECTION_ID, postId, { commentsCount });
      updatePostEverywhere(queryClient, postId, { commentsCount });

      return created;
    },
    [postId, queryClient],
  );

  return useMutation({
    mutationFn: mutate,
    onSuccess: () => {
      // Prefix-invalidate every query for this collection rather than reconstructing the exact
      // key useDocuments built - simpler, and still only touches this collection's cache.
      void queryClient.invalidateQueries({ queryKey: ["collection", COMMENTS_COLLECTION_ID] });
    },
  });
}
