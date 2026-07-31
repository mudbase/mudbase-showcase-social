"use client"

import { useEffect } from "react"
import { useRouter } from "next/navigation"
import { useAuth } from "@/hooks/useAuth"

/** `/profile` is a thin redirect to the current user's own `/users/[userId]` page - keeping a
 * single ProfileHeader/ProfilePostList implementation rather than a parallel "my profile" one. */
export default function MyProfilePage(): React.JSX.Element {
  const { user, isAuthenticated, loading } = useAuth()
  const router = useRouter()

  useEffect(() => {
    if (loading) return
    if (!isAuthenticated || !user) {
      router.replace("/login")
      return
    }
    router.replace(`/users/${user.id}`)
  }, [loading, isAuthenticated, user, router])

  return <p className="container py-16 text-center text-sm text-muted-foreground">Loading your profile…</p>
}
