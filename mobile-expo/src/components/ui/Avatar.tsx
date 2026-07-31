import { Text, View } from "react-native";
import { initials } from "@/lib/format";

const SIZE_PX: Record<"sm" | "md" | "lg", number> = { sm: 32, md: 40, lg: 56 };
const FONT_SIZE: Record<"sm" | "md" | "lg", number> = { sm: 12, md: 14, lg: 18 };

// Deterministic hue from name so the same person always renders the same color across screens,
// without needing a stored avatar/color field on any collection (none of posts/comments/likes/
// follows carry one — see ../plan/build-plan.md "Data model").
function hueForName(name: string): number {
  let hash = 0;
  for (let i = 0; i < name.length; i += 1) {
    hash = (hash * 31 + name.charCodeAt(i)) % 360;
  }
  return hash;
}

export function Avatar({ name, size = "md" }: { name: string; size?: "sm" | "md" | "lg" }): React.JSX.Element {
  const px = SIZE_PX[size];
  const hue = hueForName(name || "?");
  return (
    <View
      className="items-center justify-center rounded-full"
      style={{ width: px, height: px, backgroundColor: `hsl(${hue}, 60%, 45%)` }}
      accessibilityElementsHidden
      importantForAccessibility="no-hide-descendants"
    >
      <Text style={{ fontSize: FONT_SIZE[size] }} className="font-semibold text-white">
        {initials(name)}
      </Text>
    </View>
  );
}
