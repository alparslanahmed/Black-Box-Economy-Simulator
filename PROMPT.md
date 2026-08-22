# BLACK BOX ECONOMY SIMULATOR

## v0.01 — Primitive Barter Society

### Master Implementation Specification for Coding Agent

You are the principal engineer, game designer, simulation programmer, UI programmer, technical artist, and asset-generation agent for the first playable prototype of a game called **Black Box Economy Simulator**.

You must IMPLEMENT the game, not merely design or describe it.

Use **Odin** as the programming language and **raylib through Odin's official `vendor:raylib` bindings** for rendering, input, window management, and basic audio if eventually needed.

You must also generate all required visual assets yourself using your available image-generation capability. Do not download or copy copyrighted game assets.

Work autonomously. Do not repeatedly ask me implementation questions. When a minor detail is unspecified, choose the simplest implementation consistent with this document.

Compile and test continuously as you work.

The goal is to end with a working Windows desktop prototype.

---

# 1. THE PRODUCT VISION

Black Box Economy Simulator is a bottom-up economic civilization simulation.

The long-term game will eventually simulate economic development from primitive subsistence societies through:

* barter;
* specialization;
* agriculture;
* storage;
* property;
* towns;
* metallurgy;
* accounting;
* debt;
* commodity money;
* currencies;
* states;
* taxation;
* wage labor;
* banking;
* companies;
* industrialization;
* financial markets;
* central banking;
* globalization;
* automation;
* modern economies.

However:

**DO NOT BUILD ANY OF THAT YET.**

Version 0.01 has exactly one scientific question:

> Can a small society with no currency, no government and no predefined occupations spontaneously develop specialization and meaningful barter solely because individuals have different skills, needs, resources, locations, tools, information and opportunity costs?

If the answer is not yet convincingly "yes", adding historical systems is premature.

---

# 2. FUNDAMENTAL SIMULATION PHILOSOPHY

The most important rule of the entire project is:

> PROGRAM CAUSES, NOT MACROECONOMIC OUTCOMES.

Never write logic equivalent to:

```text
trade_enabled => productivity +20%

specialization => production +15%

scarcity => price +30%
```

There is no such system.

Instead:

* people have limited labor time;
* different people have different productivity;
* resources are geographically distributed;
* goods have actual uses;
* tools affect actual production;
* agents choose activities;
* agents exchange goods when both benefit;
* resources become scarce because people consume them;
* exchange ratios emerge from actual trades;
* occupations are inferred from behavior;
* productivity changes because people allocate labor differently.

If specialization increases output, that must happen because specialized households actually spent more labor on activities where they were comparatively productive.

If a good becomes more valuable during scarcity, that must happen because agents actually become more reluctant to give it up and more willing to sacrifice other goods to obtain it.

Never directly manipulate a macro statistic to make the simulation "look economically correct."

---

# 3. SECOND FUNDAMENTAL RULE: THE SIMULATION MUST BE EXPLAINABLE

The game is called **Black Box Economy**, but its purpose is to OPEN the black box.

For every important outcome, we eventually need to answer:

> WHY DID THIS HAPPEN?

Therefore every household decision should be inspectable.

If Household #17 decided to hunt today, the UI should be capable of showing approximately:

```text
Chosen action: Hunt with spear

Reasons:
Food reserve below preferred level      +4,200
High hunting skill                      +1,380
Expected meat production                +1,250
Strong recent demand for meat           +620
Travel cost                              -190

Total score                             7,260
```

It does not need to expose internal implementation jargon.

But it must expose enough information for the player/developer to understand the decision.

The simulation must generate an event history.

---

# 4. THIRD FUNDAMENTAL RULE: DETERMINISM

Given:

* the same game version;
* same configuration;
* same world seed;
* same starting state;
* same future player actions;

the simulation must generate the same history.

Do NOT use uncontrolled global randomness.

Implement a project-owned deterministic PRNG.

Recommended:

* PCG32;
* explicit 64-bit state;
* explicit seed;
* no dependence on system time after world creation.

Implement helpers such as:

```text
rng_next_u32
rng_range
rng_chance_basis_points
rng_shuffle
```

All simulation randomness must go through this simulation RNG.

Rendering must NEVER consume simulation RNG values.

UI animations must NEVER consume simulation RNG values.

This separation is mandatory.

---

# 5. NUMERIC REPRESENTATION

Avoid floating-point arithmetic for authoritative economic state whenever practical.

Use integer/fixed-point representation.

Recommended conventions:

```text
Quantity:
i64

1000 quantity units = 1 physical unit

Basis points:
10,000 = 100%

Skill:
10,000 = average productivity

Health:
10,000 = full health

Time:
integer minutes
```

Examples:

```text
1 berry unit = 1000
2.5 meat units = 2500
skill 1.25x = 12500
75% chance = 7500 basis points
```

Floating-point is acceptable for:

* rendering;
* camera transforms;
* chart coordinates;
* non-authoritative visual interpolation.

Simulation state must remain stable and reproducible.

---

# 6. VERSION 0.01 SCOPE

Implement:

* a procedural fictional local map;
* 40 primitive households by default;
* heterogeneous household abilities;
* natural resources;
* limited daily labor;
* food consumption;
* fuel consumption;
* health;
* gathering;
* hunting;
* primitive spear production;
* tool durability;
* local resource depletion/regeneration;
* direct barter;
* limited trading opportunities;
* double coincidence of wants;
* memory of demand/trades;
* endogenous specialization;
* observed barter exchange ratios;
* resource scarcity;
* event logging;
* household inspection;
* macro metrics generated from micro state;
* charts;
* map overlays;
* deterministic headless simulation;
* CSV metric export;
* basic experiment support.

Do NOT implement:

* currency;
* coins;
* abstract money;
* banks;
* loans;
* debt;
* interest;
* taxation;
* government;
* public projects;
* roads;
* farming;
* domestication;
* research;
* technology tree;
* buildings constructed dynamically;
* businesses;
* corporations;
* employment;
* wages;
* population reproduction;
* children;
* family demographics;
* inheritance;
* social classes;
* politics;
* religion;
* war;
* diplomacy;
* multiple civilizations;
* international trade;
* seasons;
* weather;
* disease;
* actual historical Earth;
* multiplayer;
* save/load;
* Steam integration;
* achievements;
* quests;
* scripted economic events.

If tempted to implement these, STOP.

They belong to later versions.

---

# 7. PLAYER IDENTITY IN V0.01

The player is currently only an:

> OBSERVER / ECONOMIC INVESTIGATOR.

There are no economic intervention powers yet.

The player can:

* pause;
* resume;
* change simulation speed;
* inspect households;
* inspect resources;
* inspect trades;
* view analytical overlays;
* view charts;
* view emergent exchange ratios;
* inspect why an agent acted;
* restart the same seed;
* generate a new seed.

The game loop is:

```text
WATCH
↓
NOTICE SOMETHING
↓
CLICK IT
↓
INVESTIGATE
↓
FORM A THEORY
↓
WATCH WHAT HAPPENS NEXT
```

Later versions will become:

```text
Observe
→ Investigate
→ Intervene
→ Observe consequences
```

But v0.01 stops before intervention.

---

# 8. WORLD SCALE

Default:

```text
40 households
80 x 60 map cells
1 day per simulation tick
30 days = analytical month
360 days = analytical year
```

Allow household count to be configured before starting:

```text
Minimum: 10
Default: 40
Maximum UI-supported prototype value: 100
```

This limit is NOT an architectural limit.

The simulation should eventually scale much higher.

---

# 9. WHAT A "HOUSEHOLD" MEANS

Do not simulate individuals yet.

One Household is an abstract productive family unit.

It represents enough people to provide one combined labor pool.

Every household has:

```text
Household_ID
home_location
alive
health

inventory

skills

daily labor availability

preferred food reserve
trade openness
risk preference

recent activity history

recent trades

observed demand memory

current spear durability if owned

current decision
decision explanation
```

Do NOT define an occupation field.

There must be no:

```text
occupation = HUNTER
```

or:

```text
profession = TOOLMAKER
```

Occupation is ANALYTICS ONLY.

Infer it from actual labor allocation.

---

# 10. DAILY LABOR

Each household receives:

```text
600 productive minutes per day
```

Split this into:

```text
Block A = 300 minutes
Block B = 300 minutes
```

Before each block, the household reevaluates what it should do.

Possible work activities:

```text
FORAGE_BERRIES
HUNT
GATHER_WOOD
GATHER_STONE
CRAFT_SPEAR
REST / NO PRODUCTIVE ACTION
```

Trading occurs after productive work and does not use these work blocks in v0.01.

Later versions can model merchant labor explicitly.

---

# 11. GOODS IN V0.01

Use exactly these five economic goods:

```text
BERRIES
MEAT
WOOD
STONE
SPEAR
```

No others.

Each Good Definition should include relevant physical attributes.

Example conceptual structure:

```text
Good_Definition {
    id
    display_name

    nutrition
    daily_spoilage_bp

    min_trade_quantity

    is_tool
    is_food
}
```

Suggested characteristics:

## Berries

```text
Food
Nutrition per 1 unit: 1
Highly perishable
Daily spoilage: approximately 20–25%
Divisible
```

## Meat

```text
Food
Nutrition per 1 unit: 2.5
Highly perishable
Daily spoilage: approximately 25–35%
Divisible
```

Tune these if the simulation is obviously unstable.

## Wood

```text
Raw material
Fuel
Non-perishable
Divisible
```

## Stone

```text
Raw material
Non-perishable
Divisible
```

## Spear

```text
Durable productive tool
Indivisible
Non-perishable
Has durability
Improves hunting
```

There is NO intrinsic money value attached to any good.

Never store:

```text
price
gold_value
currency_value
```

inside a Good definition.

---

# 12. SURVIVAL NEEDS

Households need:

## Food

Target daily nutrition:

```text
approximately 6 nutrition units/day
```

Make this configurable.

Both berries and meat satisfy food need according to nutritional content.

Households should prefer maintaining several days of food reserves.

Generate household reserve preferences around approximately:

```text
3–6 days
```

This heterogeneity matters.

Food scarcity should strongly increase the household's subjective marginal value of food.

Food abundance should reduce it.

Use a nonlinear utility curve.

The first day's food is extremely valuable.

The tenth stored day is much less valuable.

Do not use linear utility.

A simple piecewise curve is acceptable.

For example conceptually:

```text
food reserve < 1 day:
EXTREME value

1–2 days:
very high

2–4 days:
high

near preferred reserve:
moderate

far above reserve:
low
```

## Firewood

Each household also consumes a small amount of wood every day as fuel.

Suggested:

```text
0.20–0.30 wood units/day
```

A wood shortage should cause a small health penalty.

Food shortage must be much more dangerous than wood shortage.

This second survival need makes wood economically meaningful even for households that do not make spears.

---

# 13. HEALTH

Use:

```text
10,000 = 100% health
```

If food needs are met:

* recover slowly toward full health.

If partially unmet:

* health declines.

If completely unmet:

* health declines substantially.

Fuel shortage causes a smaller penalty.

If health reaches zero:

```text
household.alive = false
```

Remove it from productive activity and trading.

Do not add births yet.

This means poorly functioning economies can shrink and eventually collapse.

That is acceptable.

---

# 14. INITIAL INVENTORY

Give households enough initial resources to prevent immediate random extinction.

Suggested starting inventory per household:

```text
2–4 days food equivalent
small amount of wood
0–1 stone
approximately 20–30% probability of starting with a spear
```

Randomize within controlled limits using the world seed.

Do not give everybody identical inventory.

---

# 15. HOUSEHOLD SKILLS

Each household has separate productivity skill values for:

```text
FORAGING
HUNTING
WOOD_GATHERING
STONE_GATHERING
SPEAR_CRAFTING
```

Average:

```text
10,000 = 1.0x
```

Generate starting skills approximately in:

```text
7,000–13,000
```

Create meaningful heterogeneous comparative advantage.

One method:

1. Generate every skill independently around average.
2. Select one random activity and boost it by approximately 10–30%.
3. Clamp to sensible bounds.

Do not assign a profession.

Agents merely possess differences.

---

# 16. LEARNING BY DOING

Whenever a household performs an activity, slowly improve that relevant skill.

Example:

```text
+1 or +2 basis points per completed 300-minute work block
```

Clamp skill to approximately:

```text
20,000 maximum
```

This should create mild path dependence.

Repeated hunting gradually makes a household better at hunting.

Repeated crafting gradually improves crafting.

Do not make improvement so fast that initial differences disappear within weeks.

---

# 17. MAP

Create a fictional procedural 2D top-down land region.

Do NOT use a real Earth map.

Map:

```text
80 x 60 cells
```

Terrain types:

```text
MEADOW
FOREST
ROCKY
```

Do not add rivers yet.

Do not add roads.

Do not add ocean.

Generate terrain using deterministic seeded noise or clustered procedural generation.

The result should look natural rather than random television static.

Desired approximate proportions:

```text
Meadow: 45–55%
Forest: 30–40%
Rocky: 10–20%
```

Clusters must exist.

Forests should form woodland regions.

Rocky terrain should form patches/ridges.

---

# 18. RESOURCE DISTRIBUTION

Each map cell may contain resource stock.

Resource categories:

```text
BERRY_STOCK
WOOD_STOCK
STONE_STOCK
GAME_STOCK
```

Terrain influences resource capacity.

## Meadow

Good berries.

Moderate game.

Low wood.

Very little stone.

## Forest

Moderate berries.

High wood.

High game.

Low stone.

## Rocky

Low berries.

Very low wood.

Low game.

High stone.

Each resource has:

```text
current_stock
maximum_stock
daily_regeneration
```

Suggested behavior:

### Berries

Fast regeneration.

### Game

Slow regeneration.

### Wood

Very slow regeneration.

### Stone

No regeneration in this prototype.

Resource extraction MUST physically reduce local stock.

Do not give a production bonus based only on terrain while ignoring stock.

---

# 19. HOUSEHOLD LOCATIONS

Place household homes around several loose clusters in the region.

Do NOT place everybody on the same tile.

Do not build a city.

Homes are fixed for v0.01.

Migration comes later.

Location matters because travel takes time.

A household near a forest has a real advantage when collecting wood or hunting there.

A household near rocky terrain has a real advantage collecting stone.

This can generate geographic specialization.

---

# 20. TRAVEL COST

A household searching for a resource should identify attractive resource cells within a configurable search radius.

Suggested:

```text
12–16 cells
```

Travel reduces productive time.

A simple implementation is sufficient.

Example:

```text
travel_minutes =
distance_in_cells
* minutes_per_cell
* 2 for round trip
```

Then:

```text
effective_work_minutes =
300 - travel_minutes
```

If effective minutes <= 0:

that resource is not realistically accessible in that work block.

Use Euclidean or octile distance.

Do not implement A* pathfinding yet.

There are no impassable terrain barriers in v0.01.

Terrain appearance should matter for resource distribution, not route finding yet.

---

# 21. PRODUCTION ACTIVITIES

All production must consume actual:

* labor time;
* resource stock;
* required input goods.

Nothing appears from nowhere.

---

## FORAGE BERRIES

Inputs:

```text
labor
nearby berry stock
```

Output:

```text
berries
```

Productivity depends on:

```text
foraging skill
effective labor minutes
available berry stock
```

Suggested average result:

An average household spending an entire 600-minute day foraging should produce roughly enough food for itself plus only a modest surplus.

Do NOT make independent subsistence trivially easy.

---

## GATHER WOOD

Inputs:

```text
labor
wood resource
```

Output:

```text
wood
```

Depends on:

```text
wood gathering skill
distance
wood stock
```

---

## GATHER STONE

Inputs:

```text
labor
stone resource
```

Output:

```text
stone
```

Depends on:

```text
stone gathering skill
distance
stone stock
```

---

# 22. HUNTING

Hunting is risky.

Inputs:

```text
labor
nearby game stock
optional spear
```

Without spear:

* lower success probability;
* lower expected yield.

With spear:

* substantially higher success probability/yield;
* spear durability decreases.

Suggested rough target:

```text
Without spear:
success probability ~35–50% for average skill

With spear:
success probability ~65–80% for average skill
```

On successful hunt:

* consume some local game stock;
* produce meat.

Do not produce hide yet.

We deliberately postpone it until clothing/leather production exists.

Skill modifies hunting probability/productivity.

Risk should make hunting potentially high-output but less reliable than foraging.

This difference is desirable.

---

# 23. SPEAR

Spear recipe:

```text
WOOD
+
STONE
+
LABOR
=
SPEAR
```

Suggested physical requirement:

```text
1 wood
1 stone
```

Suggested average crafting requirement:

```text
approximately one 300-minute work block
```

Crafting skill affects work progress.

Use persistent crafting progress so a low-skill crafter may need more than one block and a high-skill crafter can gradually gain efficiency.

A spear has durability.

Suggested:

```text
100 durability points
```

Each hunting attempt consumes durability.

Example:

```text
10 durability/hunt attempt
```

When durability <= 0:

destroy the spear.

A spear is therefore a CAPITAL GOOD.

We are not programming "capital."

We are simply creating a durable item that increases future productivity.

That distinction is essential.

---

# 24. SPOILAGE

Food must spoil.

Implement deterministic percentage spoilage at the end of each day.

Initial suggested rates:

```text
Berries: 20–25% / day
Meat:    25–35% / day
```

Tune if necessary.

Do not allow negative inventory.

Track spoilage as an economic event/metric.

Food spoilage creates pressure to:

* trade surplus;
* avoid excessive hoarding;
* specialize;
* produce at useful times.

---

# 25. HOUSEHOLD DECISION MAKING

THIS IS THE MOST IMPORTANT SYSTEM.

Do NOT create scripted behavior such as:

```text
if household.hunter_skill > 1.2:
    always_hunt()
```

Every 300-minute block, evaluate candidate actions.

Candidates:

```text
forage
hunt
gather wood
gather stone
craft spear
rest
```

Evaluate every feasible action.

The action score should emerge from several components.

Conceptually:

```text
ACTION SCORE =
expected direct utility gain
+
expected future productive value
+
expected barter opportunity
+
skill/comparative advantage effect
-
travel/opportunity costs
-
risk cost
```

Store each component for the UI.

---

# 26. DIRECT UTILITY

Households care directly about things that improve their own circumstances.

## Food

Very high utility when food reserves are low.

Marginal utility falls when food reserves are high.

## Wood

Direct utility from required daily fuel.

Additional value if needed for spear construction.

## Stone

Useful when needed for spear construction.

## Spear

Value depends strongly on:

* whether household already owns a usable spear;
* household's hunting skill;
* expected future hunting;
* current spear durability.

A second spear should generally have much less direct utility than the first.

This matters because a good toolmaker should prefer exchanging surplus spears rather than hoarding 30 spears.

---

# 27. TRADE OPPORTUNITY IN PRODUCTION DECISIONS

Agents are allowed to learn:

> Other households often want the things I make.

Therefore a skilled crafter with enough food can choose to create an extra spear because it expects to barter the spear for food later.

Likewise a strong hunter may hunt beyond its own immediate food requirement because meat has been easy to exchange recently.

Implement an agent-local demand memory.

For each good, store something conceptually like:

```text
observed_demand_score[good]
```

This information is LOCAL.

There is no global price oracle.

A household learns demand through:

* goods its trade partners requested;
* successful exchanges;
* failed exchanges;
* its recent encounters.

Memory should decay slowly over time.

This lets expected exchangeability influence PRODUCTION.

---

# 28. IMPORTANT PRE-MONEY RESTRICTION

Version 0.01 must remain DIRECT BARTER.

An agent may NOT accept a good solely because:

> "I don't need this, but maybe someone else will accept it later."

That behavior is indirect exchange and is the conceptual beginning of commodity money.

We intentionally postpone it.

A received good must provide DIRECT household utility or useful production input.

This preserves the double coincidence of wants.

Later, when we deliberately add proto-money behavior, removing this restriction should create a fascinating transition.

---

# 29. BARTER SYSTEM

There is NO marketplace.

There is NO auction house.

There is NO global order book.

There is NO market-clearing price.

Households encounter other households directly.

Each household should have only a limited number of possible trade encounters per day.

Suggested:

```text
3 encounters/day
```

Prefer geographically nearby households.

Distance should influence partner probability.

Do not allow everyone to instantly trade with everybody.

This creates transaction/search costs.

---

# 30. DOUBLE COINCIDENCE OF WANTS

A trade can happen only if:

Household A possesses something B directly values,

AND

Household B possesses something A directly values.

Example:

```text
A has excess meat
A wants stone

B has excess stone
B wants meat

=> trade possible
```

But:

```text
A wants stone and offers meat

B has stone but wants wood

=> trade fails
```

Record failed trade opportunities.

They are economically meaningful.

The UI should eventually show:

```text
Trades attempted
Trades completed
Failure: no double coincidence
Failure: insufficient mutually beneficial ratio
```

---

# 31. BARTER NEGOTIATION ALGORITHM

Do NOT assign a universal price.

For each potential pair:

1. Determine goods A directly wants that B can spare.
2. Determine goods B directly wants that A can spare.
3. Find candidate good pairs.
4. Search a small set of possible quantity combinations.
5. Calculate household utility before trade.
6. Calculate household utility after trade.
7. Accept only if BOTH households gain positive utility.
8. Choose a mutually beneficial bundle using a deterministic fairness rule.

A brute-force small search is completely acceptable because:

* only five goods exist;
* household count is tiny;
* correctness and explainability matter more than micro-optimization.

For example, search up to 8–12 quantity steps per side.

Respect each good's divisibility.

Spears must trade in whole units.

Food/raw goods can trade fractionally using fixed-point quantities.

Potential objective:

```text
maximize minimum(
    utility_gain_A,
    utility_gain_B
)
```

This approximates a fair bargaining result without inventing a market price.

Record:

```text
household A
household B
good A
quantity A
good B
quantity B
day
result
```

---

# 32. OBSERVED BARTER EXCHANGE RATIOS

The simulation must record actual successful exchanges.

Example:

```text
3.8 meat ↔ 1 spear
4.5 meat ↔ 1 spear
3.2 meat ↔ 1 spear
```

Analytics may then report:

```text
Recent observed median:
1 spear ≈ 3.8 meat
```

This is an ANALYTICAL statistic.

Agents must NEVER access global median exchange ratios.

They only know their own memories/encounters.

Implement pairwise trade-history buffers.

---

# 33. ANALYTICAL NUMERAIRE

The UI may allow the player to select a reference good for charting.

Default:

```text
BERRIES
```

For example:

```text
Observed direct trades against berries:

Meat    2.3 berries/unit
Wood    1.7 berries/unit
Stone   2.1 berries/unit
Spear   14.8 berries/unit
```

Only use ACTUAL DIRECT TRADES for v0.01.

If there are no direct trades between a pair:

display:

```text
N/A
```

Do not fabricate an implied cross-rate.

The reference good has no special status in the simulation.

It is only a graphing convenience for the human player.

---

# 34. PRODUCTION PLANNING AND SPECIALIZATION

The decision system should make the following behavior POSSIBLE:

A household discovers that:

* its hunting skill is high;
* its hunting output is high;
* other households often need meat;
* it can barter surplus meat for wood/stone/spears.

It therefore spends increasing amounts of labor hunting.

Another household discovers:

* its crafting ability is high;
* hunting ability is poor;
* spears are desired by productive hunters.

It spends increasing labor crafting tools.

We must NOT tell either household:

```text
you are now a hunter
```

or:

```text
you are now a toolmaker
```

They simply choose actions repeatedly.

---

# 35. MEASURING SPECIALIZATION

Maintain a rolling 30-day labor history.

For each household:

```text
minutes_foraging
minutes_hunting
minutes_wood
minutes_stone
minutes_crafting
```

Calculate:

```text
specialization_score =
largest activity labor share
```

For example:

```text
70% hunting
10% foraging
10% wood
5% stone
5% crafting

specialization = 0.70
```

Infer a DISPLAY occupation if one activity exceeds approximately 55%.

Labels:

```text
Forager
Hunter
Wood Gatherer
Stone Gatherer
Toolmaker
Generalist
```

This label MUST NOT influence behavior.

It is only descriptive analytics.

---

# 36. RESOURCE COMPETITION

When multiple households target the same resource stock, they compete for the real stock.

Do not let everyone obtain their expected full yield from the same depleted tile.

A simple deterministic execution approach is acceptable:

1. households calculate intentions;
2. process production in a deterministic daily shuffled order;
3. extract what remains;
4. later households may receive less if resource is depleted.

The shuffle must use simulation RNG and therefore be reproducible.

This avoids permanent low-ID priority.

Later versions can implement simultaneous allocation.

Do not overengineer it now.

---

# 37. DAILY SIMULATION ORDER

Use a clear fixed pipeline.

Recommended:

```text
BEGIN DAY

1. Regenerate renewable map resources

2. Update/decay agent memories slightly

3. Reset household daily labor

4. PLAN WORK BLOCK A
   - evaluate candidates
   - store decision explanations

5. RESOLVE WORK BLOCK A

6. PLAN WORK BLOCK B
   - reevaluate using new inventory/state

7. RESOLVE WORK BLOCK B

8. TRADE PHASE
   - determine encounters
   - attempt barter
   - execute accepted trades
   - record failures/successes

9. CONSUMPTION
   - consume food
   - consume firewood

10. HEALTH UPDATE

11. FOOD SPOILAGE

12. LEARNING BY DOING

13. UPDATE ACTIVITY HISTORIES

14. UPDATE METRICS

15. RECORD EVENTS

16. ADVANCE DAY

END DAY
```

Keep this pipeline explicit in code.

Do not scatter day-changing behavior across rendering code.

---

# 38. HOUSEHOLD DECISION EXPLANATION

For each candidate action, retain the main scoring components.

Example data:

```text
Decision_Candidate {
    activity
    total_score

    food_need_component
    fuel_need_component
    tool_component
    input_component
    trade_demand_component
    skill_component
    travel_component
    risk_component

    target_resource_cell
    expected_output
}
```

Store top candidates for the most recent decision.

When inspecting a household, show:

```text
WHY THIS ACTION?
```

with the selected action and top alternatives.

Example:

```text
1. Hunt             7,260
2. Forage           5,910
3. Gather wood      2,230
```

Then show selected-action components.

This is a signature feature.

---

# 39. EVENT SYSTEM

Create a compact event system.

Types should include at minimum:

```text
WORK_COMPLETED
HUNT_SUCCEEDED
HUNT_FAILED
RESOURCE_DEPLETED
SPEAR_CRAFTED
SPEAR_BROKE
TRADE_COMPLETED
TRADE_FAILED
FOOD_SPOILED
HUNGER
HOUSEHOLD_DIED
SPECIALIZATION_CHANGED
```

Store a bounded event ring buffer.

Suggested capacity:

```text
10,000–50,000 events
```

Do not leak memory indefinitely.

Events should be visible in an event feed.

Important events should be human-readable.

Examples:

```text
Day 184 — Household 12 traded 1 spear to Household 28 for 4.2 meat.

Day 190 — Household 7's spear broke while hunting.

Day 213 — Berry resources near the western camp are critically depleted.

Day 288 — Household 31 is now primarily specializing in hunting.

Day 412 — Household 18 died after prolonged food shortage.
```

---

# 40. MACRO METRICS

Every macro statistic must be calculated from actual micro state.

Track at minimum:

```text
Alive households

Total population proxy = alive households

Total food nutrition stored

Average food reserve days

Median household health

Daily food production

Daily wood production

Daily stone production

Daily spear production

Daily trade attempts

Daily successful trades

Trade success rate

Total barter quantity

Average specialization score

Number of inferred specialists by activity

Total resource stock by category

Food spoiled per day

Number of hungry households

Deaths

Spear ownership rate

Average skill by activity
```

Do NOT create GDP yet.

There is no coherent monetary valuation system.

Do NOT create inflation.

There is no currency price level.

Do NOT create unemployment.

There is no labor market.

Do not pretend modern metrics already exist.

---

# 41. ANALYTICAL COMPARISON: TRADE VS NO TRADE

Implement a headless experiment capability.

At minimum allow:

```text
trade_enabled = true/false
```

The program should be able to run identical starting seeds with:

```text
TRADE ON
```

and:

```text
TRADE OFF
```

and compare:

* total production;
* survival;
* average food reserves;
* specialization;
* resource allocation.

This is scientifically useful.

Trade must not receive any hidden productivity bonus.

The only difference should be that exchange is permitted.

---

# 42. COMMAND-LINE / HEADLESS MODE

Simulation core must have ZERO dependency on rendering.

Support a mode conceptually like:

```text
blackbox.exe --headless --seed 12345 --days 5000
```

Optional:

```text
--households 40
--trade true
--csv results.csv
```

Exact CLI syntax can be chosen sensibly.

In headless mode:

* do not create a window;
* run simulation as fast as possible;
* periodically print basic metrics;
* optionally export CSV.

This is important for tuning and future large experiments.

---

# 43. CSV EXPORT

CSV should contain one row per simulated day.

Suggested columns:

```text
day
year
alive_households

food_total
food_days_average
median_health

berries_produced
meat_produced
wood_produced
stone_produced
spears_produced

trade_attempts
successful_trades
trade_success_rate

specialization_average

hunters
foragers
wood_gatherers
stone_gatherers
toolmakers
generalists

hungry_households
deaths_today

berries_resource_stock
game_resource_stock
wood_resource_stock
stone_resource_stock
```

Add direct barter ratios where available, for example:

```text
meat_per_berry
wood_per_berry
stone_per_berry
spear_per_berry
```

Use empty value or NA when no direct observed rate exists.

---

# 44. GAME WINDOW

Target desktop resolution:

```text
1600 x 900
```

The UI must scale/reflow reasonably when resized.

Minimum supported practical window:

```text
1280 x 720
```

No fixed assumption that the player uses exactly 1600x900.

---

# 45. MAIN SCREEN LAYOUT

Primary composition:

```text
┌──────────────────────────────────────────────────────────────┐
│ TOP STATUS / TIME BAR                                        │
├───────────┬───────────────────────────────────┬──────────────┤
│ OVERLAYS  │                                   │ INSPECTOR    │
│           │           WORLD MAP               │              │
│           │                                   │              │
│           │                                   │              │
├───────────┴───────────────────────────────────┴──────────────┤
│ ANALYTICS / CHARTS / EVENT FEED                              │
└──────────────────────────────────────────────────────────────┘
```

The MAP remains the primary visual focus.

Panels should be collapsible where sensible.

---

# 46. TOP BAR

Show:

```text
Day / Year
Alive households
Average food reserve
Trade success
Average specialization
```

Controls:

```text
Pause
1x
5x
20x
100x
```

Suggested keyboard shortcuts:

```text
SPACE = pause/resume
1 = 1x
2 = 5x
3 = 20x
4 = 100x
```

Simulation speed means:

```text
simulation days processed per real-time interval
```

Do not alter simulation rules based on real frame time.

---

# 47. CAMERA

Implement:

```text
WASD pan
middle-mouse drag pan
mouse wheel zoom
```

Clamp zoom to sensible bounds.

Clicking a household selects it.

Clicking a resource cell selects it.

Clicking empty map clears selection.

Selected entity remains selected until changed.

Draw a visible selection ring/highlight.

---

# 48. MAP RENDERING

Render top-down 2D.

Show:

* terrain;
* household camps/huts;
* important resource indicators;
* optional activity markers;
* trade connections.

Do not implement individual character walking animation.

That is outside v0.01.

Production/travel can remain abstract.

However, visualize activity using small temporary indicators.

Examples:

```text
hunter icon above household
berry icon when foraging
hammer/spear icon when crafting
```

These can fade after activity resolution.

---

# 49. MAP OVERLAYS

Left-side overlay buttons:

```text
NORMAL
RESOURCES
TRADE
SPECIALIZATION
FOOD SECURITY
```

## NORMAL

Standard terrain and households.

## RESOURCES

Show resource abundance through cell tint or small icons:

* berries;
* game;
* wood;
* stone.

Allow selecting resource type.

## TRADE

Draw recent successful trades as lines between household homes.

Thickness proportional to recent quantity.

Fade old trade connections.

Do not create permanent spaghetti.

## SPECIALIZATION

Color/tint household markers according to inferred dominant activity.

Always include a legend.

## FOOD SECURITY

Tint households based on food reserve days.

Example conceptual levels:

```text
critical
low
stable
surplus
```

Use both color and symbols/tooltips so information does not depend entirely on color perception.

---

# 50. HOUSEHOLD INSPECTOR

When clicking a household, the right panel must show:

### Identity

```text
Household #17
Health
Location
Current inferred role
Specialization score
```

### Inventory

Show icons + quantities:

```text
Berries
Meat
Wood
Stone
Spears
```

For spear:

```text
durability
```

### Survival

```text
Food reserve in days
Preferred reserve
Daily fuel requirement
```

### Skills

Display horizontal bars:

```text
Foraging
Hunting
Wood gathering
Stone gathering
Spear crafting
```

### Current / Last Decision

```text
Current activity

Top candidate scores

WHY?
```

Display score components.

### Labor History

Last 30 days:

```text
Forage %
Hunt %
Wood %
Stone %
Craft %
```

### Recent Trades

Last approximately 10.

Example:

```text
Gave 1 spear
Received 4.2 meat
Household #31
Day 288
```

### Local Demand Memory

Show what this household has learned people tend to request.

Make it very clear:

```text
LOCAL KNOWLEDGE
```

not global market data.

---

# 51. RESOURCE INSPECTOR

Clicking a resource cell should show:

```text
Terrain
Current berry stock / capacity
Game stock / capacity
Wood stock / capacity
Stone stock / capacity
Daily regeneration
Recent extraction
Nearby households
```

This will help diagnose local scarcity.

---

# 52. ANALYTICS PANEL

Bottom panel should have tabs:

```text
OVERVIEW
PRODUCTION
TRADE
BARTER RATIOS
SPECIALIZATION
EVENTS
```

Draw charts yourself using raylib primitives.

Do not introduce a large chart library.

---

# 53. OVERVIEW TAB

Charts:

```text
Alive households over time
Average food reserve over time
Median health over time
```

---

# 54. PRODUCTION TAB

Time-series for:

```text
Berries produced/day
Meat produced/day
Wood produced/day
Stone produced/day
Spears produced/day
```

Allow toggling series.

---

# 55. TRADE TAB

Show:

```text
Trade attempts/day
Successful trades/day
Success rate
```

Also show failed reason counts:

```text
No double coincidence
No mutually beneficial bundle
Insufficient inventory
```

---

# 56. BARTER RATIO TAB

Default analytical reference good:

```text
Berries
```

Let player select another reference good.

Display recent actual DIRECT exchange medians.

Example:

```text
1 meat  ≈ 2.2 berries
1 wood  ≈ 1.4 berries
1 stone ≈ 1.7 berries
1 spear ≈ 13.6 berries
```

Display:

```text
N/A
```

when insufficient actual trades exist.

Also draw time series when enough observations are available.

Again:

THIS INFORMATION MUST NEVER BE USED AS A GLOBAL PRICE BY AGENTS.

---

# 57. SPECIALIZATION TAB

Display:

```text
Average specialization over time
```

And current role counts:

```text
Hunters
Foragers
Wood Gatherers
Stone Gatherers
Toolmakers
Generalists
```

Also show the top five most specialized households.

Clicking one should select it on the map.

---

# 58. EVENTS TAB

Scrollable chronological event feed.

Filters:

```text
Trade
Production
Scarcity
Health
Specialization
```

Keep filtering simple.

---

# 59. START SCREEN

Implement a small clean setup screen.

Fields:

```text
World Seed
Households
```

Buttons:

```text
START SIMULATION
RANDOMIZE SEED
```

Under a small "Experimental" section:

```text
Trade Enabled [checkbox]
```

Default:

```text
true
```

This allows quick A/B experiments.

Do not expose dozens of tuning parameters to players.

Developer constants can live in configuration code.

---

# 60. ART DIRECTION

The visual identity must communicate:

> ancient material world + modern analytical instrument.

Map:

**warm, hand-painted, understated prehistoric landscape.**

UI:

**clean modern economic analysis interface.**

Do not make it:

* childish;
* hyper-saturated;
* shiny mobile-game art;
* fantasy RPG;
* medieval;
* cartoonish Civilization clone;
* excessive parchment skeuomorphism;
* pixel art unless absolutely required;
* photorealistic.

Desired feeling:

> an archaeological diorama being observed through a modern economic laboratory.

---

# 61. MAP COLOR LANGUAGE

Suggested palette feeling:

```text
Meadow:
muted olive / dry grass

Forest:
deep desaturated green

Rock:
warm grey / brown

Household structures:
ochre / hide / timber

UI:
charcoal / warm dark brown

Primary accent:
warm amber / sand

Positive/stable:
muted green

Warning:
ochre

Critical:
muted rust/red
```

Do not oversaturate.

Ensure text contrast.

---

# 62. GENERATED VISUAL ASSETS

YOU MUST GENERATE THE REQUIRED ASSETS YOURSELF.

Do not use copyrighted game assets.

Generate individual files rather than relying on a complicated sprite atlas.

Create at minimum:

## Terrain textures

```text
assets/terrain/meadow.png
assets/terrain/forest_floor.png
assets/terrain/rocky.png
```

Requirements:

* square;
* approximately 256x256 or 512x512;
* seamless or visually tileable;
* orthographic/top-down;
* subtle texture;
* no objects;
* no text;
* no baked lighting direction so repeated tiling is not obvious.

---

# 63. HOUSEHOLD ASSETS

Generate three variants:

```text
assets/structures/hut_01.png
assets/structures/hut_02.png
assets/structures/hut_03.png
```

Requirements:

* transparent background;
* top-down / slightly readable orthographic perspective;
* primitive wood/hide/grass camp shelter;
* pre-agricultural;
* no masonry town;
* no medieval details;
* culturally neutral;
* approximately 128x128 or 256x256 source;
* readable when displayed around 28–40 screen pixels.

Variation should be modest.

They all represent the same economic entity type.

---

# 64. RESOURCE ASSETS

Generate:

```text
assets/resources/berries.png
assets/resources/game.png
assets/resources/wood.png
assets/resources/stone.png
```

Requirements:

* transparent background;
* clear silhouette;
* same visual style;
* designed for top-down map marker usage;
* no text.

`game.png` may depict a simple deer-like or boar-like animal silhouette appropriate to generic prehistoric hunting.

Avoid tying the game to one real-world historical culture.

---

# 65. GOODS ICONS

Generate:

```text
assets/icons/good_berries.png
assets/icons/good_meat.png
assets/icons/good_wood.png
assets/icons/good_stone.png
assets/icons/good_spear.png
```

Requirements:

* transparent background;
* square;
* clean isolated object;
* painterly but highly legible;
* same lighting/perspective;
* no text;
* readable at 20–32 pixels.

Spear icon must clearly depict a primitive stone-tipped spear, not bronze or iron.

---

# 66. ACTIVITY ICONS

If useful, also generate:

```text
activity_forage.png
activity_hunt.png
activity_wood.png
activity_stone.png
activity_craft.png
```

However, if the generated icons become visually cluttered, simple programmatic symbols are acceptable.

Do not waste development effort on decorative assets.

---

# 67. ASSET FAILURE FALLBACK

The game must still launch if an asset is missing.

Implement simple fallback rendering:

```text
colored terrain rectangles
circles/squares for households
basic symbols for resources
text abbreviations for goods
```

Print a warning.

Do not crash because one PNG is absent.

The generated assets should be used normally, but the simulation must not depend on them.

---

# 68. UI STYLE

Use raylib-drawn panels and controls.

Do not generate UI panel PNGs.

Keep UI crisp and resolution-independent.

Use:

* flat/semi-flat panels;
* subtle borders;
* small corner radii if convenient;
* consistent spacing;
* strong hierarchy;
* compact economic data display.

Do not make every piece of information a giant card.

This is a simulation interface.

Density is acceptable if readable.

---

# 69. FONT

Prefer a clean freely distributable font if one is already available to the project.

Otherwise use raylib's built-in/default font initially.

Do not delay the prototype searching for typography.

Do not embed text inside generated images.

---

# 70. TOOLTIP SYSTEM

Hovering relevant UI/map items should explain them.

Examples:

```text
Specialization
Share of productive labor spent on this household's most common activity during the last 30 days.
```

```text
Observed Barter Ratio
Median ratio from actual direct exchanges. Agents do not know this global statistic.
```

Teaching the player how the simulation works begins here.

---

# 71. TECHNICAL ARCHITECTURE

Maintain strict separation:

```text
SIMULATION CORE
        ↓
READ-ONLY GAME VIEW
        ↓
RENDERER / UI
```

Rendering must never modify the economy except through explicitly defined future player commands.

In v0.01 there are essentially no economic player commands.

The simulation package must run without raylib.

---

# 72. DO NOT BUILD AN ECS

Do not create a massive generic engine.

Do not build:

* generic entity component system;
* generic scripting language;
* generic scene editor;
* reflection-heavy framework;
* dependency injection framework;
* networking layer.

Use straightforward Odin.

Entity references can simply be integer IDs/indices.

Favor contiguous memory and simple data structures.

The first goal is a correct simulator.

---

# 73. DATA-ORIENTED DESIGN

Avoid one heap allocation per household/resource/event.

Prefer:

* contiguous arrays;
* fixed-capacity arrays where practical;
* bounded ring buffers;
* IDs rather than chains of pointers.

Do not prematurely write SIMD or complex multithreading.

A clear array-of-structs implementation is acceptable for v0.01 if it keeps code reliable.

Organize state so future conversion to SoA or chunked processing is straightforward.

---

# 74. SINGLE-THREADED SIMULATION FIRST

Version 0.01 simulation must initially be single-threaded.

Do NOT create one thread/goroutine equivalent per household.

Do NOT parallelize before profiling.

The project has only dozens of households.

We care more about:

* deterministic behavior;
* correctness;
* debuggability;
* iteration speed.

Later versions can parallelize simulation phases.

---

# 75. SUGGESTED PROJECT LAYOUT

Use approximately:

```text
blackbox-economy/
│
├─ README.md
├─ build.bat
├─ run.bat
│
├─ assets/
│  ├─ terrain/
│  ├─ structures/
│  ├─ resources/
│  └─ icons/
│
├─ src/
│  ├─ main.odin
│  │
│  ├─ sim/
│  │  ├─ config.odin
│  │  ├─ types.odin
│  │  ├─ rng.odin
│  │  ├─ world.odin
│  │  ├─ worldgen.odin
│  │  ├─ goods.odin
│  │  ├─ resources.odin
│  │  ├─ households.odin
│  │  ├─ decisions.odin
│  │  ├─ production.odin
│  │  ├─ trade.odin
│  │  ├─ events.odin
│  │  ├─ metrics.odin
│  │  └─ simulation.odin
│  │
│  ├─ game/
│  │  ├─ app.odin
│  │  ├─ camera.odin
│  │  ├─ renderer.odin
│  │  ├─ ui.odin
│  │  ├─ map_view.odin
│  │  ├─ inspector.odin
│  │  └─ charts.odin
│  │
│  └─ analysis/
│     ├─ headless.odin
│     ├─ csv.odin
│     └─ experiments.odin
│
└─ tests/
   ├─ determinism.odin
   ├─ inventory.odin
   ├─ production.odin
   └─ barter.odin
```

Adapt to Odin package rules as necessary.

Do not force this exact layout if Odin's package/import requirements make a slightly different structure cleaner.

---

# 76. CENTRAL CONFIGURATION

Put tunable economic constants in one obvious configuration structure/file.

Example conceptual categories:

```text
World:
map width
map height
households

Time:
labor minutes
days/year

Needs:
nutrition/day
fuel/day
health penalties

Production:
base yields

Hunting:
success rates
spear bonus

Resources:
capacities
regeneration

Trade:
encounters/day
trade radius
memory decay

Skills:
starting range
learning rate

Decision:
utility weights
risk weights
```

Do not scatter magic numbers throughout code.

---

# 77. DEBUGGING INVARIANTS

Use assertions in debug builds.

Important invariants:

```text
inventory >= 0

resource stock >= 0

resource stock <= allowed capacity where applicable

health within legal range

labor minutes never exceed daily allocation

dead households do not produce

dead households do not trade

trade conserves goods

trade cannot create goods

crafting consumes required inputs

production cannot extract more than resource stock

spear durability never exceeds max

simulation day always increases exactly once per tick
```

---

# 78. DETERMINISM TEST

Create a test that:

1. creates world with seed `123456789`;
2. runs 1000 days;
3. computes a deterministic hash/checksum of important simulation state;
4. repeats from a fresh world with same seed;
5. verifies hashes are identical.

State hash should include:

* household inventories;
* health;
* skills;
* resource stocks;
* trade counts;
* day;
* relevant RNG state.

It does not need cryptographic security.

This test must pass before considering v0.01 complete.

---

# 79. DIFFERENT-SEED TEST

Run two worlds with clearly different seeds.

They SHOULD produce different final state hashes.

This catches accidental unseeded/static world creation.

---

# 80. INVENTORY CONSERVATION TEST

Construct a controlled barter test.

Before:

```text
A:
10 meat
0 stone

B:
0 meat
10 stone
```

Execute a successful trade.

Verify:

```text
total meat before == total meat after

total stone before == total stone after
```

Trade may only transfer goods.

---

# 81. NO-TRADE TEST

With:

```text
trade_enabled = false
```

there must be:

```text
0 completed trades
```

No hidden mechanism may transfer inventory between households.

---

# 82. SPECIALIZATION EXPERIMENT

Implement an automated batch experiment.

Suggested:

```text
20 seeds
720 days each
40 households
```

Run each seed twice:

```text
TRADE ON
TRADE OFF
```

Compare:

```text
average specialization
total output
survival
food reserves
```

Do NOT write a test that demands trade must always outperform no-trade.

That would force ideology into the simulator.

Instead print/export the results and inspect whether meaningful differences emerge.

The experiment is diagnostic, not a predetermined theorem.

---

# 83. SCARCITY EXPERIMENT

Provide a development-only way to run worlds with altered resource abundance.

Example:

```text
normal berry regeneration

vs

50% berry regeneration
```

Compare observed behavior.

We want to see:

* more labor redirected toward alternative food;
* changed barter patterns;
* changed observed exchange ratios;
* perhaps lower health/survival.

Do not directly alter trade ratios.

Only alter physical berry availability.

---

# 84. EXPLAINABILITY TEST

Pick a household after simulation has run.

The inspector must be able to tell:

* what it did;
* why;
* what it considered;
* what it owns;
* what it needs;
* what it has been doing recently;
* what it has traded recently;
* what local demand it has observed.

If we cannot explain one household, debugging future macroeconomics will become impossible.

---

# 85. VISUAL PERFORMANCE

Rendering target:

```text
60 FPS
```

Simulation speed is independent.

If the simulation is running 100 days/sec, do not attempt to visually animate every individual event.

Aggregate/fade visualization events.

The renderer should show the latest state smoothly.

---

# 86. SIMULATION PERFORMANCE

Do not prematurely optimize.

But headless mode should contain:

* no artificial delay;
* no rendering work;
* no unnecessary per-tick heap churn.

Profile if something is surprisingly slow.

Do not multithread merely because the eventual project may become large.

---

# 87. MEMORY DISCIPLINE

Avoid growing arrays without limit.

Bound:

* event history;
* chart history;
* trade history;
* household activity history.

For UI charts, retaining approximately:

```text
2,000–5,000 daily points
```

is enough for v0.01.

Use ring buffers if convenient.

---

# 88. GAMEPLAY FEEL

Even though this is an observer prototype, it should feel alive.

Useful subtle effects:

* huts gently highlight when active;
* small activity symbol appears during production;
* successful trade draws a short-lived line;
* hunger warning appears over endangered household;
* spear crafting produces a small visual indicator;
* resource tiles visibly become less abundant;
* chart lines update while simulation runs.

Avoid excessive particles.

Avoid mobile-game reward effects.

We are observing a living economic organism, not opening loot boxes.

---

# 89. AUDIO

Audio is optional for v0.01.

Do not delay core development for audio.

If added, use only subtle:

* ambient wind;
* soft environmental sound;
* tiny unobtrusive UI clicks.

No epic soundtrack needed.

---

# 90. ECONOMIC BEHAVIOR WE WANT TO OBSERVE

Do not hard-code these outcomes.

But tune the primitive behavioral rules until the simulation is capable of producing phenomena such as:

### Heterogeneous production

Some households consistently produce more of particular goods because their skills/location are favorable.

### Specialization

Some households increasingly devote labor to one activity.

### Exchange

Specialists barter surplus output for things they produce poorly.

### Price-like ratios

Actual barter ratios become somewhat clustered rather than completely random.

### Fluctuation

Ratios move when local scarcity changes.

### Failed trade

Double coincidence prevents otherwise useful exchanges.

### Resource pressure

Overuse of a local resource can reduce availability.

### Tool investment

Some households sacrifice short-term resources to obtain/craft spears that improve future hunting.

### Path dependence

Learning by doing reinforces some activity patterns.

### Collapse

A badly functioning local economy may experience hunger/deaths.

These should be emergent consequences.

---

# 91. DO NOT FAKE SPECIALIZATION

Absolutely prohibited:

```text
if day > 100:
    randomly_assign_specialists()
```

or:

```text
specialization_bonus = 1.25
```

or:

```text
toolmaker_probability += 0.1
```

Specialization is simply what we call an observed concentration of labor.

---

# 92. DO NOT FAKE PRICES

Absolutely prohibited:

```text
market_price[MEAT] = supply / demand
```

There is no global market.

Observed exchange ratios come from actual negotiated barter.

A household's subjective willingness to trade comes from its own utility and local experience.

---

# 93. DO NOT FAKE SCARCITY

Do not write:

```text
if berries_low:
    berry_value *= 2
```

Instead:

low berries
→ low household food inventory
→ food marginal utility becomes high
→ household demands more compensation before surrendering berries/meat
→ actual trades change.

That is the simulation we want.

---

# 94. DO NOT FAKE PRODUCTIVITY FROM TRADE

Never apply:

```text
if trade_enabled:
    productivity *= 1.2
```

If trade increases aggregate production, it must happen because agents reallocate labor toward activities where they are more effective.

---

# 95. DO NOT ADD "ECONOMIC IDEOLOGY"

This prototype is not meant to prove:

* markets are good;
* markets are bad;
* specialization is always good;
* barter is always efficient.

It is an artificial economy whose assumptions must remain visible.

The result is whatever the rules produce.

---

# 96. README

Write a proper README containing:

```text
What the project is

Current scope

Current non-goals

Prerequisites

How to build

How to run

How to run headless

Command-line arguments

Controls

Simulation rules

How determinism works

How to run tests

Known limitations
```

Also state prominently:

> v0.01 is not intended as an accurate reconstruction of any specific prehistoric society. It is a deliberately simplified laboratory for studying bottom-up allocation, production and barter.

This matters.

---

# 97. BUILD EXPERIENCE

Target first:

```text
Windows x86-64
```

Use Odin's official raylib vendor binding.

Do not introduce a package manager unless absolutely necessary.

Create:

```text
build.bat
run.bat
```

Make building easy.

The build script should create a build/output directory if necessary.

Verify the exact commands against the installed Odin compiler rather than guessing outdated syntax.

The final project must compile cleanly.

---

# 98. ERROR HANDLING

On startup:

* validate assets;
* validate configuration;
* validate map dimensions;
* validate household count.

If an asset is missing:

* warn;
* use fallback;
* continue.

If configuration is impossible:

* print useful error;
* do not silently corrupt simulation.

---

# 99. IMPLEMENTATION ORDER

Do NOT attempt everything simultaneously.

Proceed in this order.

---

## MILESTONE 1 — PROJECT BOOT

Create:

* Odin project;
* raylib window;
* build scripts;
* basic camera;
* blank map view;
* clean project structure.

Compile.

Fix all errors.

Do not continue until it runs.

---

## MILESTONE 2 — DETERMINISTIC SIMULATION SKELETON

Implement:

* simulation state;
* world seed;
* project-owned PRNG;
* daily tick;
* households;
* inventories;
* health;
* deterministic test.

No rendering dependency.

Run determinism tests.

---

## MILESTONE 3 — PROCEDURAL WORLD

Implement:

* meadow;
* forest;
* rocky terrain;
* resource stocks;
* deterministic generation;
* household placement.

Render world.

Add generated terrain/resource assets.

---

## MILESTONE 4 — SURVIVAL & PRODUCTION

Implement:

* labor;
* food;
* fuel;
* foraging;
* wood;
* stone;
* hunting;
* food consumption;
* spoilage;
* health.

Run headless worlds.

Tune until a significant share of households can survive but survival is not trivial.

Do not use barter yet.

---

## MILESTONE 5 — SPEAR / CAPITAL

Implement:

* spear recipe;
* crafting progress;
* durability;
* hunting advantage;
* tool utility;
* skill differences;
* learning by doing.

Verify that some households voluntarily craft/use spears.

---

## MILESTONE 6 — DECISION EXPLAINABILITY

Implement:

* candidate scoring;
* stored score components;
* last-decision explanation;
* household inspector.

This MUST exist before barter complexity is added.

---

## MILESTONE 7 — BARTER

Implement:

* local encounters;
* direct wants;
* double coincidence;
* bundle search;
* mutual utility gain;
* transfer;
* trade history;
* failed-trade reasons;
* local demand memory.

Run extensive headless simulations.

Fix conservation bugs.

---

## MILESTONE 8 — SPECIALIZATION ANALYTICS

Implement:

* labor history;
* inferred roles;
* specialization metric;
* specialization overlay;
* trade vs no-trade experiment.

Do not manipulate behavior to satisfy the metric.

---

## MILESTONE 9 — ANALYTICS UI

Implement:

* macro status bar;
* charts;
* barter ratios;
* event feed;
* resource inspector;
* household history.

---

## MILESTONE 10 — VISUAL POLISH

Generate/finalize:

* terrain textures;
* huts;
* resources;
* goods icons.

Improve:

* map readability;
* panel layout;
* trade animation;
* warnings;
* tooltips.

Do not let art polish obscure simulation bugs.

---

# 100. DEFINITION OF DONE

Version 0.01 is DONE only when all of the following are true:

### Technical

* Windows build succeeds.
* Program launches.
* No missing-library crash.
* Same seed produces same result.
* Different seeds produce different worlds.
* Headless mode works.
* CSV export works.
* No negative inventory bug.
* Trade conserves goods.
* Resource extraction conserves physical stock.
* Simulation and renderer are separated.

### Simulation

* Households consume real goods.
* Food can become scarce.
* Resources can deplete.
* Households choose among activities.
* Skills materially affect productivity.
* Spears materially affect hunting.
* Spears require real inputs/labor.
* Trade requires mutual benefit.
* Double coincidence matters.
* No currency exists.
* No global market price exists.
* Actual barter ratios can be observed.
* Specialization is inferred from behavior.
* Trade does not receive hidden productivity bonuses.

### UI

* Map is readable.
* Time controls work.
* Household selection works.
* Resource selection works.
* Inspector explains decisions.
* Inventories are visible.
* Skills are visible.
* Recent trades are visible.
* Trade overlay works.
* Resource overlay works.
* Specialization overlay works.
* Food-security overlay works.
* Charts update.
* Events update.

### Art

* Required visual assets have been generated.
* Art is stylistically coherent.
* Primitive stone-age material culture is visually clear.
* No bronze/iron medieval assets appear.
* Generated images contain no text.
* Game still functions with fallback rendering if an asset is missing.

---

# 101. MOST IMPORTANT SUCCESS CRITERION

After letting the simulation run for hundreds of days, I should be able to click households and discover stories such as:

> Household #12 became an unusually productive hunter because it began with strong hunting ability, acquired a spear, improved through repeated hunting, accumulated surplus meat, learned that nearby households frequently wanted meat, and increasingly exchanged that meat for wood and stone instead of gathering those resources itself.

Meanwhile:

> Household #27 became a toolmaker because its crafting efficiency was unusually high, hunting was poor, nearby hunters demanded spears, and trading spears for food became more attractive than producing its own food.

If that happens WITHOUT any profession assignment or specialization bonus, we are succeeding.

---

# 102. SECOND SUCCESS CRITERION

I should be able to observe something like:

```text
Day 240:
1 spear commonly exchanges directly for approximately 4–5 meat.

Day 500:
game becomes scarce near several hunting households.

Meat becomes harder to obtain.

Actual negotiated spear↔meat ratios change.
```

No code should have directly changed a "meat price."

Agents merely changed willingness to surrender scarce resources.

---

# 103. THIRD SUCCESS CRITERION

The simulator should occasionally surprise its developer.

If every outcome is obvious because it was scripted, the architecture has failed.

We want enough simple interacting mechanisms that behavior emerges from:

```text
scarcity
+
heterogeneity
+
limited labor
+
geography
+
tools
+
learning
+
imperfect information
+
barter
```

---

# 104. WHAT COMES AFTER V0.01 — DO NOT IMPLEMENT

Keep architecture capable of expansion, but do NOT implement these now.

Likely future progression:

```text
v0.02
better resource/ecological model

v0.03
storage and more goods

v0.04
land + agriculture

v0.05
household settlement/migration

v0.06
specialized buildings/workshops

v0.07
knowledge diffusion / experimentation

v0.08
contracts and obligations

v0.09
indirect exchange / proto-money

v0.10+
currency, institutions, states...
```

This sequence is illustrative.

Do not start those systems without explicit instruction.

---

# 105. CODING AGENT WORKING RULES

While implementing:

1. Read the current codebase before editing.
2. Maintain a working build.
3. Compile frequently.
4. Run tests frequently.
5. Fix warnings/errors immediately.
6. Prefer simple correct systems over speculative abstraction.
7. Do not leave fake TODO implementations for core systems.
8. Do not silently simplify away economic mechanisms described here.
9. Document major tuning constants.
10. Generate required art assets yourself.
11. Do not use external copyrighted game assets.
12. Keep simulation independent of rendering.
13. Keep simulation deterministic.
14. Never introduce money.
15. Never directly program macro outcomes.
16. Never assign occupations.
17. Never invent global prices.
18. Never give trade an artificial productivity bonus.
19. Never implement later historical eras without instruction.
20. Continue until the v0.01 Definition of Done is satisfied.

---

# FINAL INSTRUCTION

Build **Black Box Economy Simulator v0.01** as a small, coherent, deterministic, visually inspectable experimental game.

Do not try to impress me with feature count.

Impress me by making five primitive goods, forty households, limited labor, heterogeneous ability, geography, tools and barter interact deeply enough that I can watch the beginnings of an economy form without the code explicitly telling it to do so.

The first version succeeds when I can watch it and think:

> "Nobody told these households to organize like this. Why did they do that?"

And then click one of them and find out.
