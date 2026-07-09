import type { BusynessLevel } from "@shared/types";

export function timeAgo(iso: string): string {
  const then = new Date(iso).getTime();
  if (!Number.isFinite(then)) return "just now";
  const secs = Math.max(0, Math.round((Date.now() - then) / 1000));
  if (secs < 10) return "just now";
  if (secs < 60) return `${secs}s ago`;
  const mins = Math.round(secs / 60);
  if (mins < 60) return `${mins} min ago`;
  const hrs = Math.round(mins / 60);
  return hrs === 1 ? "1 hr ago" : `${hrs} hrs ago`;
}

export function busynessLabel(level: BusynessLevel): string {
  switch (level) {
    case "not-busy":
      return "Not busy";
    case "busy":
      return "Busy";
    case "very-busy":
      return "Very busy";
    default:
      return "No data";
  }
}

export function busynessVariant(level: BusynessLevel): "success" | "warning" | "error" | "neutral" {
  switch (level) {
    case "not-busy":
      return "success";
    case "busy":
      return "warning";
    case "very-busy":
      return "error";
    default:
      return "neutral";
  }
}
