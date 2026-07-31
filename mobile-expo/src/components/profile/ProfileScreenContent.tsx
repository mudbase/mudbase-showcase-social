import { ScrollView } from "react-native";
import { useAuth } from "@/hooks/useAuth";
import { useFollowCounts, useResolvedDisplayName } from "@/hooks/useProfileStats";
import { useMyFollowingIds } from "@/hooks/useFollows";
import { useDocuments } from "@/hooks/useCollection";
import { POSTS_COLLECTION_ID } from "@/config/env";
import { postSchema, type Post } from "@/api/schemas";
import { ProfileHeader } from "@/components/profile/ProfileHeader";
import { ProfilePostList } from "@/components/profile/ProfilePostList";

/**
 * Shared by both the "My profile" tab and `/users/[userId]` — same content,
 * the only difference is which userId is passed in (and FollowButton hides
 * itself automatically when it's the signed-in user's own id). Mirrors
 * web/src/app/users/[userId]/page.tsx.
 */
export function ProfileScreenContent({ userId }: { userId: string }): React.JSX.Element {
  const { user, isAuthenticated } = useAuth();
  const displayNameQuery = useResolvedDisplayName(userId);
  const { followerCount, followingCount } = useFollowCounts(userId);
  const followingIds = useMyFollowingIds(isAuthenticated ? user?.id : undefined);
  // Post count for the header comes from the same query ProfilePostList runs (React Query
  // dedupes identical concurrent requests), read here just for pagination.total.
  const postCountQuery = useDocuments<Post>(postSchema, POSTS_COLLECTION_ID, { filter: { authorId: userId }, limit: 1 });

  return (
    <ScrollView className="flex-1 bg-background" contentContainerClassName="gap-6 px-4 pb-8 pt-2">
      <ProfileHeader
        userId={userId}
        displayName={displayNameQuery.data ?? "Member"}
        followerCount={followerCount}
        followingCount={followingCount}
        postCount={postCountQuery.data?.pagination.total ?? 0}
        following={followingIds.data?.has(userId) ?? false}
      />
      <ProfilePostList userId={userId} />
    </ScrollView>
  );
}
