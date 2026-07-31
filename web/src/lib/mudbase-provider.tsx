"use client"

import React, { createContext, useContext, useEffect, useState, useCallback } from "react"
import { MudbaseClient, initMudbase, type MudbaseConfig, type SessionResponse } from "./mudbase"
import { useSocket } from "@/hooks/useSocket"

interface MudbaseContextValue {
  client: MudbaseClient
  session: SessionResponse | null
  loading: boolean
  refreshSession: () => Promise<void>
}

const MudbaseContext = createContext<MudbaseContextValue | null>(null)

export function MudbaseProvider({
  children,
  config,
}: {
  children: React.ReactNode
  config: MudbaseConfig
}): React.JSX.Element {
  const [client] = useState<MudbaseClient>(() => initMudbase(config))
  const [session, setSession] = useState<SessionResponse | null>(null)
  const [loading, setLoading] = useState<boolean>(true)

  const refreshSession = useCallback(async (): Promise<void> => {
    try {
      const s = await client.getSession()
      setSession(s)
    } catch {
      setSession(null)
      client.clearToken()
    }
  }, [client])

  useEffect(() => {
    const establish = async (): Promise<void> => {
      if (client.getToken()) {
        await refreshSession()
        setLoading(false)
        return
      }
      // Guest browsing: an anonymous session lets the feed's "authenticated"-role read
      // permission resolve without forcing signup (verified live: every collection read 401s
      // with no auth at all, even with the project's own publishable key sent as X-API-Key).
      // Posting/liking/commenting/following still require a real, verified "customer" account -
      // see useAuth and each hook's guard.
      try {
        await client.loginAnonymous()
        await refreshSession()
      } catch {
        setSession(null)
      } finally {
        setLoading(false)
      }
    }
    void establish()
  }, [client, refreshSession])

  return (
    <MudbaseContext.Provider value={{ client, session, loading, refreshSession }}>
      <SocketBridge />
      {children}
    </MudbaseContext.Provider>
  )
}

/**
 * useSocket() establishes the Socket.IO connection for the current session but has to run
 * inside the context it just created, so it's mounted here rather than exposed as a public
 * "wire this up yourself" hook - usePostsLive and anything else that subscribes to a room
 * depends on this connection already existing.
 */
function SocketBridge(): null {
  useSocket()
  return null
}

export function useMudbase(): MudbaseContextValue {
  const ctx = useContext(MudbaseContext)
  if (!ctx) throw new Error("useMudbase must be used inside <MudbaseProvider>")
  return ctx
}
