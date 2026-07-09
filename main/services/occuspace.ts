// Live campus busyness from UCI's Occuspace/Waitz public feed.
// Endpoint shape confirmed from community projects: GET https://waitz.io/live/irvine
// -> { data: [{ id, name, busyness, people, capacity, isOpen, isAvailable, hourSummary, subLocs[] }] }
import { logger } from "@glaze/core/backend";
import type { BusynessLevel, BusynessPoint } from "@shared/types";
import { fetchJson } from "./http.js";
import { TtlCache } from "./cache.js";

const WAITZ_URL = "https://waitz.io/live/irvine";
const TTL_MS = 60_000;

const cache = new TtlCache();

interface RawFacility {
  id?: number;
  name?: string;
  busyness?: number;
  people?: number;
  capacity?: number;
  isAvailable?: boolean;
  isOpen?: boolean;
  hourSummary?: string;
  subLocs?: RawFacility[];
}

interface RawWaitzResponse {
  data?: RawFacility[];
}

function categorize(name: string): string {
  const n = name.toLowerCase();
  if (/(arc|recreation|gym|fitness|crawford|track|pool)/.test(n)) return "Recreation";
  if (/(library|libraries|langson|science|gateway|grunigen|multimedia|ayala)/.test(n)) return "Library";
  if (/(commons|anteatery|brandywine|dining|eatery|cafe)/.test(n)) return "Dining";
  return "Campus";
}

function levelFor(percent: number | null): BusynessLevel {
  if (percent === null) return "unknown";
  if (percent <= 45) return "not-busy";
  if (percent <= 80) return "busy";
  return "very-busy";
}

function normalize(facility: RawFacility, updatedAt: string): BusynessPoint {
  const capacity = typeof facility.capacity === "number" ? facility.capacity : null;
  const count = typeof facility.people === "number" ? facility.people : null;

  let percent: number | null = typeof facility.busyness === "number" ? Math.round(facility.busyness) : null;
  if (percent === null && count !== null && capacity && capacity > 0) {
    percent = Math.round((count / capacity) * 100);
  }
  if (percent !== null) percent = Math.max(0, Math.min(100, percent));

  const name = facility.name?.trim() || "Unknown";
  const subs = Array.isArray(facility.subLocs) ? facility.subLocs.map((s) => normalize(s, updatedAt)) : undefined;

  return {
    id: typeof facility.id === "number" ? facility.id : -1,
    name,
    category: categorize(name),
    count,
    capacity,
    percent,
    level: levelFor(percent),
    isOpen: facility.isOpen ?? facility.isAvailable ?? false,
    hoursSummary: facility.hourSummary?.trim() || null,
    updatedAt,
    subLocations: subs && subs.length > 0 ? subs : undefined,
  };
}

/** All facilities the UCI Occuspace/Waitz feed currently tracks. */
export async function getBusyness(): Promise<BusynessPoint[]> {
  return cache.remember("busyness:irvine", TTL_MS, async () => {
    const raw = await fetchJson<RawWaitzResponse>(WAITZ_URL);
    const updatedAt = new Date().toISOString();
    const list = Array.isArray(raw.data) ? raw.data : [];
    logger.info("occuspace", `Fetched ${list.length} facilities from Waitz`, {
      names: list.map((f) => f.name).filter(Boolean).slice(0, 25),
    });
    return list.map((facility) => normalize(facility, updatedAt));
  });
}

/** Locate the ARC within the tracked facilities, if the feed includes it. */
export function findArc(points: BusynessPoint[]): BusynessPoint | null {
  return points.find((p) => /\barc\b|recreation/i.test(p.name) || p.category === "Recreation") ?? null;
}
