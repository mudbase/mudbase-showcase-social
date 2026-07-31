import SwiftUI

/// Mirrors `../web/src/components/ui/avatar.tsx` — an initials-based avatar since there's no
/// profile-photo field anywhere in this data model.
struct AvatarView: View {
    let name: String
    var size: CGFloat = 40

    private var initials: String {
        let parts = name
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map(String.init)
        let joined = parts.joined().uppercased()
        return joined.isEmpty ? "?" : joined
    }

    private var backgroundColor: Color {
        let hash = name.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        let hue = Double(hash % 360) / 360.0
        return Color(hue: hue, saturation: 0.45, brightness: 0.55)
    }

    var body: some View {
        Circle()
            .fill(backgroundColor)
            .frame(width: size, height: size)
            .overlay(
                Text(initials)
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(.white)
            )
    }
}
