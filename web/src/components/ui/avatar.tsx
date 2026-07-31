import * as React from "react"
import { cn } from "@/lib/utils"
import { initials } from "@/lib/utils"

interface AvatarProps extends React.HTMLAttributes<HTMLDivElement> {
  name: string
  size?: "sm" | "md" | "lg"
}

const sizeClasses: Record<NonNullable<AvatarProps["size"]>, string> = {
  sm: "h-8 w-8 text-xs",
  md: "h-10 w-10 text-sm",
  lg: "h-14 w-14 text-base",
}

/** Every author here is denormalized to a name string, not a profile with an uploaded photo
 * (there is no users collection in this app's data model - see plan/build-plan.md) - so every
 * avatar is a deterministic initials badge rather than an <img>. */
function Avatar({ name, size = "md", className, ...props }: AvatarProps): React.JSX.Element {
  return (
    <div
      className={cn(
        "flex shrink-0 select-none items-center justify-center rounded-full bg-primary font-semibold text-primary-foreground",
        sizeClasses[size],
        className,
      )}
      aria-hidden="true"
      {...props}
    >
      {initials(name)}
    </div>
  )
}

export { Avatar }
