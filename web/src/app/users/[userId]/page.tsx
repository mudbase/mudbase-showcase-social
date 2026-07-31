"use client"

import { useParams } from "next/navigation"
import { useAuth } from "@/hooks/useAuth"
import { useFollowCounts, useResolvedDisplayName } from "@/hooks/useProfileStats"
import { useMyFollowingIds } from "@/hooks/useFollows"
import { useDocuments } from "@/hooks/useCollection"
import { POSTS_COLLECTION_ID } from "@/lib/config"
import { ProfileHeader } from "@/components/profile/ProfileHeader"
import { ProfilePostList } from "@/components/profile/ProfilePostList"
import type { Post } from "@/types/post"

export default function UserProfilePage(): React.JSX.Element {
  const params = useParams<{ userId: string }>()
  const userId = params.userId
  const { user, isAuthenticated } = useAuth()

  const displayNameQuery = useResolvedDisplayName(userId)
  const { followerCount, followingCount } = useFollowCounts(userId)
  const followingIds = useMyFollowingIds(isAuthenticated ? user?.id : undefined)
  // Post count for the header comes from the same query ProfilePostList runs (React Query
  // dedupes identical concurrent requests), read here just for pagination.total.
  const postCountQuery = useDocuments<Post>(POSTS_COLLECTION_ID, { filter: { authorId: userId }, limit: 1 })

  return (
    <div className="container max-w-2xl space-y-6 py-8">
      <ProfileHeader
        userId={userId}
        displayName={displayNameQuery.data ?? "Member"}
        followerCount={followerCount}
        followingCount={followingCount}
        postCount={postCountQuery.data?.pagination.total ?? 0}
        following={followingIds.data?.has(userId) ?? false}
      />
      <ProfilePostList userId={userId} />
    </div>
  )
}
