import Link from "next/link"
import { MessageCircle } from "lucide-react"
import { Card, CardContent, CardHeader } from "@/components/ui/card"
import { Avatar } from "@/components/ui/avatar"
import { LikeButton } from "@/components/social/LikeButton"
import { FollowButton } from "@/components/social/FollowButton"
import { formatRelativeTime } from "@/lib/utils"
import type { Post } from "@/types/post"

export function PostCard({
  post,
  liked,
  followingAuthor,
  linkToDetail = true,
}: {
  post: Post
  liked: boolean
  followingAuthor: boolean
  linkToDetail?: boolean
}): React.JSX.Element {
  return (
    <Card>
      <CardHeader className="flex-row items-start justify-between space-y-0 pb-3">
        <Link href={`/users/${post.authorId}`} className="flex items-center gap-3">
          <Avatar name={post.authorName} />
          <div>
            <p className="text-sm font-semibold leading-tight">{post.authorName}</p>
            <p className="text-xs text-muted-foreground">{formatRelativeTime(post.createdAt)}</p>
          </div>
        </Link>
        <FollowButton targetUserId={post.authorId} targetUserName={post.authorName} following={followingAuthor} />
      </CardHeader>
      <CardContent className="space-y-3 pt-0">
        <p className="whitespace-pre-wrap text-sm leading-relaxed">{post.content}</p>
        {post.imageUrl && (
          <div className="relative aspect-[4/3] w-full overflow-hidden rounded-md border border-border bg-muted">
            {/* eslint-disable-next-line @next/next/no-img-element -- arbitrary user-pasted URLs (see
                plan/build-plan.md "Known limitations"); next/image's optimizer requires an allow-listed
                remote host, which a free-form pasted URL cannot satisfy. */}
            <img src={post.imageUrl} alt="" className="h-full w-full object-cover" loading="lazy" />
          </div>
        )}
        <div className="flex items-center gap-4 pt-1">
          <LikeButton post={post} liked={liked} />
          {linkToDetail ? (
            <Link
              href={`/posts/${post._id}`}
              className="inline-flex items-center gap-1.5 rounded-md px-2 py-1 text-sm font-medium text-muted-foreground transition-colors hover:text-foreground"
            >
              <MessageCircle className="h-4 w-4" />
              {post.commentsCount}
            </Link>
          ) : (
            <span className="inline-flex items-center gap-1.5 px-2 py-1 text-sm font-medium text-muted-foreground">
              <MessageCircle className="h-4 w-4" />
              {post.commentsCount}
            </span>
          )}
        </div>
      </CardContent>
    </Card>
  )
}
