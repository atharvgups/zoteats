// Lightweight localStorage-backed user preferences (frontend-only).
import * as React from "react";

const DIETARY_KEY = "zoteats:dietary-filters";

function read<T>(key: string, fallback: T): T {
  try {
    const raw = localStorage.getItem(key);
    return raw ? (JSON.parse(raw) as T) : fallback;
  } catch {
    return fallback;
  }
}

function write<T>(key: string, value: T): void {
  try {
    localStorage.setItem(key, JSON.stringify(value));
  } catch {
    // Ignore quota/serialization errors — preferences are best-effort.
  }
}

/** Persisted dietary-tag filter (e.g. ["Vegan", "Halal"]). */
export function useDietaryFilters(): [string[], (tags: string[]) => void] {
  const [filters, setFilters] = React.useState<string[]>(() => read<string[]>(DIETARY_KEY, []));

  const update = React.useCallback((tags: string[]) => {
    setFilters(tags);
    write(DIETARY_KEY, tags);
  }, []);

  return [filters, update];
}
