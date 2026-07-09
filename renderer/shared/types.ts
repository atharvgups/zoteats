// Shared IPC types for ZotEats — the single source of truth for the contract
// between the backend (main/) and the renderer. Imported as `import type` on both
// sides via the `@shared/*` tsconfig alias, so there is no runtime dependency.

export type DiningLocationId = "anteatery" | "brandywine";

/** A UCI dining commons with today's hours and which meal periods it serves.
 * Period names come straight from UCI Dining (e.g. "Breakfast", "Lunch", "Dinner", "Brunch"). */
export interface DiningLocation {
  id: DiningLocationId;
  name: string;
  area: string;
  openNow: boolean;
  /** Human-readable daily window, e.g. "7:00 AM – 9:00 PM". */
  todayHours: string | null;
  /** Meal-period names served today, in order. */
  availablePeriods: string[];
  /** True when hours are from a maintained schedule rather than a live source. */
  hoursApproximate: boolean;
}

/** A single dish on a dining hall menu. */
export interface MenuItem {
  id: string;
  name: string;
  description: string | null;
  calories: number | null;
  servingSize: string | null;
  allergens: string[];
  dietaryTags: string[];
}

/** A station (e.g. "The Twisted Root") grouping menu items. */
export interface MenuStation {
  name: string;
  items: MenuItem[];
}

export interface DiningMenu {
  locationId: DiningLocationId;
  /** YYYY-MM-DD (UCI/Pacific). */
  date: string;
  /** Meal-period name, e.g. "Lunch". */
  period: string;
  stations: MenuStation[];
}

export interface GetMenuRequest {
  locationId: DiningLocationId;
  /** Meal-period name, e.g. "Lunch". */
  period: string;
  /** YYYY-MM-DD (Pacific). Defaults to today when omitted. */
  date?: string;
}

export type BusynessLevel = "not-busy" | "busy" | "very-busy" | "unknown";

/** Live occupancy for a tracked campus facility (from Occuspace/Waitz). */
export interface BusynessPoint {
  id: number;
  name: string;
  /** "Recreation" | "Library" | "Dining" | "Campus". */
  category: string;
  count: number | null;
  capacity: number | null;
  percent: number | null;
  level: BusynessLevel;
  isOpen: boolean;
  hoursSummary: string | null;
  /** ISO timestamp of when this snapshot was fetched. */
  updatedAt: string;
  subLocations?: BusynessPoint[];
}

export interface DayHours {
  day: string;
  hours: string;
}

/** Anteater Recreation Center status: hours + live busyness when available. */
export interface GymStatus {
  name: string;
  openNow: boolean;
  todayHours: string | null;
  weekHours: DayHours[];
  /** Null when the ARC is not present in the live busyness feed. */
  busyness: BusynessPoint | null;
  /** True when hours are from a maintained schedule rather than a live source. */
  hoursApproximate: boolean;
}
