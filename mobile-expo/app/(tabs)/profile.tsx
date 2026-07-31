import { Text, View } from "react-native";
import { router } from "expo-router";
import { SafeAreaView } from "react-native-safe-area-context";
import { LogOut } from "lucide-react-native";
import { useAuth } from "@/hooks/useAuth";
import { Button } from "@/components/ui/Button";
import { ProfileScreenContent } from "@/components/profile/ProfileScreenContent";

export default function MyProfileScreen(): React.JSX.Element {
  const { user, isAuthenticated, logout, isSubmitting } = useAuth();

  if (!isAuthenticated || !user) {
    return (
      <SafeAreaView className="flex-1 items-center justify-center gap-4 bg-background px-6" edges={["top"]}>
        <Text className="text-center text-lg font-semibold text-foreground">You're browsing as a guest</Text>
        <Text className="text-center text-sm text-muted-foreground">
          Sign in to post, like, comment, and follow other people.
        </Text>
        <Button onPress={() => router.push("/login")}>Sign in</Button>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView className="flex-1 bg-background" edges={["top"]}>
      <View className="flex-row items-center justify-end px-4 pt-2">
        <Button variant="ghost" size="sm" icon={<LogOut size={16} color="#e42545" />} isLoading={isSubmitting} onPress={() => void logout()}>
          Sign out
        </Button>
      </View>
      <ProfileScreenContent userId={user.id} />
    </SafeAreaView>
  );
}
