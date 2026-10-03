# Black Box Economy Simulator

> Historical documentation. The Odin source and build scripts have been removed after the Go migration. Use the [current README](../../../README.md) to build and run the application. Source comments are preserved in [COMMENTS.md](COMMENTS.md).

**v0.01 — Primitive Barter Society**

A bottom-up economic civilization laboratory. Households have limited labor, heterogeneous skills, local resources, perishable food, a durable spear, and direct barter. Nothing is told to specialize. Occupations, “prices”, and GDP are not in the simulation — they are (at most) measurements of what already happened.

> v0.01 is not intended as an accurate reconstruction of any specific prehistoric society. It is a deliberately simplified laboratory for studying bottom-up allocation, production and barter.

The player is an **observer / economic investigator**. Watch, notice something, click it, inspect *why*, form a theory, watch what happens next.

---

## Current scope

- Procedural 80×60 fictional map (meadow / forest / rocky)
- 10–100 households (default 40)
- Five goods only: berries, meat, wood, stone, spears
- Individual daily schedules with sleep, home time, walking, work and chosen visits
- Foraging, hunting, wood, stone, spear crafting
- Food and fuel consumption, health, spoilage, death
- Spears as durable capital goods, with individual condition preserved through barter
- Families with age-dependent needs and work capacity, pregnancy, births, marriage and inherited constitution
- Direct barter with double coincidence of wants (no money)
- Local demand memory (not a global price)
- Learning-by-doing
- Explainable decisions (candidate scores + components)
- Map overlays, charts, event feed, household / cell inspector
- Deterministic simulation core (independent of rendering)
- Headless mode, CSV export, trade-on vs trade-off experiments

## Current non-goals

Do **not** expect: currency, debt, banks, taxes, government, farming, a general building system, employment, wages, seasons, weather, disease, war, Earth geography, save/load, multiplayer, or scripted “economic events”. Newly married couples can establish a hut using wood and stone.

Those belong to later versions. v0.01 asks one question:

> Can a small society with no currency, no government and no predefined occupations spontaneously develop specialization and meaningful barter because individuals differ?

---

## Prerequisites

- Windows x86-64
- [Odin](https://odin-lang.org/) compiler (this repo’s `build.bat` looks for `%USERPROFILE%\odin\dist\odin.exe`)
- Odin’s official `vendor:raylib` (ships with the compiler)
- No package manager

If Odin lives somewhere else, edit `build.bat`.

## How to build

```bat
build.bat
```

This compiles `src` to `build\blackbox.exe` and copies `raylib.dll` next to it.

Manual:

```bat
odin build src -out:build\blackbox.exe -o:speed
copy %USERPROFILE%\odin\dist\vendor\raylib\windows\raylib.dll build\
```

## How to run

```bat
run.bat
```

Or `build\blackbox.exe` from the repo root (so `assets/` resolves).

A setup screen asks for seed, household count, and whether trade is enabled.

## How to run headless

```bat
blackbox.exe --headless --seed 12345 --days 5000
blackbox.exe --headless --seed 12345 --days 2000 --households 40 --trade false --csv results.csv
```

No window. Prints a metrics line every 50 days. Optionally writes one CSV row per simulated day.

## Command-line arguments

| Flag | Meaning |
|---|---|
| `--headless` | No window; run the simulator as fast as possible |
| `--seed N` | World seed (default `12345`) |
| `--days N` | Days to simulate in headless mode (default `500`) |
| `--households N` | Initial household count (UI 10–100; headless 1–1000, default 40) |
| `--trade true\|false` | Allow barter (default true) |
| `--no-trade` | Shorthand for `--trade false` |
| `--csv PATH` | Write daily metrics |
| `--berry-regen-bp N` | Scale berry regeneration (`10000` = 100%, `5000` = 50%, `0` = none; negative values are rejected) |
| `--experiment trade` | 20 seeds × 720 days, trade on vs off |
| `--experiment scarcity` | Berry regen 100% vs 50% |
| `--test` | Built-in determinism / conservation tests |
| `--help` | Usage text |

## Controls

| Input | Action |
|---|---|
| `SPACE` | Pause / resume |
| `0` `1` `2` `3` `4` `5` | Speed 0.25× / 1× / 5× / 20× / 100× / 1000× (simulated days per real second) |
| `WASD` / arrows | Pan map |
| Mouse drag | Pan map |
| Click person / `L` | Inspect and follow a person / toggle camera follow |
| Wheel | Zoom |
| Click hut | Inspect household |
| Click cell | Inspect resources |
| Click empty | Clear selection |

Overlays (left): Normal, Resources, Trade, Specialization, Food security.

Bottom tabs: Overview, Production, Trade, Barter ratios, Specialization, People, Events.

---

## Simulation rules (short)

**Causes, not macroeconomic outcomes.** There is no `trade_enabled => productivity +20%`, no assigned occupation, no global market price.

- Each healthy adult has a 600-minute daily budget for work, travel and visits, with up to four scored bouts. Outdoor work lasts at most 300 minutes per bout. Age, health and late pregnancy reduce the budget.
- Production consumes labor, local resource stock, and (for spears) wood + stone.
- Hunting is risky; risk preference affects the decision score. A spear raises success/yield and loses durability. Spare spears retain their individual condition when traded or put into use.
- Food spoils. Wood is daily fuel. Unmet food hurts health far more than missing fuel.
- Food is shared according to each living member's needs. Health 0 kills that person; a household becomes abandoned when its last resident dies or leaves.
- Married couples may conceive when food and health permit. The biological father is recorded at conception. Birth constitution combines the parents' average with random variation; pregnancy nutrition affects birth health.
- Nearby eligible people can marry. Direct ancestors, siblings and aunt/uncle–niece/nephew pairs are excluded; first cousins follow the configured policy.
- A visit is a scored activity with walking and time costs, normally limited to one outbound visit per household per day. Barter completes **only** if both sides gain **direct** utility based on their household's actual needs (no proto-money).
- Agents remember what neighbors requested; that memory may affect *what they produce*, never a global price.
- Skills drift slowly by doing. “Hunter” / “Toolmaker” labels are 30-day labor shares, displayed only.

Authoritative state is integer / fixed-point (`1000` quantity units = 1 physical unit, `10000` bp = 100%).

The default year is 360 days and pregnancy lasts 270 days. Age, work eligibility, pregnancy restrictions, metrics and age labels use the configured lengths. Person storage grows as births accumulate; IDs and deceased parents remain available for genealogy.

## How determinism works

A project-owned PCG32 RNG is seeded from the world seed. **All** simulation randomness (worldgen jitter, hunt success, encounter picks, daily production order) goes through it.

Rendering, UI animation, and the “randomize seed” button must not consume simulation RNG. Same version + same seed + same config + same player actions ⇒ same history.

`blackbox.exe --test` (and `odin test tests -o:speed`) hashes the configuration, household and person state, resource stocks, metrics, exchange history, day and RNG state after 1000 days and requires a replay to match. It hashes field values, including household membership, pregnancy history and tool condition, rather than allocation addresses or struct padding. A different seed must not.

## How to run tests

```bat
build\blackbox.exe --test
```

```bat
odin test tests -o:speed
```

Covered:

- Same seed, 1000 days, identical state hash
- Different seeds diverge
- Controlled barter conserves goods
- `trade_enabled = false` completes zero trades
- Foraging extracts real map stock into inventory
- Barter refuses one-sided gifts
- Barter rejects exchanges with stocked inventories when there is no mutual gain
- Household-sized food and fuel utility; deaths do not skip surviving members
- Worn spear transfers, spare lifetimes and demand memory
- CSV precision and failure reporting
- Risk preference, biological parentage and inheritance
- Population storage growth and supported household counts
- Configured year/pregnancy lengths and zero resource regeneration
- Barter medians across the retained window, including wrapped exchange history
- Ancestor and cousin marriage rules
- State hashes detect changes to decision-relevant fields

## Experiments

```bat
blackbox.exe --experiment trade
blackbox.exe --experiment scarcity
```

Trade-on vs trade-off does **not** assert that trade “wins”. It prints survival, output, food reserves, and specialization so you can see whether differences emerge. Scarcity only changes berry regeneration — not a “price” knob.

---

## Project layout

```
src/main.odin          CLI + mode switch
src/sim/               simulation core (no raylib)
src/game/              observer GUI (raylib)
src/analysis/          headless, CSV, experiments, self-tests
tests/                 `odin test` wrappers
assets/                generated terrain, huts, goods, markers
```

The simulation package has zero rendering dependency. Headless and tests never open a window.

## Known limitations

- Families are simplified: no childcare allocation, adoption, divorce or migration policy.
- Abandoned huts remain on the map. New household slots are finite; person records grow independently so deceased people do not impose a lifetime birth quota.
- Inferred “toolmaker” labels are rare: a spear is a short craft job, so labor share often stays below the 55% display threshold even when tools matter.
- Observed barter ratios are **direct** pair medians. No implied cross-rate. `N/A` is a real answer.
- Metrics retain the last 4096 days and exchange history retains 2048 trades. Ratios use all matching retained trades inside the configured window. Headless CSV records every simulated day with three decimal places; a failed write returns a nonzero process exit code.
- Terrain tiles are generated textures; some repetition / mild seams remain.
- Fallback rendering (colored cells, circles, letter icons) is used if a PNG is missing — the sim does not depend on art.
- Single-threaded, dozens of households. Not an engine, not an ECS.
- Audio is omitted on purpose.

Tuning constants live in `src/sim/config.odin`. Change those; do not inject macro bonuses.
