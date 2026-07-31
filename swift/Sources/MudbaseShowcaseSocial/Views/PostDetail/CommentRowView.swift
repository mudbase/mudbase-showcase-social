import SwiftUI

/// Mirrors one `<li>` in `../web/src/components/comments/CommentList.tsx`.
struct CommentRowView: View {
    let comment: Comment

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AvatarView(name: comment.authorName, size: 32)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(comment.authorName)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(Formatting.relativeTime(from: comment.createdAt))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(comment.content)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        }
    }
}
