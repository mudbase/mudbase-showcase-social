import { Pressable, Text } from "react-native";
import { router } from "expo-router";
import { Heart } from "lucide-react-native";
import { useAuth } from "@/hooks/useAuth";
import { useToggleLike } from "@/hooks/useLikes";
import { cn } from "@/lib/cn";
import type { Post } from "@/api/schemas";

export function LikeButton({ post, liked }: { post: Post; liked: boolean }): React.JSX.Element {
  const { user, isAuthenticated } = useAuth();
  const toggleLike = useToggleLike(post, user?.id);

  const onPress = (): void => {
    if (!isAuthenticated) {
      router.push("/login");
      return;
    }
    toggleLike.mutate();
  };

  return (
    <Pressable
      onPress={onPress}
      disabled={toggleLike.isPending}
      accessibilityRole="button"
      accessibilityState={{ disabled: toggleLike.isPending, selected: liked }}
      accessibilityLabel={liked ? "Unlike post" : "Like post"}
      className={cn(
        "flex-row items-center gap-1.5 rounded-md px-2 py-1",
        toggleLike.isPending && "opacity-60",
      )}
    >
      <Heart size={16} color={liked ? "#e42545" : "#606876"} fill={liked ? "#e42545" : "transparent"} />
      <Text className={cn("text-sm font-medium", liked ? "text-destructive" : "text-muted-foreground")}>
        {post.likesCount}
      </Text>
    </Pressable>
  );
}
