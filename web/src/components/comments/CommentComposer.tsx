"use client"

import { useForm } from "react-hook-form"
import { zodResolver } from "@hookform/resolvers/zod"
import { z } from "zod"
import { useRouter } from "next/navigation"
import { useAuth } from "@/hooks/useAuth"
import { useCreateComment } from "@/hooks/useComments"
import { Button } from "@/components/ui/button"
import { Textarea } from "@/components/ui/textarea"

const MAX_COMMENT_LENGTH = 300

const schema = z.object({
  content: z.string().trim().min(1, "Write a comment first").max(MAX_COMMENT_LENGTH, `Keep it under ${MAX_COMMENT_LENGTH} characters`),
})

type FormValues = z.infer<typeof schema>

export function CommentComposer({ postId }: { postId: string }): React.JSX.Element {
  const { isAuthenticated } = useAuth()
  const router = useRouter()
  const createComment = useCreateComment(postId)
  const {
    register,
    handleSubmit,
    reset,
    formState: { errors },
  } = useForm<FormValues>({ resolver: zodResolver(schema), defaultValues: { content: "" } })

  const onSubmit = async (values: FormValues): Promise<void> => {
    if (!isAuthenticated) {
      router.push("/login")
      return
    }
    await createComment.mutateAsync(values.content)
    reset({ content: "" })
  }

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-2" noValidate>
      <Textarea
        placeholder={isAuthenticated ? "Add a comment…" : "Sign in to comment"}
        disabled={!isAuthenticated}
        className="min-h-16"
        {...register("content")}
      />
      {errors.content && <p className="text-xs text-destructive">{errors.content.message}</p>}
      <div className="flex justify-end">
        {isAuthenticated ? (
          <Button type="submit" size="sm" disabled={createComment.isPending}>
            {createComment.isPending ? "Posting…" : "Comment"}
          </Button>
        ) : (
          <Button type="button" size="sm" onClick={() => router.push("/login")}>
            Sign in to comment
          </Button>
        )}
      </div>
    </form>
  )
}
