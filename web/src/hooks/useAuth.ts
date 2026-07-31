"use client"

import { useState, useCallback } from "react"
import { useRouter } from "next/navigation"
import { useMudbase } from "@/lib/mudbase-provider"
import { MudbaseError, errorCode, type UserObject } from "@/lib/mudbase"
import { getMudbaseSocket } from "@/lib/mudbase-socket"

export interface RegisterResult {
  success: boolean
  /** true when the account was created but still needs email verification before it can log in. */
  requireVerification: boolean
}

interface UseAuthReturn {
  user: UserObject | null
  /** A real, verified, signed-in account - distinct from the always-present anonymous guest session. */
  isAuthenticated: boolean
  loading: boolean
  error: string | null
  register: (
    email: string,
    password: string,
    firstName: string,
    lastName: string,
    agreedToTerms: boolean,
  ) => Promise<RegisterResult>
  login: (email: string, password: string, options?: { redirect?: boolean }) => Promise<boolean>
  logout: () => Promise<void>
  clearError: () => void
}

export function useAuth(): UseAuthReturn {
  const { client, session, loading: sessionLoading, refreshSession } = useMudbase()
  const router = useRouter()
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const register = useCallback(
    async (
      email: string,
      password: string,
      firstName: string,
      lastName: string,
      agreedToTerms: boolean,
    ): Promise<RegisterResult> => {
      setLoading(true)
      setError(null)
      try {
        const res = await client.register({ email, password, firstName, lastName, agreedToTerms })
        // Only refresh the session if a token actually came back - this project requires email
        // verification (verified live: registration otherwise returns 201 with no token), so a
        // successful call here usually means "account created, not yet signed in".
        if (res.token) await refreshSession()
        return { success: true, requireVerification: res.requireVerification === true }
      } catch (err) {
        setError(err instanceof MudbaseError ? err.message : "Registration failed")
        return { success: false, requireVerification: false }
      } finally {
        setLoading(false)
      }
    },
    [client, refreshSession],
  )

  const login = useCallback(
    async (email: string, password: string, options?: { redirect?: boolean }): Promise<boolean> => {
      setLoading(true)
      setError(null)
      try {
        await client.login({ email, password })
        await refreshSession()
        if (options?.redirect !== false) {
          router.push("/")
        }
        return true
      } catch (err) {
        if (errorCode(err) === "EMAIL_VERIFICATION_REQUIRED") {
          setError("Please verify your email first - check your inbox for the verification link, then sign in.")
        } else {
          setError(err instanceof MudbaseError ? err.message : "Login failed")
        }
        return false
      } finally {
        setLoading(false)
      }
    },
    [client, router, refreshSession],
  )

  const logout = useCallback(async () => {
    setLoading(true)
    try {
      await client.logout()
      // Without this, a socket connected while logged in stays connected authenticated as the
      // now-invalid session indefinitely - refreshSession() only ever calls connect() again on a
      // truthy token, never disconnects on a null one.
      getMudbaseSocket().disconnect()
      await refreshSession()
      router.push("/")
    } finally {
      setLoading(false)
    }
  }, [client, router, refreshSession])

  const user = session?.user ?? null

  return {
    user,
    // The provider always establishes an anonymous session so guests can read the feed - a
    // "real" signed-in user is one with an actual application role, not that always-present
    // anonymous identity (isAnonymous true, customRole null).
    isAuthenticated: !!user && user.isAnonymous !== true && !!user.customRole,
    loading: loading || sessionLoading,
    error,
    register,
    login,
    logout,
    clearError: () => setError(null),
  }
}
