import { Avatar } from "@/components/ui/avatar"
import { formatRelativeTime } from "@/lib/utils"
import type { Comment } from "@/types/comment"

export function CommentList({ comments }: { comments: Comment[] }): React.JSX.Element {
  if (comments.length === 0) {
    return <p className="py-6 text-center text-sm text-muted-foreground">No comments yet - start the conversation.</p>
  }

  return (
    <ul className="space-y-4">
      {comments.map((comment) => (
        <li key={comment._id} className="flex items-start gap-3">
          <Avatar name={comment.authorName} size="sm" />
          <div className="min-w-0 flex-1 rounded-md bg-secondary/50 px-3 py-2">
            <div className="flex items-baseline justify-between gap-2">
              <p className="text-sm font-semibold">{comment.authorName}</p>
              <p className="shrink-0 text-xs text-muted-foreground">{formatRelativeTime(comment.createdAt)}</p>
            </div>
            <p className="whitespace-pre-wrap text-sm leading-relaxed">{comment.content}</p>
          </div>
        </li>
      ))}
    </ul>
  )
}
