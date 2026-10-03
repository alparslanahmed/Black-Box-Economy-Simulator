# Historical source comments

Comments extracted from the corrected Odin source before its removal. Original file names and line numbers identify their context. The active implementation is in backend/internal and frontend/src; the historical design brief and migration map explain the corresponding systems.

## src/analysis/selftest.odin

```text
132: A is well fed (meat) and has no stone / no spear → wants stone.
133: B is starving with stone → wants meat.
169: last-day successful trades
220: A has meat, B has nothing B wants to give that A wants.
228: Both have tradable goods and want additional goods, but identical
229: preferences and inventories leave no mutually beneficial exchange.
310: 0.005 of visual day is a bit more than one frame at 0.25x / 60fps.
312: 1.8 cells in milli
```

## src/game/charts.odin

```text
116: overlay each enabled series with its own min/max — use global max among enabled
```

## src/game/map_view.odin

```text
61: Left-click only pans after the cursor actually moves, so clicks still select.
370: Dark halo so the marker never melts into grass/rock.
380: Mars: short arrow out of the top-right.
389: Venus: cross below.
444: People first — they sit on top of huts and cells.
```

## src/game/ui.odin

```text
46: Old 12–14px default-font sizes were unreadable. Floor and lift them.
```

## src/sim/config.odin

```text
3: Tunable economic constants. Authoritative simulation uses only these values
4: plus the world seed — never frame time, never renderer state.
5:
6: Quantity: 1000 = 1 physical unit
7: Basis points: 10000 = 100%
8: Skill: 10000 = average (1.0x)
9: Health: 10000 = full
10: Time: integer minutes
62: adult cap on work + travel + visit
63: typical outdoor work stint, not including walking
107: one-way minutes at average adult walk speed
123: milli-days, 1000 = 1 day
132: percent of max per day
136: 5500 = 55%
151: Later these map onto "culture". They are just knobs for now.
156: per nearby encounter
159: church/law can later set this false
160: patrilocal weight
161: matrilocal
162: neolocal
163: living members that push toward a new hut
```

## src/sim/decisions.odin

```text
107: After a full work day, staying home beats a leftover social walk.
179: Penalize the spread of the two outcomes, weighted by failure probability.
180: Expected utility already accounts for the mean; this is risk aversion.
299: don't craft while starving
338: You do not see the other camp's stores. You walk because YOU need
339: something and YOU can spare something, and maybe you remember a neighbor.
349: A first spear is hugely useful at home, but that is not a reason
350: to walk to every neighbor every day hoping they have one.
365: Only real surplus: giving it barely hurts.
410: Hungry people will not wander far unless they are going for food.
428: Work first on a normal day; leftover evening walks need a stronger reason.
493: search heuristic only
```

## src/sim/events.odin

```text
16: 0 = oldest
```

## src/sim/households.odin

```text
53: Death compacts h.members. Visit the original members exactly once.
87: deterministic fractional leftover via leftover qty itself; keep at least
88: 1 unit loss when stock is large enough to matter
```

## src/sim/marriage.odin

```text
91: Parents are allocated before their children. This also bounds traversal
92: for malformed records rather than recursing indefinitely through a cycle.
101: Direct ancestors, siblings, and aunt/uncle–niece/nephew are always forbidden.
102: First cousins follow marry_allow_cousins (later a church/law culture knob).
392: Walk to the new home this afternoon.
```

## src/sim/metrics.odin

```text
42: household median filled after people loop
```

## src/sim/people.odin

```text
52: Mouths to feed, as a fraction of one adult daily nutrition. 1000 = 1 adult.
137: Cap on work + walking + visiting for the day. Sleep and home time are separate.
188: Wake after the night portion of sleep; sleep_start is when they must be home.
205: Walking speeds stay close; distance is what makes trips long.
286: Spread living walkers around the hut so they do not stack.
302: Drop one redundant hold (same cell, later t wins) so a new keyframe fits.
383: True sim-minute interpolation (t is 0..10000 through the 1440-minute day).
437: Collapse hut-scatter / duplicate holds so playback is walk → stand → walk,
438: not a chain of one-frame twitches.
731: Drift toward inherited constitution when fed.
847: spawn_person may grow the people array; preserve IDs before that happens.
866: Newborns start at age zero and are first ticked the following day.
```

## src/sim/rng.odin

```text
3: Project-owned PCG-XSH-RR 32-bit generator.
4: Simulation randomness MUST go through this. Rendering and UI never call it.
29: Inclusive range [lo, hi]. If hi < lo the bounds are swapped.
```

## src/sim/spears.odin

```text
3: Quantity remains in Inventory. The active spear and every spare retain their
4: own condition, including when two worn spears meet in the same household.
```

## src/sim/trade.odin

```text
43: still learn what the other requested
94: deterministic tie-break
119: Validate both legs before mutating either inventory.
133: Learn what the other household bought from us.
```

## src/sim/types.odin

```text
109: milli-cells
110: 0..10_000 through the day
122: inherited baseline, 10000 = average
128: sum of household food-days-milli
130: biological father captured at conception
133: -1 if no living marriage
138: household id for Visit, else -1
142: minute of the current day while planning
154: -1 none; partner household visited today
179: berry, game, wood, stone today
196: household id for Visit, else -1
197: labor, linger, or rest minutes planned for this bout
254: living people
258: living, no living spouse
259: of living people
261: of living marriageable people
263: crude birth rate; 28000 = 28.0 births per 1000 people per year
264: total fertility; 2100 = 2.10 children per woman
265: trailing window used for CBR/TFR
287: QTY_SCALE = 1.0 berries per 1 unit; -1 = N/A
288: for CSV *per_berry columns; -1 = N/A
316: slot allocated (new camps reuse empty slots)
320: average of living members, overlay/analytics
327: individual durability; last spare is used/sold next
329: average of working-age members
366: 10000 = as configured
529: One-way walk time in minutes at the given speed (10000 = average adult).
543: Round-trip at average adult speed. Used by household-level search.
```

## src/sim/utility.odin

```text
3: Direct household utility of a hypothetical inventory. Used for both
4: production scoring and barter. Contains NO exchange-value / proto-money term.
32: 1000 = 1 day
39: 0-1 day: extreme
42: 1-2 days: high, but other work can compete
105: continuous at the first whole unit
113: Fuel utility already counts wood. Extra only for the next spear's wood.
159: positive = cost of giving
```

## src/sim/world.odin

```text
40: People keep permanent IDs for genealogy. Growth invalidates ^Person pointers;
41: callers of spawn_person must reacquire them by ID after a possible birth.
105: Hash values field by field: no padding, allocation addresses or unused slots.
106: Reflection makes new fields in Config, Person and Household participate too.
164: durability without a spear is illegal except mid-break handling
170: dead households may keep leftover inventory; they must not act
```

## src/sim/worldgen.odin

```text
11: Integer value noise in 0..10000
76: If rocky is a tiny speckle, leave it. Proportions are advisory; clustered
77: noise is the source of truth.
129: Pick a handful of loose cluster centers biased toward different terrains.
191: fallback: first free cell
```

## tests/regressions.odin

```text
327: A directory cannot be replaced by a CSV file; this creates no test file.
```
