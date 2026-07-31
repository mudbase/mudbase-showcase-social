import { PostComposer } from "@/components/feed/PostComposer"
import { FeedList } from "@/components/feed/FeedList"

export default function HomePage(): React.JSX.Element {
  return (
    <div className="container max-w-2xl space-y-6 py-8">
      <PostComposer />
      <FeedList />
    </div>
  )
}
