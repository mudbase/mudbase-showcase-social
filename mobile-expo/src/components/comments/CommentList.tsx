import { Text, View } from "react-native";
import { Avatar } from "@/components/ui/Avatar";
import { formatRelativeTime } from "@/lib/format";
import type { Comment } from "@/api/schemas";

export function CommentList({ comments }: { comments: Comment[] }): React.JSX.Element {
  if (comments.length === 0) {
    return <Text className="py-6 text-center text-sm text-muted-foreground">No comments yet — start the conversation.</Text>;
  }

  return (
    <View className="gap-3">
      {comments.map((comment) => (
        <View key={comment._id} className="flex-row items-start gap-3">
          <Avatar name={comment.authorName} size="sm" />
          <View className="min-w-0 flex-1 rounded-md bg-secondary px-3 py-2">
            <View className="flex-row items-baseline justify-between gap-2">
              <Text className="text-sm font-semibold text-foreground">{comment.authorName}</Text>
              <Text className="shrink-0 text-xs text-muted-foreground">{formatRelativeTime(comment.createdAt)}</Text>
            </View>
            <Text className="text-sm leading-relaxed text-foreground">{comment.content}</Text>
          </View>
        </View>
      ))}
    </View>
  );
}
