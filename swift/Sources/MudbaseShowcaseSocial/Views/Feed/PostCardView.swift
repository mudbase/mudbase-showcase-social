import SwiftUI

/// Mirrors `../web/src/components/feed/PostCard.tsx`. `NavigationLink`s for the author row and the
/// comment-count row are siblings of the Like/Follow buttons, not wrappers around them — the same
/// structure the web version has (only the avatar/name link to `/users/[userId]`, only the
/// comment-count link to `/posts/[id]`, Like/Follow are separate) — so a tap on Like/Follow never
/// also triggers navigation.
struct PostCardView: View {
    let post: Post
    let liked: Bool
    let isFollowingAuthor: Bool
    /// Hidden for the signed-in user's own posts, matching `FollowButton`'s own guard.
    let showFollowButton: Bool
    /// False on the post detail screen itself (already there — matches `linkToDetail = false`).
    var linkToDetail: Bool = true
    let isLikeActionDisabled: Bool
    let isFollowActionDisabled: Bool
    let onToggleLike: () -> Void
    let onToggleFollow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                NavigationLink(value: UserReference(userId: post.authorId)) {
                    HStack(spacing: 10) {
                        AvatarView(name: post.authorName)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(post.authorName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(Formatting.relativeTime(from: post.createdAt))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                if showFollowButton {
                    FollowButtonView(isFollowing: isFollowingAuthor, isDisabled: isFollowActionDisabled, action: onToggleFollow)
                }
            }

            Text(post.content)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if let imageUrlString = post.imageUrl, let url = URL(string: imageUrlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(4.0 / 3.0, contentMode: .fill)
                            .clipped()
                    case .failure:
                        Color.secondary.opacity(0.1)
                            .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                    case .empty:
                        Color.secondary.opacity(0.1)
                            .overlay(ProgressView())
                    @unknown default:
                        Color.secondary.opacity(0.1)
                    }
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(4.0 / 3.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            HStack(spacing: 20) {
                LikeButtonView(liked: liked, count: post.likesCount, isDisabled: isLikeActionDisabled, action: onToggleLike)

                if linkToDetail {
                    NavigationLink(value: PostReference(postId: post.id)) {
                        Label("\(post.commentsCount)", systemImage: "bubble.right")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Label("\(post.commentsCount)", systemImage: "bubble.right")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.secondary.opacity(0.15)))
    }
}
