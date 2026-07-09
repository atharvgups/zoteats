import { useQuery } from "@tanstack/react-query";
import { Button, Callout, EmptyState, ScrollArea, Separator, Status, Text } from "@glaze/core/components";
import { ExternalLink } from "lucide-react";
import { api } from "../lib/api";
import { BusynessBar } from "../components/busyness-bar";
import { Skeleton } from "../components/skeleton";

const ARC_HOURS_URL = "https://www.campusrec.uci.edu/arc/hours.html";

export function GymView() {
  const gymQuery = useQuery({
    queryKey: ["gym", "status"],
    queryFn: () => api.getGymStatus(),
    staleTime: 60_000,
    refetchInterval: 90_000,
  });

  const gym = gymQuery.data;

  return (
    <ScrollArea className="h-full" title="Gym" viewportClassName="px-5 pb-10">
      <div className="mx-auto w-full max-w-2xl flex flex-col gap-5 pt-2">
        {gymQuery.isLoading ? (
          <GymSkeleton />
        ) : gymQuery.isError || !gym ? (
          <EmptyState
            title="Gym unavailable"
            description="Couldn't load Anteater Recreation Center info. Check your connection and try again."
            actions={<Button onClick={() => gymQuery.refetch()}>Retry</Button>}
          />
        ) : (
          <>
            <div className="flex flex-col gap-2">
              <div className="flex items-center justify-between gap-3">
                <Text variant="heading2">{gym.name}</Text>
                <Status variant={gym.openNow ? "success" : "neutral"}>{gym.openNow ? "Open now" : "Closed"}</Status>
              </div>
              {gym.todayHours ? (
                <Text color="secondary">Today · {gym.todayHours}</Text>
              ) : null}
            </div>

            {gym.busyness ? (
              <div className="flex flex-col gap-2">
                <Text variant="strong">How busy is it?</Text>
                <BusynessBar point={gym.busyness} />
              </div>
            ) : (
              <Callout color="secondary">
                Live busyness isn't available for the ARC right now — only hours are shown. Campus study spaces have
                live counts on the Busyness tab.
              </Callout>
            )}

            {gym.hoursApproximate ? (
              <Callout color="yellow" actions={<OpenSiteButton url={ARC_HOURS_URL} label="Official hours" />}>
                Hours are from a maintained schedule and may change on holidays or between quarters.
              </Callout>
            ) : null}

            <div className="flex flex-col gap-1">
              <Text variant="strong">This week</Text>
              <div className="flex flex-col">
                {gym.weekHours.map((day) => (
                  <div key={day.day} className="flex items-center justify-between py-2 border-b border-separator last:border-b-0">
                    <Text variant="regular">{day.day}</Text>
                    <Text variant="small" color="secondary" className="tabular-nums">
                      {day.hours}
                    </Text>
                  </div>
                ))}
              </div>
            </div>
          </>
        )}
      </div>
    </ScrollArea>
  );
}

function GymSkeleton() {
  return (
    <div className="flex flex-col gap-5">
      <Skeleton className="h-7 w-64" />
      <Skeleton className="h-16 w-full" />
      <Separator />
      {[0, 1, 2, 3, 4].map((row) => (
        <Skeleton key={row} className="h-5 w-full" />
      ))}
    </div>
  );
}

function OpenSiteButton({ url, label }: { url: string; label: string }) {
  return (
    <Button size="small" variant="transparent" onClick={() => api.openExternal(url)}>
      <ExternalLink className="size-4" />
      {label}
    </Button>
  );
}
