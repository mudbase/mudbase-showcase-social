import { useCallback, useMemo, type ReactElement } from "react";
import { ActivityIndicator, FlatList, RefreshControl, Text, View } from "react-native";
import { useAuth } from "@/hooks/useAuth";
import { usePostsFeed } from "@/hooks/usePostsFeed";
import { usePostsLive } from "@/hooks/usePostsLive";
import { useMyLikedPostIds } from "@/hooks/useLikes";
import { useMyFollowingIds } from "@/hooks/useFollows";
import { PostCard } from "@/components/feed/PostCard";
import type { Post } from "@/api/schemas";

export function FeedList({ ListHeaderComponent }: { ListHeaderComponent?: ReactElement }): React.JSX.Element {
  const { user, isAuthenticated } = useAuth();
  const feed = usePostsFeed();
  usePostsLive(true);
  const likedPostIds = useMyLikedPostIds(isAuthenticated ? user?.id : undefined);
  const followingIds = useMyFollowingIds(isAuthenticated ? user?.id : undefined);

  const posts = useMemo<Post[]>(() => feed.data?.pages.flatMap((page) => page.data) ?? [], [feed.data]);

  const onEndReached = useCallback(() => {
    if (feed.hasNextPage && !feed.isFetchingNextPage) void feed.fetchNextPage();
  }, [feed]);

  const renderItem = useCallback(
    ({ item }: { item: Post }) => (
      <PostCard post={item} liked={likedPostIds.data?.has(item._id) ?? false} followingAuthor={followingIds.data?.has(item.authorId) ?? false} />
    ),
    [likedPostIds.data, followingIds.data],
  );

  const emptyState = feed.isLoading ? (
    <View className="items-center justify-center py-16">
      <ActivityIndicator size="large" color="#4a43db" />
    </View>
  ) : feed.isError ? (
    <View className="items-center px-6 py-16">
      <Text className="text-center text-sm text-destructive">Couldn&apos;t load the feed. Pull down to retry.</Text>
    </View>
  ) : (
    <View className="items-center py-16">
      <Text className="text-sm text-muted-foreground">No posts yet — be the first to share something.</Text>
    </View>
  );

  return (
    <FlatList
      data={posts}
      keyExtractor={(item) => item._id}
      renderItem={renderItem}
      ListHeaderComponent={ListHeaderComponent}
      contentContainerClassName="gap-3 px-4 pb-8"
      onEndReached={onEndReached}
      onEndReachedThreshold={0.4}
      refreshControl={
        <RefreshControl refreshing={feed.isRefetching && !feed.isFetchingNextPage} onRefresh={() => void feed.refetch()} tintColor="#4a43db" />
      }
      ListEmptyComponent={emptyState}
      ListFooterComponent={
        feed.isFetchingNextPage ? (
          <View className="py-4">
            <ActivityIndicator size="small" color="#4a43db" />
          </View>
        ) : null
      }
    />
  );
}
