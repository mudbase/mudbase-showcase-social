import { useCallback } from "react";
import { ActivityIndicator, FlatList, Text, View } from "react-native";
import { useAuth } from "@/hooks/useAuth";
import { useDocuments } from "@/hooks/useCollection";
import { useMyLikedPostIds } from "@/hooks/useLikes";
import { useMyFollowingIds } from "@/hooks/useFollows";
import { POSTS_COLLECTION_ID } from "@/config/env";
import { postSchema, type Post } from "@/api/schemas";
import { PostCard } from "@/components/feed/PostCard";

// Demo scale: one bounded page, no further pagination UI on a profile - a single showcase
// account will never accumulate enough posts to need it. Mirrors web/src/components/profile/ProfilePostList.tsx.
const PROFILE_POSTS_LIMIT = 100;

export function ProfilePostList({ userId }: { userId: string }): React.JSX.Element {
  const { user, isAuthenticated } = useAuth();
  const postsQuery = useDocuments<Post>(postSchema, POSTS_COLLECTION_ID, {
    filter: { authorId: userId },
    sort: "-createdAt",
    limit: PROFILE_POSTS_LIMIT,
  });
  const likedPostIds = useMyLikedPostIds(isAuthenticated ? user?.id : undefined);
  const followingIds = useMyFollowingIds(isAuthenticated ? user?.id : undefined);

  const renderItem = useCallback(
    ({ item }: { item: Post }) => (
      <PostCard post={item} liked={likedPostIds.data?.has(item._id) ?? false} followingAuthor={followingIds.data?.has(item.authorId) ?? false} />
    ),
    [likedPostIds.data, followingIds.data],
  );

  if (postsQuery.isLoading) {
    return (
      <View className="items-center py-10">
        <ActivityIndicator size="small" color="#4a43db" />
      </View>
    );
  }

  if (postsQuery.isError) {
    return <Text className="py-10 text-center text-sm text-destructive">Couldn&apos;t load this user&apos;s posts.</Text>;
  }

  const posts = postsQuery.data?.data ?? [];

  return (
    <FlatList
      data={posts}
      keyExtractor={(item) => item._id}
      renderItem={renderItem}
      scrollEnabled={false}
      contentContainerClassName="gap-3 pt-4"
      ListEmptyComponent={<Text className="py-10 text-center text-sm text-muted-foreground">No posts yet.</Text>}
    />
  );
}
