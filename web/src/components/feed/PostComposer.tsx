"use client"

import { useForm } from "react-hook-form"
import { zodResolver } from "@hookform/resolvers/zod"
import { z } from "zod"
import { useRouter } from "next/navigation"
import { useAuth } from "@/hooks/useAuth"
import { useCreatePost } from "@/hooks/usePostsFeed"
import { Button } from "@/components/ui/button"
import { Textarea } from "@/components/ui/textarea"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Card, CardContent } from "@/components/ui/card"

const MAX_CONTENT_LENGTH = 500

const schema = z.object({
  content: z.string().trim().min(1, "Write something first").max(MAX_CONTENT_LENGTH, `Keep it under ${MAX_CONTENT_LENGTH} characters`),
  // Pasted URL rather than an upload - see PostCard/plan/build-plan.md "Known limitations".
  imageUrl: z.string().trim().url("Enter a valid image URL").optional().or(z.literal("")),
})

type FormValues = z.infer<typeof schema>

export function PostComposer(): React.JSX.Element {
  const { isAuthenticated } = useAuth()
  const router = useRouter()
  const createPost = useCreatePost()
  const {
    register,
    handleSubmit,
    reset,
    watch,
    formState: { errors },
  } = useForm<FormValues>({ resolver: zodResolver(schema), defaultValues: { content: "", imageUrl: "" } })

  const content = watch("content") ?? ""

  const onSubmit = async (values: FormValues): Promise<void> => {
    if (!isAuthenticated) {
      router.push("/login")
      return
    }
    await createPost.mutateAsync({ content: values.content, imageUrl: values.imageUrl || undefined })
    reset({ content: "", imageUrl: "" })
  }

  return (
    <Card>
      <CardContent className="space-y-3 p-4">
        <form onSubmit={handleSubmit(onSubmit)} className="space-y-3" noValidate>
          <div className="space-y-1.5">
            <Label htmlFor="content" className="sr-only">
              What&apos;s on your mind?
            </Label>
            <Textarea
              id="content"
              placeholder={isAuthenticated ? "What's on your mind?" : "Sign in to post"}
              disabled={!isAuthenticated}
              {...register("content")}
            />
            <div className="flex items-center justify-between text-xs text-muted-foreground">
              {errors.content ? <p className="text-destructive">{errors.content.message}</p> : <span />}
              <span>
                {content.length}/{MAX_CONTENT_LENGTH}
              </span>
            </div>
          </div>
          <div className="space-y-1.5">
            <Label htmlFor="imageUrl" className="text-xs text-muted-foreground">
              Image URL (optional)
            </Label>
            <Input
              id="imageUrl"
              type="url"
              placeholder="https://example.com/photo.jpg"
              disabled={!isAuthenticated}
              {...register("imageUrl")}
            />
            {errors.imageUrl && <p className="text-xs text-destructive">{errors.imageUrl.message}</p>}
          </div>
          <div className="flex justify-end">
            {isAuthenticated ? (
              <Button type="submit" disabled={createPost.isPending}>
                {createPost.isPending ? "Posting…" : "Post"}
              </Button>
            ) : (
              <Button type="button" onClick={() => router.push("/login")}>
                Sign in to post
              </Button>
            )}
          </div>
        </form>
      </CardContent>
    </Card>
  )
}
