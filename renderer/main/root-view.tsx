import { Outlet, useNavigate, useRouterState } from "@tanstack/react-router";
import * as React from "react";
import { Sidebar, SidebarList, SidebarListItem, SplitView, Status } from "@glaze/core/components";
import { useTheme, useConnection, useEnvironment } from "@glaze/core/hooks";
import { UtensilsCrossed, Dumbbell, Activity } from "lucide-react";

type NavPath = "/" | "/gym" | "/busyness";

const NAV: { path: NavPath; label: string; icon: typeof UtensilsCrossed }[] = [
  { path: "/", label: "Dining", icon: UtensilsCrossed },
  { path: "/gym", label: "Gym", icon: Dumbbell },
  { path: "/busyness", label: "Busyness", icon: Activity },
];

export function RootView() {
  useTheme();

  const connectionQuery = useConnection();
  const environmentQuery = useEnvironment();
  const navigate = useNavigate();
  const pathname = useRouterState({ select: (state) => state.location.pathname });

  React.useEffect(() => {
    return () => {
      window.glazeAPI?.glaze?.ipc?.disconnect();
    };
  }, []);

  return (
    <div className="h-full relative">
      <SplitView
        storageKey="zoteats"
        sidebar={
          <Sidebar>
            <SidebarList
              items={NAV}
              selectedItem={NAV.find((item) => item.path === pathname) ?? NAV[0]}
              onSelectedItemChange={(item) => navigate({ to: item.path })}
              getItemKey={(item) => item.path}
            >
              {NAV.map((item) => {
                const Icon = item.icon;
                return (
                  <SidebarListItem key={item.path} item={item} icon={<Icon className="size-4" />} title={item.label} />
                );
              })}
            </SidebarList>
          </Sidebar>
        }
      >
        <Outlet />
      </SplitView>

      {import.meta.env.DEV ? (
        <div className="flex flex-col items-end gap-1 fixed bottom-3 right-3 z-30">
          {connectionQuery.error ? <Status variant="error">Backend disconnected</Status> : null}
          {environmentQuery.data ? null : <Status variant="error">Dev Server not found</Status>}
        </div>
      ) : null}
    </div>
  );
}
