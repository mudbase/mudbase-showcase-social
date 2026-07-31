"use client"

import { useRouter } from "next/navigation"
import { Heart } from "lucide-react"
import { useAuth } from "@/hooks/useAuth"
import { useToggleLike } from "@/hooks/useLikes"
import { cn } from "@/lib/utils"
import type { Post } from "@/types/post"

export function LikeButton({ post, liked }: { post: Post; liked: boolean }): React.JSX.Element {
  const { user, isAuthenticated } = useAuth()
  const router = useRouter()
  const toggleLike = useToggleLike(post, user?.id)

  const onClick = (): void => {
    if (!isAuthenticated) {
      router.push("/login")
      return
    }
    toggleLike.mutate()
  }

  return (
    <button
      type="button"
      onClick={onClick}
      disabled={toggleLike.isPending}
      aria-pressed={liked}
      aria-label={liked ? "Unlike post" : "Like post"}
      className={cn(
        "inline-flex items-center gap-1.5 rounded-md px-2 py-1 text-sm font-medium transition-colors disabled:opacity-60",
        liked ? "text-destructive" : "text-muted-foreground hover:text-foreground",
      )}
    >
      <Heart className={cn("h-4 w-4", liked && "fill-current")} />
      {post.likesCount}
    </button>
  )
}
