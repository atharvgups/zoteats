// Thin fetch helper with a timeout and status-code-aware errors.
import { logger } from "@glaze/core/backend";

const DEFAULT_TIMEOUT_MS = 12_000;

interface FetchOptions {
  headers?: Record<string, string>;
  timeoutMs?: number;
}

export async function fetchJson<T>(url: string, init?: FetchOptions): Promise<T> {
  const { timeoutMs = DEFAULT_TIMEOUT_MS, headers } = init ?? {};

  let response: Response;
  try {
    response = await fetch(url, {
      signal: AbortSignal.timeout(timeoutMs),
      headers: {
        Accept: "application/json",
        "User-Agent": "ZotEats/1.0 (UCI student utility)",
        ...(headers ?? {}),
      },
    });
  } catch (err) {
    const reason = err instanceof Error ? err.message : String(err);
    logger.error("http", `Network request failed: ${url}`, { reason });
    throw new Error(`Network request failed for ${url}: ${reason}`);
  }

  if (!response.ok) {
    const body = await response.text().catch(() => "");
    logger.error("http", `HTTP ${response.status} for ${url}`, { body: body.slice(0, 300) });
    throw new Error(`Request to ${url} failed: ${response.status} ${response.statusText}`);
  }

  return (await response.json()) as T;
}
