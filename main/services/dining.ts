// UCI dining data from the Anteater API (anteaterapi.com) — the maintained, public
// UCI data API used by ICSSC's PeterPlate. Endpoints (base /v2/rest/dining):
//   GET /restaurants                     -> restaurants with their stations (id + name)
//   GET /restaurantToday?id=&date=       -> periods -> stationToDishes (station id -> dish ids)
//   GET /dishes/batch?ids=a,b,c          -> full dish objects (nutrition + diet/allergen flags)
// Responses use the standard { ok, data } envelope. No API key required (rate-limited).
import { logger } from "@glaze/core/backend";
import type { DiningLocation, DiningLocationId, DiningMenu, MenuItem, MenuStation } from "@shared/types";
import { fetchJson } from "./http.js";
import { TtlCache } from "./cache.js";

const BASE = "https://anteaterapi.com/v2/rest/dining";

const HALLS: Record<DiningLocationId, { name: string; area: string }> = {
  anteatery: { name: "The Anteatery", area: "Mesa Court" },
  brandywine: { name: "Brandywine", area: "Middle Earth" },
};

const cache = new TtlCache();
const STATIONS_TTL = 24 * 60 * 60_000;
const TODAY_TTL = 20 * 60_000;
const DISHES_TTL = 30 * 60_000;

interface Envelope<T> {
  ok?: boolean;
  data?: T;
  message?: string;
}

interface ApiStation {
  id: string;
  name: string;
}
interface ApiRestaurant {
  id: string;
  stations?: ApiStation[];
}
interface ApiPeriod {
  name: string;
  startTime: string | null;
  endTime: string | null;
  stationToDishes?: Record<string, string[]>;
}
interface ApiRestaurantToday {
  id: string;
  periods?: Record<string, ApiPeriod>;
}
interface ApiDietRestriction {
  containsEggs?: boolean;
  containsFish?: boolean;
  containsMilk?: boolean;
  containsPeanuts?: boolean;
  containsSesame?: boolean;
  containsShellfish?: boolean;
  containsSoy?: boolean;
  containsTreeNuts?: boolean;
  containsWheat?: boolean;
  isGlutenFree?: boolean;
  isHalal?: boolean;
  isKosher?: boolean;
  isLocallyGrown?: boolean;
  isOrganic?: boolean;
  isVegan?: boolean;
  isVegetarian?: boolean;
}
interface ApiNutrition {
  servingSize?: string | null;
  servingUnit?: string | null;
  calories?: number | null;
}
interface ApiDish {
  id: string;
  stationId: string;
  name: string;
  description?: string | null;
  dietRestriction?: ApiDietRestriction | null;
  nutritionInfo?: ApiNutrition | null;
}

const ALLERGEN_LABELS: [keyof ApiDietRestriction, string][] = [
  ["containsEggs", "Eggs"],
  ["containsFish", "Fish"],
  ["containsMilk", "Milk"],
  ["containsPeanuts", "Peanuts"],
  ["containsSesame", "Sesame"],
  ["containsShellfish", "Shellfish"],
  ["containsSoy", "Soy"],
  ["containsTreeNuts", "Tree Nuts"],
  ["containsWheat", "Wheat"],
];
const DIET_LABELS: [keyof ApiDietRestriction, string][] = [
  ["isVegan", "Vegan"],
  ["isVegetarian", "Vegetarian"],
  ["isHalal", "Halal"],
  ["isKosher", "Kosher"],
  ["isGlutenFree", "Gluten-Free"],
  ["isOrganic", "Organic"],
  ["isLocallyGrown", "Locally Grown"],
];

async function getData<T>(url: string): Promise<T> {
  const res = await fetchJson<Envelope<T> | T>(url);
  const env = res as Envelope<T>;
  if (env && typeof env === "object" && "ok" in env) {
    if (env.ok === false) throw new Error(`Anteater API error for ${url}: ${env.message ?? "request failed"}`);
    if (env.data !== undefined) return env.data;
  }
  return res as T;
}

function extractFlags(dr: ApiDietRestriction | null | undefined, labels: [keyof ApiDietRestriction, string][]): string[] {
  if (!dr) return [];
  return labels.filter(([key]) => dr[key] === true).map(([, label]) => label);
}

function parseMinutes(time: string | null | undefined): number | null {
  if (!time) return null;
  const [h, m] = time.split(":").map((x) => parseInt(x, 10));
  if (!Number.isFinite(h)) return null;
  return h * 60 + (Number.isFinite(m) ? m : 0);
}

function formatMinutes(mins: number): string {
  const h = Math.floor(mins / 60);
  const m = mins % 60;
  const period = h < 12 || h === 24 ? "AM" : "PM";
  const display = h % 12 === 0 ? 12 : h % 12;
  return m === 0 ? `${display}:00 ${period}` : `${display}:${String(m).padStart(2, "0")} ${period}`;
}

function irvineDateISO(date?: string): string {
  if (date) return date;
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: "America/Los_Angeles",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(new Date());
  const get = (type: string) => parts.find((p) => p.type === type)?.value ?? "";
  return `${get("year")}-${get("month")}-${get("day")}`;
}

function irvineNowMinutes(): number {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: "America/Los_Angeles",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  }).formatToParts(new Date());
  const get = (type: string) => parts.find((p) => p.type === type)?.value ?? "";
  return (parseInt(get("hour"), 10) || 0) * 60 + (parseInt(get("minute"), 10) || 0);
}

async function getStationMap(): Promise<Map<string, string>> {
  return cache.remember("dining:stations", STATIONS_TTL, async () => {
    const restaurants = await getData<ApiRestaurant[]>(`${BASE}/restaurants`);
    const map = new Map<string, string>();
    for (const restaurant of restaurants ?? []) {
      for (const station of restaurant.stations ?? []) map.set(station.id, station.name);
    }
    logger.info("dining", `Loaded ${map.size} dining stations`);
    return map;
  });
}

async function getToday(hall: DiningLocationId, dateISO: string): Promise<ApiRestaurantToday> {
  return cache.remember(`dining:today:${hall}:${dateISO}`, TODAY_TTL, async () => {
    logger.info("dining", `Fetching menu day: ${hall} ${dateISO}`);
    return getData<ApiRestaurantToday>(`${BASE}/restaurantToday?id=${hall}&date=${dateISO}`);
  });
}

async function getDishes(ids: string[]): Promise<Map<string, ApiDish>> {
  const unique = [...new Set(ids)].sort();
  if (unique.length === 0) return new Map();
  return cache.remember(`dining:dishes:${unique.join(",")}`, DISHES_TTL, async () => {
    const dishes = await getData<ApiDish[]>(`${BASE}/dishes/batch?ids=${encodeURIComponent(unique.join(","))}`);
    const map = new Map<string, ApiDish>();
    for (const dish of dishes ?? []) map.set(dish.id, dish);
    return map;
  });
}

function servedPeriods(today: ApiRestaurantToday): ApiPeriod[] {
  return Object.values(today.periods ?? {}).filter(
    (period) => Object.keys(period.stationToDishes ?? {}).length > 0,
  );
}

export async function getLocations(): Promise<DiningLocation[]> {
  const dateISO = irvineDateISO();
  const now = irvineNowMinutes();

  return Promise.all(
    (Object.keys(HALLS) as DiningLocationId[]).map(async (id) => {
      const base = { id, name: HALLS[id].name, area: HALLS[id].area, hoursApproximate: false };
      try {
        const periods = servedPeriods(await getToday(id, dateISO));
        const starts = periods.map((p) => parseMinutes(p.startTime)).filter((x): x is number => x !== null);
        const ends = periods.map((p) => parseMinutes(p.endTime)).filter((x): x is number => x !== null);
        const openNow = periods.some((p) => {
          const s = parseMinutes(p.startTime);
          const e = parseMinutes(p.endTime);
          return s !== null && e !== null && now >= s && now < e;
        });
        const todayHours =
          starts.length && ends.length ? `${formatMinutes(Math.min(...starts))} – ${formatMinutes(Math.max(...ends))}` : null;
        return { ...base, openNow, todayHours, availablePeriods: periods.map((p) => p.name) };
      } catch (err) {
        logger.warn("dining", `Failed to load ${id} day info`, {
          reason: err instanceof Error ? err.message : String(err),
        });
        return { ...base, openNow: false, todayHours: null, availablePeriods: [] };
      }
    }),
  );
}

function toMenuItem(dish: ApiDish): MenuItem {
  const nutrition = dish.nutritionInfo ?? undefined;
  const serving = nutrition?.servingSize
    ? `${nutrition.servingSize}${nutrition.servingUnit ? ` ${nutrition.servingUnit}` : ""}`
    : null;
  return {
    id: dish.id,
    name: dish.name,
    description: dish.description?.trim() || null,
    calories: typeof nutrition?.calories === "number" ? Math.round(nutrition.calories) : null,
    servingSize: serving,
    allergens: extractFlags(dish.dietRestriction, ALLERGEN_LABELS),
    dietaryTags: extractFlags(dish.dietRestriction, DIET_LABELS),
  };
}

export async function getMenu(locationId: DiningLocationId, period: string, date?: string): Promise<DiningMenu> {
  if (!HALLS[locationId]) throw new Error(`Unknown dining location: ${locationId}`);
  const dateISO = irvineDateISO(date);
  const today = await getToday(locationId, dateISO);

  const match = Object.values(today.periods ?? {}).find((p) => p.name.toLowerCase() === period.toLowerCase());
  if (!match) return { locationId, date: dateISO, period, stations: [] };

  const stationToDishes = match.stationToDishes ?? {};
  const allIds = Object.values(stationToDishes).flat();
  const [dishMap, stationMap] = await Promise.all([getDishes(allIds), getStationMap()]);

  const stations: MenuStation[] = [];
  for (const [stationId, dishIds] of Object.entries(stationToDishes)) {
    const items = dishIds
      .map((dishId) => dishMap.get(dishId))
      .filter((dish): dish is ApiDish => Boolean(dish))
      .map(toMenuItem);
    if (items.length > 0) stations.push({ name: stationMap.get(stationId) ?? "Menu", items });
  }

  return { locationId, date: dateISO, period, stations };
}
