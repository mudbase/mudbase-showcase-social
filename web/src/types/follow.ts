import type { Document } from "@/lib/mudbase"

export interface Follow extends Document {
  followerId: string
  followingId: string
  followingName?: string
}
