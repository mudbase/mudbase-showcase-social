"use client"

import { Suspense, useEffect, useState } from "react"
import { useSearchParams } from "next/navigation"
import Link from "next/link"
import { useMudbase } from "@/lib/mudbase-provider"
import { MudbaseError } from "@/lib/mudbase"
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card"
import { Button } from "@/components/ui/button"

type VerifyState = { status: "verifying" } | { status: "success" } | { status: "error"; message: string }

function VerifyEmailContent(): React.JSX.Element {
  const searchParams = useSearchParams()
  const token = searchParams.get("token")
  const { client } = useMudbase()
  const [state, setState] = useState<VerifyState>({ status: "verifying" })

  useEffect(() => {
    if (!token) {
      setState({ status: "error", message: "This verification link is missing its token." })
      return
    }
    let cancelled = false
    client
      .verifyEmail(token)
      .then(() => {
        if (!cancelled) setState({ status: "success" })
      })
      .catch((err: unknown) => {
        if (cancelled) return
        const message = err instanceof MudbaseError ? err.message : "This verification link is invalid or has expired."
        setState({ status: "error", message })
      })
    return () => {
      cancelled = true
    }
  }, [client, token])

  return (
    <Card>
      <CardHeader>
        <CardTitle>Email verification</CardTitle>
        <CardDescription>
          {state.status === "verifying" && "Confirming your email address…"}
          {state.status === "success" && "Your email is verified."}
          {state.status === "error" && "We couldn't verify your email."}
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        {state.status === "error" && <p className="text-sm text-destructive">{state.message}</p>}
        {state.status === "success" && (
          <Button asChild className="w-full">
            <Link href="/login">Sign in now</Link>
          </Button>
        )}
      </CardContent>
    </Card>
  )
}

export default function VerifyEmailPage(): React.JSX.Element {
  return (
    <div className="container flex max-w-md flex-col justify-center py-16">
      <Suspense fallback={<p className="text-center text-sm text-muted-foreground">Loading…</p>}>
        <VerifyEmailContent />
      </Suspense>
    </div>
  )
}
