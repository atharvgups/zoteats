# ZotEats — UC Irvine Dining & Recreation App

## Context

The user is a rising UC Irvine freshman who wants a native macOS app modeled on UCLA's "Nom": one place to see **dining hall hours + menus** and **gym hours + live busyness** for UCI. They want to use it personally and share it with peers.

The current project is an untouched Glaze template (React 19 + TanStack Router + React Query + Tailwind v4 + `@glaze/core`). We transform it into **ZotEats**.

### Data-source reality (researched)

- **Dining menus, hours, nutrition, allergens** — UCI runs on the **CampusDish** platform (`uci.campusdish.com` / `uci.mydininghub.com`). Public JSON endpoints exist and are used by community projects. This is the reliable core. The two all-you-care-to-eat commons are **The Anteatery** (Mesa Court) and **Brandywine** (Middle Earth), plus retail locations.
- **ARC gym hours** — published at `campusrec.uci.edu/arc/hours.html`; seasonal, semi-static.
- **Live busyness** — UCI uses **Occuspace/Waitz** (`waitz.io/irvine` / `beta.occuspace.io/irvine`). Confirmed coverage: libraries. ARC coverage is **unconfirmed** and the official API needs a token we can't issue. Per user's choice: show live busyness for **whatever facilities the public feed actually tracks**, and **always** show ARC hours regardless.

### User decisions

- **Busyness:** best-available (pull live occupancy for whatever the public feed tracks; always show ARC hours). Verify ARC coverage during build.
- **Menu detail:** full menus by meal period **plus** per-dish nutrition, allergens, and dietary tags where CampusDish provides them.

### ⚠️ Endpoints to confirm during implementation

I could not hit these hosts from the sandbox. Before wiring, confirm exact URLs / IDs by referencing the maintained community repos and (once the app is running) its own network calls / logs:

- **CampusDish** — reference `github.com/icssc/ZotMeal` (PeterPlate, current) and `github.com/EricPedley/zotmeal-backend`. Expected shape: `GET https://uci.campusdish.com/api/menu/GetMenus?locationId=<id>&mode=Daily&date=MM/DD/YYYY&period=<periodId>` and a companion `GetMenuPeriods` call. Capture the **location IDs/GUIDs** for The Anteatery and Brandywine and the period IDs (breakfast/lunch/dinner/brunch). Confirm whether `uci.campusdish.com` or `uci.mydininghub.com` is the live host.
- **Occuspace/Waitz public feed** — the consumer web app at `waitz.io/irvine` fetches JSON from a public endpoint (no token). Confirm the exact URL and response shape (facility name, count, percent, capacity, busyness label) and enumerate which UCI facilities appear (note whether the ARC is present).
- **ARC hours** — parse `campusrec.uci.edu/arc/hours.html`, or if unstable, maintain a small hardcoded seasonal schedule in a service module as fallback.

## Architecture

**Backend required** — all three data sources are third-party HTTP APIs. Fetching from the renderer would hit CORS; the backend also lets us cache and normalize. So: Node services in `main/` exposed over IPC, consumed by the renderer via React Query.

### Backend (`main/`)

New service modules (`main/services/`):
- `campusdish.ts` — fetch + normalize dining locations, hours, menus (stations → dishes → nutrition/allergens/dietary tags).
- `occuspace.ts` — fetch + normalize live busyness for all tracked UCI facilities.
- `campusrec.ts` — ARC hours + open/closed computation (parsed page or fallback schedule).
- `cache.ts` — tiny in-memory TTL cache helper (menus: cache for the day; busyness: ~60–90s; hours: hours).

New IPC handlers (`main/handlers/`, registered in `main/handlers/index.ts`):
- `dining:getLocations` → `{ locations: DiningLocation[] }` (name, area, todayHours, openNow, availablePeriods).
- `dining:getMenu` `{ locationId, date, periodId }` → `{ stations: { name, items: MenuItem[] }[] }` where `MenuItem` = name, description, calories, allergens[], dietaryTags[].
- `gym:getStatus` → `{ arc: { hours, openNow, busyness?: BusynessPoint } }`.
- `busyness:getAll` → `{ facilities: BusynessPoint[] }` (name, category, count, percent, level, updatedAt).

Follow `glaze-backend-rules`, `glaze-external-api`, and `glaze-backend-performance` (child-process safety not needed; focus on fetch timeouts, caching, IPC payload shape). All shared TS types in a `main/types.ts` (or `renderer` shared) so the IPC contract is single-sourced.

### Frontend (`renderer/`)

Native macOS **SplitView** (sidebar + detail), reusing the template's `SplitView` in `root-view.tsx`. Sidebar sections → TanStack routes in `renderer/main/router.tsx`:
- **Dining** (`/`) — cards for each dining hall: open/closed pill, today's hours, meal-period tabs (Breakfast/Lunch/Dinner/Brunch). Selecting a hall shows its menu grouped by station; each dish opens a detail sheet/popover with calories, allergens, dietary tags. Dietary filter control (Vegan/Vegetarian/Halal/etc.) that filters items.
- **Gym** (`/gym`) — ARC card: open/closed, today's + week hours, and a live busyness gauge when the feed provides ARC data (otherwise a clear "live count not available" state).
- **Busyness** (`/busyness`) — list/grid of all tracked campus facilities with occupancy bars, percent, and "updated X ago".

Use React Query for all fetches (loading skeletons, error + retry states, `staleTime` aligned to backend cache). Follow `glaze-frontend-rules`, `glaze-component-patterns`, `glaze-icon-usage`. Never show mock data — if a source is empty/unavailable, show an explicit empty/unavailable state.

Preferences (dietary filter, default dining hall) in `localStorage` (frontend-only, per `glaze-data-storage`) — no backend persistence needed.

### Theming & window

- Apply UCI brand colors via `glaze-theming` seed override — UCI blue (`#0064A4`) primary, gold (`#FFD200`) accent; respect light/dark.
- Set window size via `glaze-window-sizing` in `main/index.ts` (sidebar + detail browsing app; ~960×720, min ~720×520). Keep the existing Settings window.

## Files to modify / create

Modify:
- `main/index.ts` — window sizing.
- `main/handlers/index.ts` — register new handlers.
- `renderer/main/router.tsx` — add `/gym`, `/busyness` routes.
- `renderer/main/root-view.tsx` — sidebar nav sections.
- `renderer/main/home-view.tsx` — becomes the Dining view.
- `renderer/styles.css` (or theme entry) — UCI theme seed vars.

Create:
- `main/services/{campusdish,occuspace,campusrec,cache}.ts`
- `main/handlers/{dining,gym,busyness}.ts`
- `main/types.ts` (shared IPC types)
- `renderer/main/gym-view.tsx`, `renderer/main/busyness-view.tsx`
- `renderer/components/` wrappers as needed (e.g. `busyness-bar.tsx`, `menu-item-sheet.tsx`)
- `renderer/lib/api.ts` (typed `window.glazeAPI` IPC wrappers) + `renderer/lib/prefs.ts` (localStorage)

## Execution approach

Given this is a substantial full-stack build with a small, well-defined IPC contract, implement **directly** (no sub-agents), layer by layer: (1) backend services + handlers against confirmed endpoints, (2) IPC wrappers + types, (3) frontend views + theming + window. Confirm the real endpoints/IDs first (see warning above) so services fetch live data, not guesses.

## Verification

1. `npm run type-check && npm run lint` — clean.
2. Build the app; launch it.
3. Confirm each source returns **real** data:
   - Dining: locations list, hours, at least one full menu with stations + nutrition/allergens for The Anteatery and Brandywine (check current day/period).
   - Gym: ARC hours + open/closed correct for now; busyness gauge shows live data if ARC is tracked, else the unavailable state.
   - Busyness: tracked facilities render with live counts; "updated X ago" advances on refetch.
   - Inspect app logs / network to verify the confirmed endpoints are the ones actually called; check for CORS/timeout/parse errors.
4. DOM-inspect the SplitView + route switching + menu-item sheet render correctly; verify sidebar drag region and window sizing feel native.
5. Verify empty/error/loading states by simulating a failed fetch (e.g. offline) — no crashes, no mock data.

## GitHub repository

The user wants ZotEats on a **new private repo named `zoteats`** on their GitHub account, and has opted to **grant this session GitHub access** so I create + push directly.

- `.glaze-sources` is already a git repo (branch `main`, no remote). Prep it for publishing: add a `.gitignore` (node_modules, build output, local env, `.glaze/`), and a `README.md` describing ZotEats, its features, the data sources, and the "endpoints are community/reverse-engineered, unofficial, may change" caveat. Make a clean initial/`feat: ZotEats v1` commit.
- Create the repo and push:
  ```bash
  gh repo create zoteats --private --source=. --remote=origin --push
  ```
  (or `git remote add origin <url>` + `git push -u origin main` if the repo is pre-created).
- **Environment blocker to resolve first:** this sandbox currently blocks `github.com` (network limited to `api.glazeapp.com`), blocks reading the GitHub CLI config (`~/.config/gh`), and blocks writing the repo's `.git/config` (protected path). All three must be permitted for the create + push to succeed. At execution time, attempt the commands; if any is blocked, have the user allow `github.com` (and `api.github.com`) as network hosts, un-deny `~/.config/gh`, and allow `.git/config` writes in the session's sandbox settings, then retry. Do **not** weaken or touch the Glaze-managed `.npmrc` or other protected paths.
- Never commit secrets. If an Occuspace token is ever obtained, keep it out of git (env/local only) — v1 uses only public/no-auth endpoints, so no secrets expected.
- After the successful push, record the repo URL in `PROJECT-CONTEXT.md`.

## Portability / continuing in Cursor

The user wants to be able to hand this off to Cursor (or any editor) mid-build if credits run low. To keep the work editor-agnostic and self-contained in the repo:

- **Source is standard React 19 + TypeScript + Tailwind v4** in `.glaze-sources/` — any editor can open and edit it. No proprietary code lives in the app source.
- **All knowledge lives in-repo, not in chat.** This plan file, plus `.glaze_memory/PROJECT-CONTEXT.md` (kept current after every step), together record: purpose, the confirmed endpoints/IDs, the full IPC contract + shared TS types (`main/types.ts`), file map, components used, localStorage keys, and remaining TODOs. A fresh session or a Cursor developer can resume from these alone.
- **Boundary to call out clearly:** editing code is fully portable, but **building/launching** the app relies on Glaze's host tooling (the `glaze` build path is not a plain `npm run build` and Cursor won't have it). So in Cursor you continue writing code/logic; to build, run, and visually validate, use Glaze. Keep type-check/lint (`npm run type-check && npm run lint`) as the editor-agnostic sanity check that works anywhere.
- As part of finishing each layer, leave a short **"Next steps / where I left off"** note at the top of `PROJECT-CONTEXT.md` so a handoff is always current.

## Out of scope (v1)

- Push notifications / meal reminders.
- Historical busyness prediction charts (feed provides "now"; predictive trends deferred).
- Publishing/distribution mechanics (separate from the build).

## Post-build

Create `.glaze_memory/PROJECT-CONTEXT.md` (Overview + Current State + first Recent History entry) documenting app purpose, key files, the IPC contract, the confirmed endpoints/IDs, components used, localStorage keys, and conventions.
