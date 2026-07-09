// Campus busyness IPC handler.
import { ipcMain } from "@glaze/core/backend";
import { getBusyness } from "../services/occuspace.js";

export function registerBusynessHandlers(): void {
  ipcMain.handle("busyness:getAll", async () => {
    return { facilities: await getBusyness() };
  });
}
