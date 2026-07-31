import { useEffect, useState } from "react";
import { getMudbaseSocket, type SocketStatus } from "@/lib/socket";

/**
 * Tracks the shared Mudbase socket's connection status for UI (e.g. a small
 * "reconnecting…" indicator). The connection itself is established by
 * authStore.initialize()/login()/logout() as soon as a token exists — this
 * hook only observes, it never calls connect()/disconnect() itself, since
 * multiple screens mount it concurrently and only one owner should manage the
 * socket's lifecycle (mirrors web/src/hooks/useSocket.ts, adapted so the
 * connect trigger lives in the auth store instead of a top-level provider
 * effect — RN has no single "app shell" context ideal for that side effect).
 */
export function useSocket(): { status: SocketStatus } {
  const [status, setStatus] = useState<SocketStatus>(getMudbaseSocket().connected ? "connected" : "disconnected");

  useEffect(() => {
    const socket = getMudbaseSocket();
    return socket.onStatus(setStatus);
  }, []);

  return { status };
}
