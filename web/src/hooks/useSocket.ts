"use client"

import { useEffect, useState } from "react"
import { getMudbaseSocket, type SocketStatus } from "@/lib/mudbase-socket"
import { useMudbase } from "@/lib/mudbase-provider"

export function useSocket(): { status: SocketStatus } {
  const { session } = useMudbase()
  const [status, setStatus] = useState<SocketStatus>("disconnected")

  useEffect(() => {
    const socket = getMudbaseSocket()
    if (session?.token) {
      socket.connect(session.token)
    }
    const off = socket.onStatus(setStatus)
    return off
  }, [session?.token])

  return { status }
}
