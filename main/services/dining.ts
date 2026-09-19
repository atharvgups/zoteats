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

function weekStartISO(dateISO: string): string {
  const [year, month, day] = dateISO.split("-").map((x) => parseInt(x, 10));
  if (!year || !month || !day) return dateISO;
  const utc = Date.UTC(year, month - 1, day);
  const weekday = new Date(utc).getUTCDay(); // 0 = Sunday
  const start = new Date(utc);
  start.setUTCDate(start.getUTCDate() - weekday);
  const y = start.getUTCFullYear();
  const m = String(start.getUTCMonth() + 1).padStart(2, "0");
  const d = String(start.getUTCDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
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
  const map = new Map<string, ApiDish>();
  const chunkSize = 40;
  for (let i = 0; i < unique.length; i += chunkSize) {
    const chunk = unique.slice(i, i + chunkSize);
    const batch = await cache.remember(`dining:dishes:${chunk.join(",")}`, DISHES_TTL, async () => {
      const dishes = await getData<ApiDish[]>(`${BASE}/dishes/batch?ids=${encodeURIComponent(chunk.join(","))}`);
      const inner = new Map<string, ApiDish>();
      for (const dish of dishes ?? []) inner.set(dish.id, dish);
      return inner;
    });
    for (const [id, dish] of batch) map.set(id, dish);
  }
  return map;
}

function servedPeriods(today: ApiRestaurantToday): ApiPeriod[] {
  return Object.values(today.periods ?? {}).filter((period) =>
    Object.values(period.stationToDishes ?? {}).some((ids) => (ids?.length ?? 0) > 0),
  );
}

const MESH = "https://api.elevate-dxp.com/api/mesh/c087f756-cc72-4649-a36f-3a41b700c519/graphql";
const MESH_HEADERS = {
  Referer: "https://uci.mydininghub.com/",
  Origin: "https://uci.mydininghub.com",
  store: "ch_uci_en",
  "x-api-key": "ElevateAPIProd",
  "magento-store-code": "ch_uci",
  "magento-website-code": "ch_uci",
  "magento-store-view-code": "ch_uci_en",
};
const HUB_KEYS: Record<DiningLocationId, string> = {
  anteatery: "the-anteatery",
  brandywine: "brandywine",
};

async function mesh<T>(query: string, variables: unknown): Promise<T> {
  const url = `${MESH}?query=${encodeURIComponent(query)}&variables=${encodeURIComponent(JSON.stringify(variables))}`;
  const envelope = await fetchJson<{ data?: T }>(url, { headers: MESH_HEADERS, timeoutMs: 20_000 });
  if (!envelope.data) throw new Error("Dining hub returned no data");
  return envelope.data;
}

async function hubMealPeriodId(name: string): Promise<number | null> {
  return cache.remember("dining:hub:mealPeriods", STATIONS_TTL, async () => {
    const data = await mesh<{ Commerce_mealPeriods?: { name: string; id: number }[] }>(
      "query{Commerce_mealPeriods(sort_order:ASC){name id}}",
      {},
    );
    return data.Commerce_mealPeriods ?? [];
  }).then((periods) => periods.find((p) => p.name.toLowerCase() === name.toLowerCase())?.id ?? null);
}

async function hubStationNames(): Promise<Map<string, string>> {
  return cache.remember("dining:hub:stations", STATIONS_TTL, async () => {
    const data = await mesh<{
      getLocations?: { commerceAttributes?: { children?: { id: number; name: string }[] } }[];
    }>(
      `query($campusUrlKey:String!){getLocations(campusUrlKey:$campusUrlKey){commerceAttributes{children{id name}}}}`,
      { campusUrlKey: "campus" },
    );
    const map = new Map<string, string>();
    for (const loc of data.getLocations ?? []) {
      for (const station of loc.commerceAttributes?.children ?? []) {
        map.set(String(station.id), station.name.trim());
      }
    }
    return map;
  });
}

interface HubRecipes {
  locationRecipesMap?: { dateSkuMap?: { date: string; stations?: { id: number; skus?: { simple?: string[] } }[] }[] };
  products?: { items?: { sku: string; name: string }[] };
}

async function hubAssignment(
  hall: DiningLocationId,
  period: string,
  dateISO: string,
): Promise<{ stations: Map<string, string[]>; products: Map<string, { sku: string; name: string }> }> {
  const periodId = await hubMealPeriodId(period);
  const urlKey = HUB_KEYS[hall];
  const empty = { stations: new Map<string, string[]>(), products: new Map<string, { sku: string; name: string }>() };
  if (periodId == null || !urlKey) return empty;

  const query = `query getLocationRecipes($locationUrlKey:String!,$date:String!,$mealPeriod:Int,$viewType:Commerce_MenuViewType!){getLocationRecipes(campusUrlKey:"campus",locationUrlKey:$locationUrlKey,date:$date,mealPeriod:$mealPeriod,viewType:$viewType){locationRecipesMap{dateSkuMap{date stations{id skus{simple}}}}products{items{sku name}}}}`;
  const weekStart = weekStartISO(dateISO);
  const [daily, weekly] = await Promise.all(
    ([
      ["DAILY", dateISO],
      ["WEEKLY", weekStart],
    ] as const).map(([viewType, date]) =>
      cache.remember(`dining:hub:recipes:${urlKey}:${date}:${periodId}:${viewType}`, TODAY_TTL, () =>
        mesh<{ getLocationRecipes?: HubRecipes }>(query, {
          locationUrlKey: urlKey,
          date,
          mealPeriod: periodId,
          viewType,
        }).then((d) => d.getLocationRecipes ?? {}),
      ),
    ),
  );

  const stations = new Map<string, string[]>();
  const products = new Map<string, { sku: string; name: string }>();
  for (const recipes of [weekly, daily]) {
    for (const day of recipes.locationRecipesMap?.dateSkuMap ?? []) {
      if (day.date !== dateISO) continue;
      for (const station of day.stations ?? []) {
        const skus = (station.skus?.simple ?? []).filter(Boolean);
        if (!skus.length) continue;
        const id = String(station.id);
        const existing = stations.get(id) ?? [];
        for (const sku of skus) if (!existing.includes(sku)) existing.push(sku);
        stations.set(id, existing);
      }
    }
    for (const item of recipes.products?.items ?? []) {
      if (item.sku && item.name) products.set(item.sku, item);
    }
  }
  return { stations, products };
}

async function commerceNames(skus: string[]): Promise<Map<string, string>> {
  const unique = [...new Set(skus)].sort();
  const names = new Map<string, string>();
  for (let i = 0; i < unique.length; i += 20) {
    const chunk = unique.slice(i, i + 20);
    const data = await mesh<{ Commerce_products?: { items?: { sku: string; name: string }[] } }>(
      `query($skus:[String!]){Commerce_products(filter:{sku:{in:$skus}},pageSize:50){items{sku name}}}`,
      { skus: chunk },
    );
    for (const item of data.Commerce_products?.items ?? []) {
      if (item.sku && item.name) names.set(item.sku, item.name);
    }
  }
  return names;
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
  const lastGoodKey = `dining:lastGood:${locationId}:${dateISO}:${period.toLowerCase()}`;

  try {
    const menu = await buildMenu(locationId, period, dateISO);
    if (menu.stations.length > 0) cache.set(lastGoodKey, menu, 24 * 60 * 60_000);
    return menu;
  } catch (err) {
    const stale = cache.getStale<DiningMenu>(lastGoodKey);
    if (stale && stale.stations.length > 0) {
      logger.warn("dining", `Serving last-good menu for ${locationId} ${dateISO} ${period}`, {
        reason: err instanceof Error ? err.message : String(err),
      });
      return { ...stale, isStale: true };
    }
    throw err;
  }
}

async function buildMenu(locationId: DiningLocationId, period: string, dateISO: string): Promise<DiningMenu> {
  const [hub, today, stationMap, hubNames] = await Promise.all([
    hubAssignment(locationId, period, dateISO).catch((err) => {
      logger.warn("dining", `Hub recipes failed for ${locationId} ${period}`, {
        reason: err instanceof Error ? err.message : String(err),
      });
      return { stations: new Map<string, string[]>(), products: new Map<string, { sku: string; name: string }>() };
    }),
    getToday(locationId, dateISO).catch((err) => {
      const message = err instanceof Error ? err.message : String(err);
      if (/404|no data/i.test(message)) return { id: locationId, periods: {} } as ApiRestaurantToday;
      throw err;
    }),
    getStationMap(),
    hubStationNames().catch(() => new Map<string, string>()),
  ]);

  const drafts = new Map<string, { name: string; dishIds: string[] }>();
  const add = (stationId: string, dishIds: string[]) => {
    if (!dishIds.length) return;
    const name = (hubNames.get(stationId) ?? stationMap.get(stationId) ?? "Menu").trim() || "Menu";
    const draft = drafts.get(stationId) ?? { name, dishIds: [] };
    for (const id of dishIds) if (!draft.dishIds.includes(id)) draft.dishIds.push(id);
    drafts.set(stationId, draft);
  };
  for (const [id, skus] of hub.stations) add(id, skus);
  const match = Object.values(today.periods ?? {}).find((p) => p.name.toLowerCase() === period.toLowerCase());
  for (const [id, dishIds] of Object.entries(match?.stationToDishes ?? {})) add(id, dishIds.filter(Boolean));

  const allIds = [...drafts.values()].flatMap((d) => d.dishIds);
  const dishMap = await getDishes(allIds);
  const unresolved = allIds.filter((id) => !dishMap.has(id) && !hub.products.has(id));
  const extraNames = unresolved.length ? await commerceNames(unresolved).catch(() => new Map<string, string>()) : new Map();

  const warnings: string[] = [];
  const stations: MenuStation[] = [];
  for (const [stationId, draft] of drafts) {
    const seen = new Set<string>();
    const items: MenuItem[] = [];
    let missing = 0;
    for (const id of draft.dishIds) {
      const apiDish = dishMap.get(id);
      const item = apiDish
        ? toMenuItem(apiDish)
        : hub.products.has(id)
          ? { id, name: hub.products.get(id)!.name, description: null, calories: null, servingSize: null, allergens: [], dietaryTags: [] }
          : extraNames.has(id)
            ? { id, name: extraNames.get(id)!, description: null, calories: null, servingSize: null, allergens: [], dietaryTags: [] }
            : null;
      if (!item) {
        missing += 1;
        continue;
      }
      if (seen.has(item.name.toLowerCase())) continue;
      seen.add(item.name.toLowerCase());
      items.push(item);
    }
    if (items.length === 0) {
      if (missing) warnings.push(`${draft.name} was on the menu but its dishes didn't load.`);
      continue;
    }
    if (missing) warnings.push(`${draft.name} is missing ${missing} dish${missing === 1 ? "" : "es"}.`);
    stations.push({ name: draft.name, items });
  }

  if (drafts.size === 0) {
    logger.info("dining", `No stations for ${locationId} ${dateISO} ${period}`);
  }

  return { locationId, date: dateISO, period, stations, isStale: false, warnings };
}
