import type { NextConfig } from "next"
import { fileURLToPath } from "url"
import { dirname } from "path"

const __dirname = dirname(fileURLToPath(import.meta.url))

const nextConfig: NextConfig = {
  // An unrelated lockfile at /Users/mac/package-lock.json would otherwise make Next.js infer
  // the wrong workspace root and mis-trace file dependencies for this project.
  outputFileTracingRoot: __dirname,
  // No `images.remotePatterns` block: this app never uses next/image. Post images are
  // arbitrary user-pasted URLs (see PostCard.tsx and plan/build-plan.md "Known limitations"),
  // which next/image's optimizer can't serve from an unbounded host allowlist anyway - a plain
  // <img> is used instead, so there is nothing here for next/image config to apply to.
  async headers() {
    return [
      {
        source: "/(.*)",
        headers: [
          { key: "X-Frame-Options", value: "DENY" },
          { key: "X-Content-Type-Options", value: "nosniff" },
          { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
          { key: "Permissions-Policy", value: "camera=(), microphone=(), geolocation=()" },
        ],
      },
    ]
  },
}

export default nextConfig
