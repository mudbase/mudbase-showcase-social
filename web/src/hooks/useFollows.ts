"use client"

import { useCallback } from "react"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { useMudbase } from "@/lib/mudbase-provider"
import { FOLLOWS_COLLECTION_ID } from "@/lib/config"
import type { Follow } from "@/types/follow"

const MY_FOLLOWING_QUERY_KEY = (userId: string) => ["follows", "mine", userId] as const
export const FOLLOWER_COUNT_KEY = (userId: string) => ["follows", "followerCount", userId] as const
export const FOLLOWING_COUNT_KEY = (userId: string) => ["follows", "followingCount", userId] as const
// Demo-scale cap, same rationale as useLikes' MINE_LIMIT.
const MINE_LIMIT = 500

/** The signed-in user's own "who am I following" ids, fetched once and reused by every
 * FollowButton on the feed (post authors) and on profile pages. */
export function useMyFollowingIds(userId: string | undefined) {
  const { client } = useMudbase()
  return useQuery<Set<string>>({
    queryKey: MY_FOLLOWING_QUERY_KEY(userId ?? ""),
    queryFn: async () => {
      const res = await client.getDocuments<Follow>(FOLLOWS_COLLECTION_ID, {
        filter: { followerId: userId },
        limit: MINE_LIMIT,
      })
      return new Set(res.data.map((f) => f.followingId))
    },
    enabled: !!userId,
  })
}

export function useToggleFollow(targetUserId: string, targetUserName: string, currentUserId: string | undefined) {
  const { client } = useMudbase()
  const queryClient = useQueryClient()

  const mutate = useCallback(async (): Promise<{ following: boolean }> => {
    if (!currentUserId) throw new Error("Must be signed in to follow a user")
    if (currentUserId === targetUserId) throw new Error("Cannot follow yourself")

    // Check-then-act against the server, same race-guard rationale as useToggleLike.
    const existing = await client.getDocuments<Follow>(FOLLOWS_COLLECTION_ID, {
      filter: { followerId: currentUserId, followingId: targetUserId },
      limit: 1,
    })
    const existingFollow = existing.data[0]

    if (existingFollow) {
      await client.deleteDocument(FOLLOWS_COLLECTION_ID, existingFollow._id)
      return { following: false }
    }

    await client.createDocument<Follow>(FOLLOWS_COLLECTION_ID, {
      followerId: currentUserId,
      followingId: targetUserId,
      followingName: targetUserName,
    })
    return { following: true }
  }, [client, currentUserId, targetUserId, targetUserName])

  return useMutation({
    mutationFn: mutate,
    onSuccess: ({ following }) => {
      if (!currentUserId) return
      queryClient.setQueryData<Set<string>>(MY_FOLLOWING_QUERY_KEY(currentUserId), (old) => {
        const next = new Set(old ?? [])
        if (following) next.add(targetUserId)
        else next.delete(targetUserId)
        return next
      })
      queryClient.invalidateQueries({ queryKey: FOLLOWER_COUNT_KEY(targetUserId) })
      queryClient.invalidateQueries({ queryKey: FOLLOWING_COUNT_KEY(currentUserId) })
    },
  })
}
