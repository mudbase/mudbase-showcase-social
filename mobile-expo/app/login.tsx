import { ScrollView, Text, View } from "react-native";
import { router } from "expo-router";
import { SafeAreaView } from "react-native-safe-area-context";
import { LoginForm } from "@/components/auth/LoginForm";

export default function LoginScreen(): React.JSX.Element {
  return (
    <SafeAreaView className="flex-1 bg-background" edges={["bottom"]}>
      <ScrollView contentContainerClassName="flex-grow justify-center px-6 py-10" keyboardShouldPersistTaps="handled">
        <View className="mb-8 gap-1">
          <Text className="text-3xl font-semibold text-foreground">Mudbase Social</Text>
          <Text className="text-muted-foreground">Sign in to post, like, comment, and follow.</Text>
        </View>
        {/* No manual navigation needed on success - router.back() returns to whichever screen
            (feed, post detail, a profile) triggered the sign-in redirect. */}
        <LoginForm onSuccess={() => router.back()} />
      </ScrollView>
    </SafeAreaView>
  );
}
