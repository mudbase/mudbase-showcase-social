import { useEffect } from "react";
import { ActivityIndicator, ScrollView, Text, View } from "react-native";
import { router, useLocalSearchParams } from "expo-router";
import { z } from "zod";
import { SafeAreaView } from "react-native-safe-area-context";
import { useAuth } from "@/hooks/useAuth";
import { useDocument } from "@/hooks/useCollection";
import { useComments } from "@/hooks/useComments";
import { useMyLikedPostIds } from "@/hooks/useLikes";
import { useMyFollowingIds } from "@/hooks/useFollows";
import { POSTS_COLLECTION_ID } from "@/config/env";
import { postSchema } from "@/api/schemas";
import { PostCard } from "@/components/feed/PostCard";
import { CommentList } from "@/components/comments/CommentList";
import { CommentComposer } from "@/components/comments/CommentComposer";

const paramsSchema = z.object({ id: z.string().min(1) });

export default function PostDetailScreen(): React.JSX.Element {
  const params = useLocalSearchParams();
  const parsed = paramsSchema.safeParse(params);
  const id = parsed.success ? parsed.data.id : undefined;
  const { user, isAuthenticated } = useAuth();

  const postQuery = useDocument(postSchema, POSTS_COLLECTION_ID, id);
  const commentsQuery = useComments(id ?? "");
  const likedPostIds = useMyLikedPostIds(isAuthenticated ? user?.id : undefined);
  const followingIds = useMyFollowingIds(isAuthenticated ? user?.id : undefined);

  useEffect(() => {
    if (!parsed.success) router.back();
  }, [parsed.success]);

  if (postQuery.isLoading || !id) {
    return (
      <SafeAreaView className="flex-1 items-center justify-center bg-background" edges={["bottom"]}>
        <ActivityIndicator size="large" color="#4a43db" />
      </SafeAreaView>
    );
  }

  if (postQuery.isError || !postQuery.data) {
    return (
      <SafeAreaView className="flex-1 items-center justify-center bg-background px-6" edges={["bottom"]}>
        <Text className="text-center text-sm text-destructive">This post isn&apos;t available.</Text>
      </SafeAreaView>
    );
  }

  const post = postQuery.data;

  return (
    <SafeAreaView className="flex-1 bg-background" edges={["bottom"]}>
      <ScrollView contentContainerClassName="gap-6 px-4 py-4" keyboardShouldPersistTaps="handled">
        <PostCard
          post={post}
          liked={likedPostIds.data?.has(post._id) ?? false}
          followingAuthor={followingIds.data?.has(post.authorId) ?? false}
          linkToDetail={false}
        />
        <View className="gap-4">
          <Text className="text-sm font-semibold text-muted-foreground">Comments</Text>
          <CommentComposer postId={post._id} />
          {commentsQuery.isLoading ? (
            <View className="items-center py-6">
              <ActivityIndicator size="small" color="#4a43db" />
            </View>
          ) : (
            <CommentList comments={commentsQuery.data?.data ?? []} />
          )}
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}
