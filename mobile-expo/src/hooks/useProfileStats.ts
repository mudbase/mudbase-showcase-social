import { useQuery } from "@tanstack/react-query";
import { mudbaseClient } from "@/api/client";
import { FOLLOWS_COLLECTION_ID, POSTS_COLLECTION_ID } from "@/config/env";
import { FOLLOWER_COUNT_KEY, FOLLOWING_COUNT_KEY } from "@/hooks/useFollows";
import { followSchema, postSchema } from "@/api/schemas";

/** Counts are read via `pagination.total` on a limit:1 query rather than pulling every row -
 * cheap, and correct regardless of how many follow/post rows exist. */
export function useFollowCounts(userId: string | undefined) {
  const followers = useQuery<number>({
    queryKey: FOLLOWER_COUNT_KEY(userId ?? ""),
    queryFn: async () => {
      const res = await mudbaseClient.listDocuments(followSchema, FOLLOWS_COLLECTION_ID, {
        filter: { followingId: userId },
        limit: 1,
      });
      return res.pagination.total;
    },
    enabled: !!userId,
  });

  const following = useQuery<number>({
    queryKey: FOLLOWING_COUNT_KEY(userId ?? ""),
    queryFn: async () => {
      const res = await mudbaseClient.listDocuments(followSchema, FOLLOWS_COLLECTION_ID, {
        filter: { followerId: userId },
        limit: 1,
      });
      return res.pagination.total;
    },
    enabled: !!userId,
  });

  return {
    followerCount: followers.data ?? 0,
    followingCount: following.data ?? 0,
    isLoading: followers.isLoading || following.isLoading,
  };
}

/** A profile screen has no `users` collection to read a display name from (see
 * ../plan/build-plan.md "Data model") - every name in this app is denormalized onto the row
 * that references it. This resolves the best available name for a given userId: their most
 * recent post's authorName, or failing that the followingName recorded by anyone who follows
 * them, or a generic fallback. Ported from web/src/hooks/useProfileStats.ts. */
export function useResolvedDisplayName(userId: string | undefined) {
  return useQuery<string>({
    queryKey: ["profile", "displayName", userId ?? ""],
    queryFn: async () => {
      const posts = await mudbaseClient.listDocuments(postSchema, POSTS_COLLECTION_ID, {
        filter: { authorId: userId },
        sort: "-createdAt",
        limit: 1,
      });
      const fromPost = posts.data[0]?.authorName;
      if (fromPost) return fromPost;

      const follows = await mudbaseClient.listDocuments(followSchema, FOLLOWS_COLLECTION_ID, {
        filter: { followingId: userId, followingName: { $exists: true, $ne: "" } },
        limit: 1,
      });
      const fromFollow = follows.data[0]?.followingName;
      if (fromFollow) return fromFollow;

      return "Member";
    },
    enabled: !!userId,
  });
}
