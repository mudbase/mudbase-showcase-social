"use client"

import { useRouter } from "next/navigation"
import { useAuth } from "@/hooks/useAuth"
import { useToggleFollow } from "@/hooks/useFollows"
import { Button } from "@/components/ui/button"

export function FollowButton({
  targetUserId,
  targetUserName,
  following,
}: {
  targetUserId: string
  targetUserName: string
  following: boolean
}): React.JSX.Element | null {
  const { user, isAuthenticated } = useAuth()
  const router = useRouter()
  const toggleFollow = useToggleFollow(targetUserId, targetUserName, user?.id)

  // Never render a follow button for the signed-in user's own posts/profile.
  if (isAuthenticated && user?.id === targetUserId) return null

  const onClick = (): void => {
    if (!isAuthenticated) {
      router.push("/login")
      return
    }
    toggleFollow.mutate()
  }

  return (
    <Button type="button" size="sm" variant={following ? "outline" : "default"} disabled={toggleFollow.isPending} onClick={onClick}>
      {following ? "Following" : "Follow"}
    </Button>
  )
}
