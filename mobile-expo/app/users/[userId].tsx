import { useEffect } from "react";
import { ActivityIndicator } from "react-native";
import { router, useLocalSearchParams } from "expo-router";
import { z } from "zod";
import { SafeAreaView } from "react-native-safe-area-context";
import { ProfileScreenContent } from "@/components/profile/ProfileScreenContent";

const paramsSchema = z.object({ userId: z.string().min(1) });

export default function UserProfileScreen(): React.JSX.Element {
  const params = useLocalSearchParams();
  const parsed = paramsSchema.safeParse(params);
  const userId = parsed.success ? parsed.data.userId : undefined;

  useEffect(() => {
    if (!parsed.success) router.back();
  }, [parsed.success]);

  if (!userId) {
    return (
      <SafeAreaView className="flex-1 items-center justify-center bg-background" edges={["bottom"]}>
        <ActivityIndicator size="large" color="#4a43db" />
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView className="flex-1 bg-background" edges={["bottom"]}>
      <ProfileScreenContent userId={userId} />
    </SafeAreaView>
  );
}
