# AGENTS.md

## Cursor Cloud specific instructions

ZotEats is a **native macOS desktop app built on the proprietary Glaze SDK** (`@glaze/core`).
It has a Node backend (`main/`) that fetches/normalizes live UCI data over IPC and a React 19
renderer (`renderer/`). See `README.md` and `project-plans/` for the design and data sources.

### Node version
- The app requires **Node >= 24** (`package.json` `engines`).
- The default `node` on the VM (`/exec-daemon/node`) is **v22** and shadows nvm on `PATH`.
  Node 24 is installed via nvm. To use it in a session, select it and prepend it to `PATH`:
  ```bash
  export NVM_DIR="$HOME/.nvm"; . "$NVM_DIR/nvm.sh"; nvm use 24
  export PATH="$HOME/.nvm/versions/node/$(nvm version 24)/bin:$PATH"; hash -r
  ```
  (`npm install` itself also works under the default v22, since `engines` is advisory.)

### Glaze host SDK is NOT available here (key gotcha)
- All npm scripts (`build`, `dev`, `dev:renderer`, `lint`, `type-check`, `format`) are thin
  wrappers that run `node glaze.ts <cmd>`, which resolves the Glaze CLI from the **Glaze host
  tooling** at sibling paths (`../glaze-core/...` or `../../../sdk/current/@glaze/core/...`).
- `@glaze/core` is **not published to npm** and is **not present** in this Linux VM, so those
  scripts fail with `[glaze] CLI not found`. Likewise a direct `tsc`/`eslint` run fails on
  `@glaze/core/*` module resolution because the SDK type declarations only exist in the host.
- **Building, launching, linting, and type-checking the full app require the Glaze host and are
  not possible in this environment.** This is expected (see `project-plans/…` "Portability"),
  not a setup mistake. Do code/logic edits here; use the Glaze host to build/run/visually verify.

### What CAN be exercised here
- The backend service logic (`main/services/*.ts`) is plain TypeScript whose only SDK dependency
  is a `logger` from `@glaze/core/backend`. The app's core data pipeline can be run directly
  against its **live public data sources** (no keys), which are reachable from this VM:
  - Dining: `https://anteaterapi.com/v2/rest/dining` (restaurants / restaurantToday / dishes)
  - Busyness: `https://waitz.io/live/irvine`
- To run a service standalone (e.g. for a smoke test), stub the SDK `logger` in an ephemeral
  shim under `node_modules/@glaze/core` (gitignored) and run the service with `npx tsx`.
  `@shared/*` imports are type-only and erase at runtime.
