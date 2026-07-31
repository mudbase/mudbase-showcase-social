import { Avatar } from "@/components/ui/avatar"
import { FollowButton } from "@/components/social/FollowButton"

export function ProfileHeader({
  userId,
  displayName,
  followerCount,
  followingCount,
  postCount,
  following,
}: {
  userId: string
  displayName: string
  followerCount: number
  followingCount: number
  postCount: number
  following: boolean
}): React.JSX.Element {
  return (
    <div className="flex flex-col items-start gap-4 border-b border-border pb-6 sm:flex-row sm:items-center sm:justify-between">
      <div className="flex items-center gap-4">
        <Avatar name={displayName} size="lg" />
        <div>
          <h1 className="text-xl font-semibold tracking-tight">{displayName}</h1>
          <div className="mt-1 flex gap-4 text-sm text-muted-foreground">
            <span>
              <span className="font-semibold text-foreground">{postCount}</span> posts
            </span>
            <span>
              <span className="font-semibold text-foreground">{followerCount}</span> followers
            </span>
            <span>
              <span className="font-semibold text-foreground">{followingCount}</span> following
            </span>
          </div>
        </div>
      </div>
      <FollowButton targetUserId={userId} targetUserName={displayName} following={following} />
    </div>
  )
}
