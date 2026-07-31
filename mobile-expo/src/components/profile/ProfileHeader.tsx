import { Text, View } from "react-native";
import { Avatar } from "@/components/ui/Avatar";
import { FollowButton } from "@/components/social/FollowButton";

export function ProfileHeader({
  userId,
  displayName,
  followerCount,
  followingCount,
  postCount,
  following,
}: {
  userId: string;
  displayName: string;
  followerCount: number;
  followingCount: number;
  postCount: number;
  following: boolean;
}): React.JSX.Element {
  return (
    <View className="flex-row items-center justify-between gap-4 border-b border-border pb-6">
      <View className="flex-row items-center gap-4">
        <Avatar name={displayName} size="lg" />
        <View>
          <Text className="text-xl font-semibold text-foreground">{displayName}</Text>
          <View className="mt-1 flex-row gap-4">
            <Text className="text-sm text-muted-foreground">
              <Text className="font-semibold text-foreground">{postCount}</Text> posts
            </Text>
            <Text className="text-sm text-muted-foreground">
              <Text className="font-semibold text-foreground">{followerCount}</Text> followers
            </Text>
            <Text className="text-sm text-muted-foreground">
              <Text className="font-semibold text-foreground">{followingCount}</Text> following
            </Text>
          </View>
        </View>
      </View>
      <FollowButton targetUserId={userId} targetUserName={displayName} following={following} />
    </View>
  );
}
