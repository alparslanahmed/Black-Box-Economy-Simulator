# Black Box Economy Simulator

**v0.01 — Primitive Barter Society**

A bottom-up economic civilization laboratory. Households have limited labor, heterogeneous skills, local resources, perishable food, a durable spear, and direct barter. Nothing is told to specialize. Occupations, “prices”, and GDP are not in the simulation — they are (at most) measurements of what already happened.

> v0.01 is not intended as an accurate reconstruction of any specific prehistoric society. It is a deliberately simplified laboratory for studying bottom-up allocation, production and barter.

The player is an **observer / economic investigator**. Watch, notice something, click it, inspect *why*, form a theory, watch what happens next.

---

## Current scope

- Procedural 80×60 fictional map (meadow / forest / rocky)
- 10–100 households (default 40)
- Five goods only: berries, meat, wood, stone, spears
- Daily labor in two 300-minute blocks
- Foraging, hunting, wood, stone, spear crafting
- Food and fuel consumption, health, spoilage, death
- Spear as a durable capital good (inputs + labor + durability)
- Direct barter with double coincidence of wants (no money)
- Local demand memory (not a global price)
- Learning-by-doing
- Explainable decisions (candidate scores + components)
- Map overlays, charts, event feed, household / cell inspector
- Deterministic simulation core (independent of rendering)
- Headless mode, CSV export, trade-on vs trade-off experiments

## Current non-goals

Do **not** expect: currency, debt, banks, taxes, government, farming, buildings, employment, wages, children, seasons, weather, disease, war, Earth geography, save/load, multiplayer, or scripted “economic events”.

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
| `--households N` | Household count (UI range 10–100, default 40) |
| `--trade true\|false` | Allow barter (default true) |
| `--no-trade` | Shorthand for `--trade false` |
| `--csv PATH` | Write daily metrics |
| `--berry-regen-bp N` | Scale berry regeneration (`10000` = 100%, `5000` = 50%) |
| `--experiment trade` | 20 seeds × 720 days, trade on vs off |
| `--experiment scarcity` | Berry regen 100% vs 50% |
| `--test` | Built-in determinism / conservation tests |
| `--help` | Usage text |

## Controls

| Input | Action |
|---|---|
| `SPACE` | Pause / resume |
| `1` `2` `3` `4` | Speed 1× / 5× / 20× / 100× (simulated days per real second) |
| `WASD` / arrows | Pan map |
| Middle-mouse drag | Pan map |
| Wheel | Zoom |
| Click hut | Inspect household |
| Click cell | Inspect resources |
| Click empty | Clear selection |

Overlays (left): Normal, Resources, Trade, Specialization, Food security.

Bottom tabs: Overview, Production, Trade, Barter ratios, Specialization, Events.

---

## Simulation rules (short)

**Causes, not macroeconomic outcomes.** There is no `trade_enabled => productivity +20%`, no assigned occupation, no global market price.

- Each living household has 600 minutes/day in two scored blocks.
- Production consumes labor, local resource stock, and (for spears) wood + stone.
- Hunting is risky; a spear raises success/yield and loses durability.
- Food spoils. Wood is daily fuel. Unmet food hurts health far more than missing fuel.
- Health 0 → household dies. No births in v0.01.
- After work, a few nearby encounters may barter **only** if both sides gain **direct** utility (no proto-money).
- Agents remember what neighbors requested; that memory may affect *what they produce*, never a global price.
- Skills drift slowly by doing. “Hunter” / “Toolmaker” labels are 30-day labor shares, displayed only.

Authoritative state is integer / fixed-point (`1000` quantity units = 1 physical unit, `10000` bp = 100%).

## How determinism works

A project-owned PCG32 RNG is seeded from the world seed. **All** simulation randomness (worldgen jitter, hunt success, encounter picks, daily production order) goes through it.

Rendering, UI animation, and the “randomize seed” button must not consume simulation RNG. Same version + same seed + same config + same player actions ⇒ same history.

`blackbox.exe --test` (and `odin test tests`) hashes inventories, health, skills, stocks, trade counts, day, and RNG state after 1000 days and requires a replay to match. A different seed must not.

## How to run tests

```bat
build\blackbox.exe --test
```

```bat
odin test tests
```

Covered:

- Same seed, 1000 days, identical state hash
- Different seeds diverge
- Controlled barter conserves goods
- `trade_enabled = false` completes zero trades
- Foraging extracts real map stock into inventory
- Barter refuses one-sided gifts

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

- v0.01 households are abstract labor pools, not families.
- Inferred “toolmaker” labels are rare: a spear is a short craft job, so labor share often stays below the 55% display threshold even when tools matter.
- Observed barter ratios are **direct** pair medians. No implied cross-rate. `N/A` is a real answer.
- Terrain tiles are generated textures; some repetition / mild seams remain.
- Fallback rendering (colored cells, circles, letter icons) is used if a PNG is missing — the sim does not depend on art.
- Single-threaded, dozens of households. Not an engine, not an ECS.
- Audio is omitted on purpose.

Tuning constants live in `src/sim/config.odin`. Change those; do not inject macro bonuses.
