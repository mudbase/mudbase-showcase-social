import { Pressable, Text, View } from "react-native";
import { Link, router } from "expo-router";
import { Image } from "expo-image";
import { MessageCircle } from "lucide-react-native";
import { Card } from "@/components/ui/Card";
import { Avatar } from "@/components/ui/Avatar";
import { LikeButton } from "@/components/social/LikeButton";
import { FollowButton } from "@/components/social/FollowButton";
import { formatRelativeTime } from "@/lib/format";
import type { Post } from "@/api/schemas";

export function PostCard({
  post,
  liked,
  followingAuthor,
  linkToDetail = true,
}: {
  post: Post;
  liked: boolean;
  followingAuthor: boolean;
  linkToDetail?: boolean;
}): React.JSX.Element {
  return (
    <Card className="gap-3">
      <View className="flex-row items-start justify-between">
        <Link href={{ pathname: "/users/[userId]", params: { userId: post.authorId } }} asChild>
          <Pressable className="flex-row items-center gap-3">
            <Avatar name={post.authorName} />
            <View>
              <Text className="text-sm font-semibold leading-tight text-foreground">{post.authorName}</Text>
              <Text className="text-xs text-muted-foreground">{formatRelativeTime(post.createdAt)}</Text>
            </View>
          </Pressable>
        </Link>
        <FollowButton targetUserId={post.authorId} targetUserName={post.authorName} following={followingAuthor} />
      </View>

      <Text className="text-sm leading-relaxed text-foreground">{post.content}</Text>

      {post.imageUrl && (
        <View className="aspect-[4/3] w-full overflow-hidden rounded-md border border-border bg-secondary">
          <Image source={{ uri: post.imageUrl }} style={{ width: "100%", height: "100%" }} contentFit="cover" transition={150} />
        </View>
      )}

      <View className="flex-row items-center gap-4 pt-1">
        <LikeButton post={post} liked={liked} />
        {linkToDetail ? (
          <Pressable
            onPress={() => router.push({ pathname: "/posts/[id]", params: { id: post._id } })}
            className="flex-row items-center gap-1.5 rounded-md px-2 py-1"
            accessibilityRole="button"
            accessibilityLabel={`View ${post.commentsCount} comments`}
          >
            <MessageCircle size={16} color="#606876" />
            <Text className="text-sm font-medium text-muted-foreground">{post.commentsCount}</Text>
          </Pressable>
        ) : (
          <View className="flex-row items-center gap-1.5 px-2 py-1">
            <MessageCircle size={16} color="#606876" />
            <Text className="text-sm font-medium text-muted-foreground">{post.commentsCount}</Text>
          </View>
        )}
      </View>
    </Card>
  );
}
