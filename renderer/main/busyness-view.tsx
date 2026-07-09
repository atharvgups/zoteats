import * as React from "react";
import { useQuery } from "@tanstack/react-query";
import { Button, EmptyState, ScrollArea, Text } from "@glaze/core/components";
import { RefreshCw } from "lucide-react";
import type { BusynessPoint } from "@shared/types";
import { api } from "../lib/api";
import { BusynessBar } from "../components/busyness-bar";
import { Skeleton } from "../components/skeleton";
import { timeAgo } from "../lib/format";

const CATEGORY_ORDER = ["Recreation", "Library", "Dining", "Campus"];

export function BusynessView() {
  const busynessQuery = useQuery({
    queryKey: ["busyness", "all"],
    queryFn: () => api.getBusyness(),
    staleTime: 60_000,
    refetchInterval: 60_000,
  });

  const facilities = busynessQuery.data?.facilities ?? [];

  const grouped = React.useMemo(() => {
    const map = new Map<string, BusynessPoint[]>();
    for (const point of facilities) {
      const list = map.get(point.category) ?? [];
      list.push(point);
      map.set(point.category, list);
    }
    return [...map.entries()].sort(
      (a, b) => CATEGORY_ORDER.indexOf(a[0]) - CATEGORY_ORDER.indexOf(b[0]),
    );
  }, [facilities]);

  const updatedAt = facilities[0]?.updatedAt;

  return (
    <ScrollArea
      className="h-full"
      title="Busyness"
      subtitle={updatedAt ? `Updated ${timeAgo(updatedAt)}` : undefined}
      actions={
        <Button iconOnly aria-label="Refresh" onClick={() => busynessQuery.refetch()}>
          <RefreshCw className="size-4.5" />
        </Button>
      }
      viewportClassName="px-5 pb-10"
    >
      <div className="mx-auto w-full max-w-2xl flex flex-col gap-6 pt-2">
        {busynessQuery.isLoading ? (
          <BusynessSkeleton />
        ) : busynessQuery.isError ? (
          <EmptyState
            title="Busyness unavailable"
            description="Couldn't load live campus occupancy. Check your connection and try again."
            actions={<Button onClick={() => busynessQuery.refetch()}>Retry</Button>}
          />
        ) : facilities.length === 0 ? (
          <EmptyState
            title="No live data right now"
            description="UCI's occupancy feed isn't reporting any facilities at the moment. Check back soon."
          />
        ) : (
          grouped.map(([category, points]) => (
            <section key={category} className="flex flex-col gap-3">
              <Text variant="strong">{category}</Text>
              <div className="flex flex-col gap-4">
                {points.map((point) => (
                  <BusynessBar key={point.id} point={point} />
                ))}
              </div>
            </section>
          ))
        )}
      </div>
    </ScrollArea>
  );
}

function BusynessSkeleton() {
  return (
    <div className="flex flex-col gap-6">
      {[0, 1].map((section) => (
        <div key={section} className="flex flex-col gap-3">
          <Skeleton className="h-4 w-28" />
          {[0, 1, 2].map((row) => (
            <div key={row} className="flex flex-col gap-1.5">
              <Skeleton className="h-4 w-full" />
              <Skeleton className="h-2 w-full" />
            </div>
          ))}
        </div>
      ))}
    </div>
  );
}
