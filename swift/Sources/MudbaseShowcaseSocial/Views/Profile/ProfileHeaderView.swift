import SwiftUI

/// Mirrors `../web/src/components/profile/ProfileHeader.tsx`.
struct ProfileHeaderView: View {
    let displayName: String
    let followerCount: Int
    let followingCount: Int
    let postCount: Int
    let showFollowButton: Bool
    let isFollowing: Bool
    let isFollowActionDisabled: Bool
    let onToggleFollow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                AvatarView(name: displayName, size: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        .font(.title2.weight(.semibold))
                    HStack(spacing: 16) {
                        statistic(value: postCount, label: "posts")
                        statistic(value: followerCount, label: "followers")
                        statistic(value: followingCount, label: "following")
                    }
                }
                Spacer()
            }

            if showFollowButton {
                FollowButtonView(isFollowing: isFollowing, isDisabled: isFollowActionDisabled, action: onToggleFollow)
            }
        }
        .padding(.bottom, 16)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private func statistic(value: Int, label: String) -> some View {
        HStack(spacing: 4) {
            Text("\(value)").font(.subheadline.weight(.semibold))
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }
}
