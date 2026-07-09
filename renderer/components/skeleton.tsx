import { cn } from "@glaze/core/utils";

/** Fixed-dimension loading placeholder (set width/height via className). */
export function Skeleton({ className }: { className?: string }) {
  return <div className={cn("bg-well rounded-md animate-pulse", className)} />;
}
