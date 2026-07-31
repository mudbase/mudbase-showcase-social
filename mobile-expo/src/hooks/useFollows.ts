import { useCallback } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { mudbaseClient, MudbaseApiError } from "@/api/client";
import { FOLLOWS_COLLECTION_ID } from "@/config/env";
import { followSchema } from "@/api/schemas";

const MY_FOLLOWING_QUERY_KEY = (userId: string) => ["follows", "mine", userId] as const;
export const FOLLOWER_COUNT_KEY = (userId: string) => ["follows", "followerCount", userId] as const;
export const FOLLOWING_COUNT_KEY = (userId: string) => ["follows", "followingCount", userId] as const;
// Demo-scale cap, same rationale as useLikes' MINE_LIMIT.
const MINE_LIMIT = 500;

/** The signed-in user's own "who am I following" ids, fetched once and reused by every
 * FollowButton on the feed (post authors) and on profile screens. */
export function useMyFollowingIds(userId: string | undefined) {
  return useQuery<Set<string>>({
    queryKey: MY_FOLLOWING_QUERY_KEY(userId ?? ""),
    queryFn: async () => {
      const res = await mudbaseClient.listDocuments(followSchema, FOLLOWS_COLLECTION_ID, {
        filter: { followerId: userId },
        limit: MINE_LIMIT,
      });
      return new Set(res.data.map((f) => f.followingId));
    },
    enabled: !!userId,
  });
}

export function useToggleFollow(targetUserId: string, targetUserName: string, currentUserId: string | undefined) {
  const queryClient = useQueryClient();

  const mutate = useCallback(async (): Promise<{ following: boolean }> => {
    if (!currentUserId) throw new MudbaseApiError("Must be signed in to follow a user", 401);
    if (currentUserId === targetUserId) throw new MudbaseApiError("Cannot follow yourself", 400);

    // Check-then-act against the server, same race-guard rationale as useToggleLike.
    const existing = await mudbaseClient.listDocuments(followSchema, FOLLOWS_COLLECTION_ID, {
      filter: { followerId: currentUserId, followingId: targetUserId },
      limit: 1,
    });
    const existingFollow = existing.data[0];

    if (existingFollow) {
      await mudbaseClient.deleteDocument(FOLLOWS_COLLECTION_ID, existingFollow._id);
      return { following: false };
    }

    await mudbaseClient.createDocument(followSchema, FOLLOWS_COLLECTION_ID, {
      followerId: currentUserId,
      followingId: targetUserId,
      followingName: targetUserName,
    });
    return { following: true };
  }, [currentUserId, targetUserId, targetUserName]);

  return useMutation({
    mutationFn: mutate,
    onSuccess: ({ following }) => {
      if (!currentUserId) return;
      queryClient.setQueryData<Set<string>>(MY_FOLLOWING_QUERY_KEY(currentUserId), (old) => {
        const next = new Set(old ?? []);
        if (following) next.add(targetUserId);
        else next.delete(targetUserId);
        return next;
      });
      void queryClient.invalidateQueries({ queryKey: FOLLOWER_COUNT_KEY(targetUserId) });
      void queryClient.invalidateQueries({ queryKey: FOLLOWING_COUNT_KEY(currentUserId) });
    },
  });
}
