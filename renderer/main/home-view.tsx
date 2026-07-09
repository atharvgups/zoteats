import * as React from "react";
import { useQuery } from "@tanstack/react-query";
import {
  Badge,
  Button,
  Callout,
  EmptyState,
  ScrollArea,
  SegmentedControl,
  SegmentedControlItem,
  Separator,
  Status,
  TabsRoot,
  Tabs,
  TabsTrigger,
  TabsContent,
  Text,
  ToggleButton,
} from "@glaze/core/components";
import { ExternalLink } from "lucide-react";
import type { DiningLocation, MenuItem, MenuStation } from "@shared/types";
import { api } from "../lib/api";
import { useDietaryFilters } from "../lib/prefs";
import { Skeleton } from "../components/skeleton";

const DINING_SITE = "https://uci.mydininghub.com/en/locations";

export function HomeView() {
  const locationsQuery = useQuery({
    queryKey: ["dining", "locations"],
    queryFn: () => api.getDiningLocations(),
    staleTime: 5 * 60_000,
  });

  const locations = locationsQuery.data?.locations ?? [];

  return (
    <ScrollArea className="h-full" title="Dining" viewportClassName="px-5 pb-10">
      <div className="mx-auto w-full max-w-2xl flex flex-col gap-4 pt-2">
        <Callout color="secondary" actions={<OpenSiteButton url={DINING_SITE} label="Dining site" />}>
          Menus, hours, and nutrition are live from UCI Dining.
        </Callout>

        {locationsQuery.isLoading ? (
          <Skeleton className="h-9 w-full" />
        ) : locations.length === 0 ? (
          <EmptyState
            title="Dining unavailable"
            description="Couldn't load UCI dining locations. Check your connection and try again."
            actions={<Button onClick={() => locationsQuery.refetch()}>Retry</Button>}
          />
        ) : (
          <TabsRoot defaultValue={locations[0].id}>
            <Tabs size="large">
              {locations.map((location) => (
                <TabsTrigger key={location.id} value={location.id}>
                  {location.name}
                </TabsTrigger>
              ))}
            </Tabs>
            {locations.map((location) => (
              <TabsContent key={location.id} value={location.id} className="pt-4">
                <HallPanel location={location} />
              </TabsContent>
            ))}
          </TabsRoot>
        )}
      </div>
    </ScrollArea>
  );
}

function HallPanel({ location }: { location: DiningLocation }) {
  const [filters, setFilters] = useDietaryFilters();
  const periods = location.availablePeriods;
  const [period, setPeriod] = React.useState<string>(periods[0] ?? "");

  const menuQuery = useQuery({
    queryKey: ["dining", "menu", location.id, period],
    queryFn: () => api.getMenu({ locationId: location.id, period }),
    enabled: period !== "",
    staleTime: 10 * 60_000,
  });

  const availableTags = React.useMemo(() => {
    const set = new Set<string>();
    for (const station of menuQuery.data?.stations ?? []) {
      for (const item of station.items) {
        for (const tag of item.dietaryTags) set.add(tag);
      }
    }
    return [...set].sort();
  }, [menuQuery.data]);

  const stations: MenuStation[] = React.useMemo(() => {
    const raw = menuQuery.data?.stations ?? [];
    if (filters.length === 0) return raw;
    return raw
      .map((station) => ({
        ...station,
        items: station.items.filter((item) => filters.some((tag) => item.dietaryTags.includes(tag))),
      }))
      .filter((station) => station.items.length > 0);
  }, [menuQuery.data, filters]);

  const toggleTag = (tag: string) => {
    setFilters(filters.includes(tag) ? filters.filter((t) => t !== tag) : [...filters, tag]);
  };

  if (periods.length === 0) {
    return (
      <EmptyState
        placement="inline"
        title="Closed today"
        description={`${location.name} isn't serving meals today. Check back tomorrow or view the dining site.`}
      />
    );
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <SegmentedControl value={period} onValueChange={(value) => setPeriod(value as string)} aria-label="Meal period">
          {periods.map((p) => (
            <SegmentedControlItem key={p} value={p}>
              {p}
            </SegmentedControlItem>
          ))}
        </SegmentedControl>
        <div className="flex items-center gap-2">
          <Status variant={location.openNow ? "success" : "neutral"}>{location.openNow ? "Open" : "Closed"}</Status>
          {location.todayHours ? (
            <Text variant="small" color="tertiary">
              {location.todayHours}
            </Text>
          ) : null}
        </div>
      </div>

      {availableTags.length > 0 ? (
        <div className="flex flex-wrap items-center gap-1.5">
          <Text variant="small" color="tertiary" className="mr-1">
            Filter:
          </Text>
          {availableTags.map((tag) => (
            <ToggleButton
              key={tag}
              size="small"
              variant="transparent"
              pressed={filters.includes(tag)}
              onPressedChange={() => toggleTag(tag)}
            >
              {tag}
            </ToggleButton>
          ))}
        </div>
      ) : null}

      {menuQuery.isLoading ? (
        <MenuSkeleton />
      ) : menuQuery.isError ? (
        <Callout color="red" role="alert" actions={<Button size="small" onClick={() => menuQuery.refetch()}>Retry</Button>}>
          Couldn't load the {location.name} menu. {(menuQuery.error as Error).message}
        </Callout>
      ) : stations.length === 0 ? (
        <EmptyState
          placement="inline"
          title={filters.length > 0 ? "Nothing matches your filters" : "No menu posted"}
          description={
            filters.length > 0
              ? "Try clearing a dietary filter to see more options."
              : `${location.name} isn't serving ${period.toLowerCase()} today. Try another meal.`
          }
        />
      ) : (
        <div className="flex flex-col gap-6">
          {stations.map((station) => (
            <StationSection key={station.name} station={station} />
          ))}
        </div>
      )}
    </div>
  );
}

function StationSection({ station }: { station: MenuStation }) {
  return (
    <section className="flex flex-col gap-1">
      <Text variant="strong">{station.name}</Text>
      <div className="flex flex-col">
        {station.items.map((item) => (
          <MenuItemRow key={item.id} item={item} />
        ))}
      </div>
    </section>
  );
}

function MenuItemRow({ item }: { item: MenuItem }) {
  return (
    <div className="flex flex-col gap-1 py-2.5 border-b border-separator last:border-b-0">
      <div className="flex items-baseline justify-between gap-3">
        <Text variant="regular" className="min-w-0">
          {item.name}
        </Text>
        {item.calories !== null ? (
          <Text variant="small" color="tertiary" className="shrink-0 tabular-nums">
            {item.calories} cal
          </Text>
        ) : null}
      </div>

      {item.description ? (
        <Text variant="small" color="secondary">
          {item.description}
        </Text>
      ) : null}

      {item.dietaryTags.length > 0 || item.allergens.length > 0 ? (
        <div className="flex flex-wrap items-center gap-1 pt-0.5">
          {item.dietaryTags.map((tag) => (
            <Badge key={`d-${tag}`} color="green">
              {tag}
            </Badge>
          ))}
          {item.allergens.map((allergen) => (
            <Badge key={`a-${allergen}`} color="orange">
              {allergen}
            </Badge>
          ))}
        </div>
      ) : null}
    </div>
  );
}

function MenuSkeleton() {
  return (
    <div className="flex flex-col gap-6">
      {[0, 1].map((section) => (
        <div key={section} className="flex flex-col gap-2">
          <Skeleton className="h-4 w-32" />
          <Separator />
          {[0, 1, 2].map((row) => (
            <div key={row} className="flex flex-col gap-1.5 py-1">
              <Skeleton className="h-4 w-48" />
              <Skeleton className="h-3 w-64" />
            </div>
          ))}
        </div>
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
