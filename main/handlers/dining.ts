// Dining IPC handlers. Thin: validate input, delegate to the dining service.
import { ipcMain } from "@glaze/core/backend";
import type { DiningLocationId, GetMenuRequest } from "@shared/types";
import { getLocations, getMenu } from "../services/dining.js";

const VALID_LOCATIONS: DiningLocationId[] = ["anteatery", "brandywine"];

function parseMenuRequest(input: unknown): GetMenuRequest {
  const obj = input && typeof input === "object" ? (input as Record<string, unknown>) : {};
  const { locationId, period, date } = obj;

  if (typeof locationId !== "string" || !VALID_LOCATIONS.includes(locationId as DiningLocationId)) {
    throw new Error(`dining:getMenu received an invalid locationId: ${String(locationId)}`);
  }
  if (typeof period !== "string" || period.trim() === "") {
    throw new Error(`dining:getMenu received an invalid period: ${String(period)}`);
  }

  return {
    locationId: locationId as DiningLocationId,
    period,
    date: typeof date === "string" ? date : undefined,
  };
}

export function registerDiningHandlers(): void {
  ipcMain.handle("dining:getLocations", async () => {
    return { locations: await getLocations() };
  });

  ipcMain.handle("dining:getMenu", async (_event, input: unknown) => {
    const request = parseMenuRequest(input);
    return getMenu(request.locationId, request.period, request.date);
  });
}
