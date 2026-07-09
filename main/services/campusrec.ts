// Anteater Recreation Center (ARC) status.
//
// UCI Campus Recreation does not publish a machine-readable hours API, and the ARC's
// hours shift by quarter/holidays. Strategy: prefer LIVE hours + open state from the
// Occuspace/Waitz feed when the ARC is tracked there; otherwise fall back to this
// maintained weekly schedule (verify against campusrec.uci.edu/arc/hours.html).
import { logger } from "@glaze/core/backend";
import type { DayHours, GymStatus } from "@shared/types";
import { getBusyness, findArc } from "./occuspace.js";

// Hours as [open, close] in 24h; close may be 24 (midnight). Maintained fallback.
const ARC_WEEK: { day: string; open: number; close: number }[] = [
  { day: "Sunday", open: 8, close: 24 },
  { day: "Monday", open: 6, close: 24 },
  { day: "Tuesday", open: 6, close: 24 },
  { day: "Wednesday", open: 6, close: 24 },
  { day: "Thursday", open: 6, close: 24 },
  { day: "Friday", open: 6, close: 24 },
  { day: "Saturday", open: 8, close: 21 },
];

function formatHour(h: number): string {
  const hour = h % 24;
  const period = hour < 12 ? "AM" : "PM";
  const display = hour % 12 === 0 ? 12 : hour % 12;
  return `${display}:00 ${period}`;
}

function irvineNow(): { weekday: string; minutes: number } {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: "America/Los_Angeles",
    weekday: "long",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  }).formatToParts(new Date());
  const get = (type: string) => parts.find((p) => p.type === type)?.value ?? "";
  const hour = parseInt(get("hour"), 10) || 0;
  const minute = parseInt(get("minute"), 10) || 0;
  return { weekday: get("weekday"), minutes: hour * 60 + minute };
}

export async function getGymStatus(): Promise<GymStatus> {
  let liveBusyness = null;
  let liveHours: string | null = null;
  let liveOpen: boolean | null = null;

  try {
    const arc = findArc(await getBusyness());
    if (arc) {
      liveBusyness = arc;
      liveHours = arc.hoursSummary;
      liveOpen = arc.isOpen;
    }
  } catch (err) {
    logger.warn("campusrec", "Busyness feed unavailable; using maintained schedule", {
      reason: err instanceof Error ? err.message : String(err),
    });
  }

  const { weekday, minutes } = irvineNow();
  const today = ARC_WEEK.find((d) => d.day === weekday);
  const scheduleOpenNow = today ? minutes >= today.open * 60 && minutes < today.close * 60 : false;

  const weekHours: DayHours[] = ARC_WEEK.map((d) => ({
    day: d.day,
    hours: `${formatHour(d.open)} – ${formatHour(d.close)}`,
  }));

  const todayHours = liveHours ?? (today ? `${formatHour(today.open)} – ${formatHour(today.close)}` : null);

  return {
    name: "Anteater Recreation Center",
    openNow: liveOpen ?? scheduleOpenNow,
    todayHours,
    weekHours,
    busyness: liveBusyness,
    hoursApproximate: liveHours === null,
  };
}
