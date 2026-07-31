import type { Document } from "@/lib/mudbase"

export interface Like extends Document {
  postId: string
  userId: string
}
