import { router } from "expo-router";
import { useAuth } from "@/hooks/useAuth";
import { useToggleFollow } from "@/hooks/useFollows";
import { Button } from "@/components/ui/Button";

export function FollowButton({
  targetUserId,
  targetUserName,
  following,
}: {
  targetUserId: string;
  targetUserName: string;
  following: boolean;
}): React.JSX.Element | null {
  const { user, isAuthenticated } = useAuth();
  const toggleFollow = useToggleFollow(targetUserId, targetUserName, user?.id);

  // Never render a follow button for the signed-in user's own posts/profile.
  if (isAuthenticated && user?.id === targetUserId) return null;

  const onPress = (): void => {
    if (!isAuthenticated) {
      router.push("/login");
      return;
    }
    toggleFollow.mutate();
  };

  return (
    <Button size="sm" variant={following ? "outline" : "primary"} isLoading={toggleFollow.isPending} onPress={onPress}>
      {following ? "Following" : "Follow"}
    </Button>
  );
}
