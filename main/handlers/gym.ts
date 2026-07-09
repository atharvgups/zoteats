// Gym (ARC) IPC handler.
import { ipcMain } from "@glaze/core/backend";
import { getGymStatus } from "../services/campusrec.js";

export function registerGymHandlers(): void {
  ipcMain.handle("gym:getStatus", async () => {
    return getGymStatus();
  });
}
