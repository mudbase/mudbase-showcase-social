"use client"

import { useEffect } from "react"
import { useQueryClient } from "@tanstack/react-query"
import { getMudbaseSocket } from "@/lib/mudbase-socket"
import { useMudbase } from "@/lib/mudbase-provider"
import { POSTS_COLLECTION_ID } from "@/lib/config"
import { prependPost, updatePostEverywhere } from "@/hooks/usePostsFeed"
import type { Post } from "@/types/post"

interface RowEvent {
  projectId: string
  collectionId: string
  action: string
  data: Post
  timestamp: string
}

/**
 * Live feed: subscribes to the `posts` collection's Socket.IO room so a post created or liked/
 * commented-on by someone else appears (or updates) immediately, with no polling - the same
 * `subscribe:collection` / `db:create` / `db:update` contract the ecommerce showcase's seller
 * dashboard uses for orders (see sockets/index.js on the Mudbase backend).
 */
export function usePostsLive(enabled: boolean): void {
  const { client } = useMudbase()
  const queryClient = useQueryClient()
  const projectId = client.getProjectId()

  useEffect(() => {
    if (!enabled) return
    const socket = getMudbaseSocket()

    const trySubscribe = (): void => {
      if (!socket.connected) return
      socket.emit("subscribe:collection", { projectId, collectionId: POSTS_COLLECTION_ID })
    }
    trySubscribe()
    const offStatus = socket.onStatus(trySubscribe)

    const onCreate = (ev: RowEvent): void => {
      if (ev.collectionId !== POSTS_COLLECTION_ID) return
      prependPost(queryClient, ev.data)
    }
    const onUpdate = (ev: RowEvent): void => {
      if (ev.collectionId !== POSTS_COLLECTION_ID) return
      updatePostEverywhere(queryClient, ev.data._id, ev.data)
    }

    const offCreate = socket.on<RowEvent>("db:create", onCreate)
    const offUpdate = socket.on<RowEvent>("db:update", onUpdate)

    return () => {
      socket.emit("unsubscribe:collection", { collectionId: POSTS_COLLECTION_ID })
      offStatus()
      offCreate()
      offUpdate()
    }
  }, [enabled, projectId, queryClient])
}
