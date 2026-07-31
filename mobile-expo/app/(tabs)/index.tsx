import { Text, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { PostComposer } from "@/components/feed/PostComposer";
import { FeedList } from "@/components/feed/FeedList";

export default function FeedScreen(): React.JSX.Element {
  return (
    <SafeAreaView className="flex-1 bg-background" edges={["top"]}>
      <FeedList
        ListHeaderComponent={
          <View className="gap-3 pb-3 pt-2">
            <View className="gap-1">
              <Text className="text-2xl font-semibold text-foreground">Feed</Text>
              <Text className="text-sm text-muted-foreground">
                Every post, like, comment, and follow here is served by a real Mudbase project — no custom backend.
              </Text>
            </View>
            <PostComposer />
          </View>
        }
      />
    </SafeAreaView>
  );
}
