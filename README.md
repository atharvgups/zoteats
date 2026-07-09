# ZotEats 🐜🍽️

A native macOS app for UC Irvine students — dining hall menus & hours, gym hours, and live campus busyness, all in one place. Think of it as UCLA's "Nom", built for Anteaters.

Built with [Glaze](https://glazeapp.com) (React 19 + TypeScript + Tailwind).

## Features

- **Dining** — The Anteatery and Brandywine: open/closed status, today's hours, and full menus by meal period, with per-dish **calories, allergens, and dietary tags** (Vegan, Vegetarian, Halal, Kosher, Gluten-Free…). Filter the menu by dietary preference.
- **Gym** — Anteater Recreation Center (ARC) hours, open/closed, and live busyness when available.
- **Busyness** — live occupancy for tracked campus facilities (currently UCI libraries) with counts, % full, and "updated X ago".

## Data sources

All data is live from public, community-maintained UCI sources. This is an unofficial student project and not affiliated with UC Irvine.

- **Dining** — [Anteater API](https://anteaterapi.com) (`/v2/rest/dining`), the maintained UCI data API used by ICSSC's PeterPlate. Provides restaurants, per-day menus, stations, dishes, nutrition, and allergen/dietary flags. No API key required (rate-limited).
- **Busyness** — UCI's Occuspace/Waitz public feed (`https://waitz.io/live/irvine`). Coverage is whatever the feed reports (libraries today; the ARC is not currently tracked, so the Gym tab shows hours only when live counts aren't available).
- **ARC hours** — a maintained weekly schedule (verify against [campusrec.uci.edu](https://www.campusrec.uci.edu/arc/hours.html)); overridden by the live feed when the ARC appears in it.

> These are public/unofficial endpoints and may change without notice.

## Architecture

- **Backend** (`main/`) — Node services fetch, normalize, and cache the three data sources, exposed over IPC:
  - `main/services/dining.ts` — Anteater API dining (menus, hours, nutrition)
  - `main/services/occuspace.ts` — Waitz busyness feed
  - `main/services/campusrec.ts` — ARC hours + status
  - `main/handlers/{dining,gym,busyness}.ts` — IPC handlers
- **Frontend** (`renderer/`) — a `SplitView` shell with sidebar navigation and three views (Dining / Gym / Busyness), React Query for data, themed in UCI blue.
- **Shared contract** — `renderer/shared/types.ts` (imported type-only by both sides).

## Development

This is a Glaze app. Editing the source (`.glaze-sources/`) works in any editor. Static checks run anywhere:

```bash
npm install --include=dev
npm run type-check
npm run lint
```

Building, launching, and previewing the app use the Glaze host tooling (not a plain `npm run build`). See `project-plans/` for the full design + the confirmed data endpoints/IDs.
