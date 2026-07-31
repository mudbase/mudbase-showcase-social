import type { Document } from "@/lib/mudbase"

export interface Post extends Document {
  authorId: string
  authorName: string
  content: string
  imageUrl?: string
  likesCount: number
  commentsCount: number
}
