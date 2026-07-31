import { Tabs } from "expo-router";
import { Home, User } from "lucide-react-native";
import type { ColorValue } from "react-native";

const FALLBACK_ICON_COLOR = "#181c25";

/**
 * `Tabs.Screen`'s `tabBarIcon` hands back React Navigation's broader
 * `ColorValue`, while lucide-react-native icons only accept a plain `string`.
 * Every tint color configured below (`tabBarActiveTintColor`/
 * `tabBarInactiveTintColor`) is always a literal hex string, so this narrows
 * safely without a cast — same pattern the sibling ecommerce mobile port uses.
 */
function toIconColor(color: ColorValue): string {
  return typeof color === "string" ? color : FALLBACK_ICON_COLOR;
}

export default function TabsLayout(): React.JSX.Element {
  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: "#4a43db",
        tabBarInactiveTintColor: "#606876",
      }}
    >
      <Tabs.Screen
        name="index"
        options={{ title: "Feed", tabBarIcon: ({ color, size }) => <Home color={toIconColor(color)} size={size} /> }}
      />
      <Tabs.Screen
        name="profile"
        options={{ title: "Profile", tabBarIcon: ({ color, size }) => <User color={toIconColor(color)} size={size} /> }}
      />
    </Tabs>
  );
}
