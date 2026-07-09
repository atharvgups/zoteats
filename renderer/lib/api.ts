// Typed wrappers around the custom IPC bridge (window.glazeAPI.glaze.ipc).
import type { BusynessPoint, DiningLocation, DiningMenu, GetMenuRequest, GymStatus } from "@shared/types";

interface GlazeBridge {
  glaze: { ipc: { invoke<T>(channel: string, ...args: unknown[]): Promise<T> } };
  shell?: { openExternal?: (url: string) => Promise<void> };
}

function bridge(): GlazeBridge {
  const api = (window as unknown as { glazeAPI?: GlazeBridge }).glazeAPI;
  if (!api) throw new Error("Glaze bridge is unavailable");
  return api;
}

function invoke<T>(channel: string, ...args: unknown[]): Promise<T> {
  return bridge().glaze.ipc.invoke<T>(channel, ...args);
}

export const api = {
  getDiningLocations: () => invoke<{ locations: DiningLocation[] }>("dining:getLocations"),
  getMenu: (request: GetMenuRequest) => invoke<DiningMenu>("dining:getMenu", request),
  getGymStatus: () => invoke<GymStatus>("gym:getStatus"),
  getBusyness: () => invoke<{ facilities: BusynessPoint[] }>("busyness:getAll"),
  openExternal: (url: string) => bridge().shell?.openExternal?.(url),
};
