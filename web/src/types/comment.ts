import type { Document } from "@/lib/mudbase"

export interface Comment extends Document {
  postId: string
  authorId: string
  authorName: string
  content: string
}
