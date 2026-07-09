import { Status, Text } from "@glaze/core/components";
import type { BusynessPoint } from "@shared/types";
import { busynessLabel, busynessVariant } from "../lib/format";

/** A single facility's live occupancy: name, level pill, fill bar, and counts. */
export function BusynessBar({ point }: { point: BusynessPoint }) {
  const percent = point.percent ?? 0;
  const hasLive = point.percent !== null;

  return (
    <div className="flex flex-col gap-1.5">
      <div className="flex items-center justify-between gap-3">
        <Text variant="regular" className="min-w-0 truncate">
          {point.name}
        </Text>
        <Status variant={busynessVariant(point.level)} className="shrink-0">
          {busynessLabel(point.level)}
        </Status>
      </div>

      <div className="h-2 rounded-pill bg-well overflow-hidden">
        <div
          className="h-full rounded-pill bg-accent transition-[width] duration-500"
          style={{ width: `${Math.max(hasLive ? 3 : 0, percent)}%` }}
        />
      </div>

      <div className="flex items-center justify-between gap-3">
        <Text variant="small" color="tertiary" className="tabular-nums">
          {hasLive ? `${point.percent}% full` : "No live count"}
          {point.count !== null && point.capacity ? ` · ${point.count}/${point.capacity}` : ""}
        </Text>
        {point.hoursSummary ? (
          <Text variant="small" color="tertiary" className="shrink-0">
            {point.hoursSummary}
          </Text>
        ) : null}
      </div>
    </div>
  );
}
