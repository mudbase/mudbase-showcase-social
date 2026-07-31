import { io, type Socket } from "socket.io-client";
import { MUDBASE_URL } from "@/config/env";

/**
 * Ported faithfully from web/src/lib/mudbase-socket.ts — same
 * `subscribe:collection` / `db:create` / `db:update` Socket.IO contract,
 * confirmed live against this exact project in web/plan/build-plan.md's "Live
 * smoke test results". `socket.io-client` works unmodified in React Native:
 * RN provides the `WebSocket` and `XMLHttpRequest` globals the "websocket" and
 * "polling" transports need, so no RN-specific transport config is required.
 */
export type SocketStatus = "disconnected" | "connecting" | "connected" | "error";

export class MudbaseSocket {
  private socket: Socket | null = null;
  private statusListeners: Set<(s: SocketStatus) => void> = new Set();
  private connectedToken: string | null = null;

  connect(token: string): void {
    // Guest browsing connects anonymously, then the same session often logs in - without
    // checking the token, this early-return would leave the socket permanently authenticated as
    // the stale anonymous identity, since "already connected" looked sufficient on its own.
    if (this.socket?.connected && this.connectedToken === token) return;
    if (this.socket) this.socket.disconnect();

    this.connectedToken = token;
    this.socket = io(MUDBASE_URL, {
      path: "/socket.io/",
      transports: ["websocket", "polling"],
      auth: { token },
      reconnection: true,
      reconnectionDelay: 1000,
      reconnectionDelayMax: 30000,
      reconnectionAttempts: 10,
    });

    this.socket.on("connect", () => this.emitStatus("connected"));
    this.socket.on("disconnect", () => this.emitStatus("disconnected"));
    this.socket.on("connect_error", () => this.emitStatus("error"));
  }

  disconnect(): void {
    this.socket?.disconnect();
    this.socket = null;
    this.connectedToken = null;
  }

  get connected(): boolean {
    return this.socket?.connected ?? false;
  }

  onStatus(cb: (s: SocketStatus) => void): () => void {
    this.statusListeners.add(cb);
    return () => this.statusListeners.delete(cb);
  }

  private emitStatus(s: SocketStatus): void {
    this.statusListeners.forEach((cb) => cb(s));
  }

  emit(event: string, data?: unknown): void {
    if (!this.socket?.connected) return;
    if (data !== undefined) this.socket.emit(event, data);
    else this.socket.emit(event);
  }

  on<T = unknown>(event: string, handler: (data: T) => void): () => void {
    const wrapped = (payload: unknown): void => handler(payload as T);
    this.socket?.on(event, wrapped);
    return () => this.socket?.off(event, wrapped);
  }
}

let _socket: MudbaseSocket | null = null;

export function getMudbaseSocket(): MudbaseSocket {
  if (!_socket) _socket = new MudbaseSocket();
  return _socket;
}
