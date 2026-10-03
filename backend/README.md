# Black Box backend

Go 1.26+, Fiber 3, GORM and SQLite. The SQLite driver is pure Go; normal builds do not need a C compiler.

## Run

From this directory:

```sh
go run ./cmd/server
```

The production app is at http://127.0.0.1:8080 after building ../frontend. During development, run npm run dev in ../frontend and open port 5173. Options: -addr, -db and -web. The server defaults to loopback.

## Ownership and concurrency

- One goroutine owns the active world, its PCG generator and every economic mutation. Commands are serialized through a bounded channel.
- One commit worker writes a complete checkpoint and its observations in a SQLite transaction. The owner waits for that commit before publishing or acknowledging the result.
- Each WebSocket has a reader and one writer. Its live snapshot queue holds only the newest update, so a slow viewer cannot block the world. Replies have a separate bounded queue.
- Independent experiments run in a bounded worker pool. Each world has its own random generator; results retain seed order regardless of scheduling.
- Competing resource claims and random draws retain the original sequential order. Parallelizing those mutations would change the experiment.
- Pan, selection and history commands do not reset the simulation's time budget.

The requested speed is a target in simulated days per second. SQLite durability, simulation cost and snapshot encoding can limit the achieved speed. Batches are capped at ten days so commands remain serviceable.

## Persistence

Default database: data/blackbox.db. SQLite uses WAL, synchronous=FULL, foreign keys and a five-second busy timeout.

| Table | Contents |
| --- | --- |
| world_records | Versioned gzip/JSON checkpoint, seed, revision, population and timestamps |
| settings | Active saved world |
| metric_records | Every completed day's metrics |
| event_records | Full chronological event archive |
| exchange_records | Every completed barter |
| command_records | Accepted mutations and unique request IDs |
| experiment_records | Experiment options, ordered results and CSV |

A checkpoint contains the full world: resources and extraction, people including deceased ancestors, households, pregnancies and conception fathers, individual spear conditions, inventories, skills, schedules, paths, decisions, demand memory, random state, counters and all simulation rings. Pause/speed and map selection/camera are saved too. Modal search/filter text is presentation state.

Commands are acknowledged only after commit. A failed write restores the last checkpoint and pauses the world. A revision condition rejects stale writers. Do not run two servers on the same database; use separate database paths for independent worlds. Normal exit or forced process termination cannot expose half a transaction. On restart, only committed days are resumed; no offline time is simulated.

To back up, stop the server and copy the database, or use SQLite's backup API. While running, the WAL is part of the database.

## WebSocket protocol

/ws is the only game-data endpoint. /health reports readiness; other HTTP requests serve the compiled frontend.

Send JSON commands with a unique request_id. Each response contains version: 1 and type. Successful mutations return ack, invalid operations return error. Live state arrives as snapshot. Retrying the same mutation ID does not apply it twice. Browser commands include their active world_id so reconnect retries cannot mutate another world accidentally.

| Command | Fields / response |
| --- | --- |
| play, pause | Start/stop automatic days |
| speed | speed: 0.25–1000 |
| step | days: 1–100; pauses |
| trade | trade: boolean |
| regeneration | berry_regen_bp: 0–100000; 10000 means 100% |
| view | Complete validated ViewState |
| new_world | seed as uint64 decimal string; households: 1–1000; optional trade/regeneration |
| reset | Same seed/settings in a new saved world |
| list_worlds | worlds response |
| load_world | world_id; loads paused |
| snapshot | Request current committed snapshot |
| events | Optional category and before cursor; 100 events per page |
| history | Optional before day; up to 4096 daily records |
| export_csv | csv response containing all daily metrics |

Seed and hash travel as strings to avoid JavaScript uint64 precision loss. Quantities use 1000 integer units; skills/health/ratios use basis points where documented in types. The browser interpolates backend-derived visual keyframes but cannot decide activities, paths, eligibility or economic outcomes.

internal/protocol/types.go is the transport source of truth. Run:

```sh
go generate ./internal/protocol
```

This derives frontend/src/generated/protocol.ts from Go fields and JSON tags. Do not hand-edit the generated file. Add protocol fields on the Go side first.

## Headless simulation and experiments

```sh
go run ./cmd/simtool -seed 12345 -days 500 -csv data/run.csv
go run ./cmd/experiment -kind trade -workers 4 -csv data/trade.csv
go run ./cmd/experiment -kind scarcity -workers 4
```

simtool saves a resumable world and every daily observation to data/headless.db in batches of 25 days and on completion. Use -db="" only for stateless benchmarks. Its world can be opened by starting the server with that database. Trade defaults to 720 days × 20 paired seeds; scarcity to 360 days × 8 paired seeds. Experiments persist their full results in SQLite. Their output totals include all days even beyond the 4096-day in-memory metric ring.

## Check

```sh
go test ./...
go test -race ./...
go vet ./...
```

The race build needs a supported C compiler. The ordinary build and SQLite driver do not.

See [migration evidence](docs/MIGRATION.md), [historical design](docs/legacy/PROMPT.md) and [legacy documentation](docs/legacy/README.md).
