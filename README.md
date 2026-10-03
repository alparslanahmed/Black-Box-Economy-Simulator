# Black Box Economy Simulator

**v0.2 — Go + SQLite / React + Pixi.js**

A small society with finite resources, individual skills, family life and voluntary barter. The player observes why people make decisions and how specialization emerges.

The simulation now runs entirely in Go. React presents the interface and sends input over WebSocket; Pixi.js draws the world. The new interface follows the supplied dark woodland strategy-game reference, with 22 individually generated assets.

## Start on Windows

Prerequisites: Go 1.26+ and a current Node.js version supported by Vite (tested with Node 25.9).

```bat
build.bat
run.bat
```

Open **http://127.0.0.1:8080**. SQLite creates backend/data/blackbox.db automatically. Closing the browser does not stop a running server simulation; pause it first to freeze the world. Restarting the server restores the last committed world and controls.

## Development

Backend terminal:

```sh
cd backend
go run ./cmd/server
```

Frontend terminal:

```sh
cd frontend
npm ci
npm run dev
```

Open http://127.0.0.1:5173. Production builds are served directly by Fiber; Vite is only needed during development.

## New version layout

```text
backend/
  cmd/server/          Fiber HTTP/WebSocket application
  cmd/simtool/         Deterministic headless runner with SQLite/CSV
  cmd/experiment/      Parallel trade and scarcity experiments
  cmd/typegen/         Go → TypeScript contract generator
  internal/sim/        Complete authoritative simulation
  internal/engine/     World owner, commands, snapshots
  internal/storage/    GORM, SQLite, checkpoints and archives
  internal/protocol/   Shared transport definitions
  docs/legacy/         Historical docs, source comments, artwork and tools
frontend/
  src/components/      React interface, inspectors and charts
  src/world/           Pixi renderer, picking, camera and visual playback
  src/generated/       Generated TypeScript contract
  public/art/          22 new PNG assets and exact generation prompts
```

The Odin source, tests and obsolete build scripts have been removed after verifying the Go port. Historical documentation and extracted source comments remain in backend/docs/legacy; the independent Odin-generated fixture remains part of the Go regression tests. The root assets/ and tools/ are historical artwork references and are not part of the new build.

## Systems preserved

- Deterministic 80×60 meadow/forest/rocky world; 1–1000 initial households, default 40.
- Five goods: berries, meat, wood, stone and spears.
- Individual sleep, home, travel, work and visit schedules.
- Feasible decisions with inspectable food, fuel, tool, input, demand, skill, travel and risk scores.
- Finite local stock, regeneration, hunting, gathering and spear crafting.
- Age-dependent needs, fuel, food spoilage, health and death.
- Individual spear condition, spare tools and condition-preserving barter.
- Local demand memory, mutual-gain direct barter and observed direct barter ratios.
- Learning by doing and specialization inferred from work history.
- Pregnancy, births, marriage, ancestry, inherited constitution, residence and new camps.
- Map layers, household/person/cell inspectors, population and economy charts.
- Trade-on/off and berry-scarcity experiments.

The simulation still uses no money, assigned professions or global prices. Detailed design rules and comments remain in the [historical brief](backend/docs/legacy/PROMPT.md).

## Added persistence and concurrency

Worlds, RNG, inventories, people, ancestors, pregnancy history, skills, schedules, decisions, events, exchanges, metrics and controls are saved in SQLite. New/reset creates a separate saved world. Every accepted mutation has an idempotency key and is acknowledged after its transaction commits.

Socket readers/writers and a database worker run separately from the world owner. Independent experiments use a bounded Go worker pool. Shared resource claims and RNG draws stay ordered so the original results remain reproducible.

## Controls

- Space: play/pause. 0–5: 0.25×, 1×, 5×, 20×, 100×, 1000× target speed.
- Drag, WASD or arrows: pan. Scroll: zoom. L: follow selected person.
- Click a hut, person or cell to inspect. Resource layers select berries/game/wood/stone.
- Click **Economy Overview** for production, trade, barter ratio, specialization and people charts.
- **Event Feed** opens the full saved archive; **Saved worlds** loads a previous world.
- CSV export includes all recorded days, beyond the live graph's recent window.

## Validate

```bat
check.bat
```

Or:

```sh
cd backend
go test ./...
go test -race ./...
go vet ./...
cd ../frontend
npm run build
```

The port is checked against a complete 1000-day Odin world fixture. A separate 5000-day economic CSV also matched corrected Odin exactly after line-ending normalization. Persistence, concurrent commands, reconnect-safe IDs, WebSocket communication, archive pagination and parallel experiment determinism have regression tests.

## Documentation

- [Backend, storage, concurrency and protocol](backend/README.md)
- [Frontend, renderer and artwork](frontend/README.md)
- [Migration map and verification evidence](backend/docs/MIGRATION.md)
- [Original documentation](backend/docs/legacy/README.md)
- [Original full design brief](backend/docs/legacy/PROMPT.md)
- [Historical source comments](backend/docs/legacy/COMMENTS.md)

## Model limits

The underlying game remains a simplified economy laboratory: farming, currency, banking, wages, weather, disease and war are not implemented systems. Families use the existing simplified reproduction/residence rules. Barter ratios can be unavailable when no direct trade was observed. High requested speeds are bounded by machine throughput and durable writes.
