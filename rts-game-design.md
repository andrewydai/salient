# RTS Territory Game — Design & Build Plan

## Game Overview

A real-time territory-control strategy game built in Godot 4. Players command armies across a
territory graph, expanding control through conquest while managing troop production. Designed
for single-player vs AI and networked multiplayer (multiplayer deferred to a later phase).
Multiple historical eras (Medieval, Napoleonic, WW2, etc.) are supported via an era theme/skin
system that swaps art without touching game logic.

---

## Core Mechanics Summary

- The map is a **graph of territories**, each with a defined set of neighbors (adjacency)
- Each territory produces soldiers per tick based on its owner and modifiers
- Players select a territory they own and order armies to any other territory on the map
- Armies travel **hop-by-hop through the graph** in real time, fighting through enemy
  territories as they go — territory control shifts during a long march
- **Combat occurs at two places only:** at territories (arrival) and on edges (en-route
  collision between enemy armies on the same path segment)
- Combat is attrition-based (extensible to troop types, flanking, terrain)
- Armies **dissolve into the territory garrison on arrival** — armies only exist as entities
  while in transit
- **Generals** are the exception: they survive army dissolution, pool at territories, and
  re-assign when a new army departs
- Players can send partial armies (specify count by hotkey/typing) and redirect in-transit
  armies by clicking them
- **Fog of war is a core mechanic:** players see only owned territories and their immediate
  neighbors. All other territories show last-known state (troops, buildings) marked as stale
  with a question mark indicator. Certain troop types and buildings can extend visibility range.

---

## Architecture

### Core Principles

1. **Command pattern for all state mutations** — every action (player or AI) passes through
   `CommandBus`. This makes the game multiplayer-ready without networking in Phase 1.
2. **Strategy pattern for combat** — `CombatResolver` is an interchangeable class. Swap
   resolvers to change combat math without touching anything else.
3. **Modifier chain for territories** — buildings and terrain are composable `TerritoryModifier`
   resources. Adding a new building type = new Resource subclass, zero logic changes.
4. **Full data/presentation separation** — `EraTheme` resource maps game entity IDs to art
   assets. Renderers query `ThemeManager`; game logic never references sprites.
5. **Signal-driven decoupling** — systems communicate via `EventBus` signals, never through
   direct references to each other.
6. **Visibility as a first-class system** — fog of war is computed per-player each tick by
   `VisibilitySystem` inside `GameSimulation`. Renderers and (in Phase 6) the network layer
   both consume visibility state. Nothing bypasses it.

---

### Autoloads (Global Singletons)

| Autoload | Responsibility |
|---|---|
| `GameSimulation` | Authoritative game state. Owns all entity state. Processes commands. Fires events. Exposes `PRODUCTION_TICK_INTERVAL: float` as a configurable constant (~5–10 s). |
| `CommandBus` | All player and AI actions pass through here. Network layer hooks in here in Phase 6. |
| `EventBus` | Broadcast signals. UI, renderers, and systems subscribe. Nobody talks directly. |
| `ThemeManager` | Holds the active `EraTheme`. Queried by all renderers for sprites and display names. |

---

### Key Resources (Data Objects)

Resources in Godot are data containers that live outside the scene tree and can be serialized
to `.tres` files. Game logic data belongs in Resources, not in scene nodes.

```
MapData
  territories: Array[TerritoryData]
  starting_positions: Dictionary  # player_id → territory_id

TerritoryData
  id: String
  display_name: String
  neighbors: Array[String]          # IDs of adjacent territories
  polygon_points: PackedVector2Array
  terrain_type: TerrainType         # Plains, Mountain, Water, River, etc.
  passable: bool                    # false = armies cannot enter (mountains, water)
  base_production: int

# TerrainType drives both passability and edge traversal speed.
# Edge speed uses a bottleneck model: min(source.speed_modifier, dest.speed_modifier).
# Crossing Plains→Mountain is as slow as Mountain→Mountain; the harder terrain dominates.
# Example speed modifiers (tunable):
#   Plains:   1.0   Mountain: 0.4   River: 0.6   Forest: 0.7

TroopType
  id: String
  base_attack: float
  base_defense: float
  move_speed: float
  visibility_range: int             # 0 = default, >0 = extends sight by N hops beyond adjacency
  tags: Array[String]               # "cavalry", "artillery", "infantry"

EraTheme
  era_name: String
  troop_sprites: Dictionary[TroopTypeID, Texture2D]
  building_sprites: Dictionary[BuildingTypeID, Texture2D]
  general_sprites: Dictionary[int, Texture2D]  # rank → portrait
  territory_palette: Gradient
  ui_theme: Theme

GeneralProgressionData
  rank_bonuses: Array[CombatModifierData]  # index = rank
```

---

### Runtime Entities (owned by GameSimulation)

These are not scene nodes — they are plain objects (or inner classes) that `GameSimulation`
owns and mutates. Renderers receive events and update visuals accordingly.

```
Territory
  id: String
  owner: PlayerID
  garrison: Dictionary[TroopType, int]
  conquest_cooldown: float           # counts to 0 after capture; 0 = production active
  modifiers: Array[TerritoryModifier]
  generals: Array[General]           # pooled here when not in transit

Army
  id: String
  owner: PlayerID
  composition: Dictionary[TroopType, int]
  path: Array[TerritoryID]           # remaining hops to destination
  current_edge: [TerritoryID, TerritoryID]
  progress: float                    # 0.0–1.0 along current edge (visual only)
  state: ArmyState                   # Moving | Fighting | Waiting | Retreating
  generals: Array[General]

General
  id: String
  name: String
  rank: int
  location: TerritoryID | ArmyID     # tracked by GameSimulation

# --- Visibility ---

VisibilityLevel (enum)
  INTEL    # owned or within visible range — see troops, buildings, generals, armies
  STALE    # was visible, no longer — show last-known state with stale indicator
  HIDDEN   # never seen — show territory polygon only, no contents

IntelSnapshot                         # stored per-player, per-territory
  territory_id: TerritoryID
  last_seen_tick: int
  garrison_total: int                 # troop count at last observation
  buildings: Array[BuildingTypeID]
  general_count: int
  owner: PlayerID
```

---

### Commands (CommandBus vocabulary)

```
MoveArmyCommand(from_territory, to_territory, composition)
RedirectArmyCommand(army_id, new_destination)
BuildStructureCommand(territory_id, building_type)
SplitArmyCommand(army_id, split_composition, new_destination)  # Phase 2 — tied to general split rule
```

---

### Combat System

```
CombatResolver (base class)
  resolve(attacker: Army, defender: Army, context: CombatContext) -> CombatResult

CombatContext
  territory: TerritoryData
  terrain_modifiers: Array[CombatModifier]
  attacker_generals: Array[General]
  defender_generals: Array[General]
  reinforcements_pending: Array[Army]  # friendly armies arriving this tick

CombatResult
  winner: Army | null
  remaining_composition: Dictionary[TroopType, int]
  experience_threshold_crossed: bool  # triggers general spawn/levelup check
```

The `CombatResolver` sets `experience_threshold_crossed = true` when total casualties in the
engagement exceed a configurable threshold (e.g. 50 troops). Small skirmishes do not generate
experience. After a combat resolves, `GameSimulation` checks:
- If `experience_threshold_crossed` and winning army has **no generals** → spawn a rank-1 general
- If `experience_threshold_crossed` and winning army **has generals** → highest-ranked general
  gains a rank

#### En-Route Collision Rules

Collision between two enemy armies on the same edge is **direction-agnostic** — it fires
regardless of whether the armies are traveling toward each other or in the same direction.

After edge combat resolves, the losing army may attempt to **retreat**:
- **Retreat is legal** if the army was met head-on (opposite directions). The army reverses
  onto its source territory.
- **Retreat is not legal** if the army was caught from behind (same-direction pursuit). It
  has been overtaken and must fight to resolution.
- Retreat is represented by `ArmyState.Retreating`; the army's `path` is reversed one hop
  and it begins moving back toward its source territory.

---

### Territory Modifier Chain

```
TerritoryModifier (base Resource)
  apply_production_modifier(base: int) -> int
  apply_defense_modifier(base: float) -> float
  get_visibility_range() -> int        # default 0; override to extend player's sight

# Concrete modifiers (each is a Resource subclass):
ConquestCooldownModifier   # returns 0 production until timer expires
Fortification              # defense bonus
Barracks                   # production bonus
OfficerSchool              # ticks toward general spawn event
TerrainModifier            # mountain = impassable, river = defender bonus
Watchtower                 # get_visibility_range() returns 1 or 2 (extends sight)
```

When production or combat fires, the value is passed through each modifier in the territory's
`modifiers` array in sequence. Adding a new building = new `TerritoryModifier` subclass file.
No changes to existing systems.

---

### Visibility System

`VisibilitySystem` lives inside `GameSimulation` and recomputes visibility each tick for each
player. It is the only place visibility logic lives — renderers and the network layer consume
its output, never recompute it themselves.

```
VisibilitySystem (owned by GameSimulation)
  compute(player_id) -> Dictionary[TerritoryID, VisibilityLevel]

# Algorithm each tick:
# 1. Start with all owned territories → INTEL
# 2. For each owned territory, BFS outward by (1 + max visibility_range modifier)
#    hops → INTEL
# 3. For each in-transit army owned by player, BFS outward by army's
#    visibility_range (from TroopType) → INTEL
# 4. Any territory previously INTEL, now not → demote to STALE, snapshot saved
# 5. Any territory with no snapshot → HIDDEN
```

**Renderer behavior by visibility level:**
- `INTEL` — full display: troop count, buildings, generals, in-transit armies
- `STALE` — show `IntelSnapshot` data with a stale overlay (question mark indicator)
- `HIDDEN` — show territory polygon only; no contents, no armies

**Multiplayer implication (Phase 6):** The server filters all state updates through
`VisibilitySystem` before sending to each client. Clients never receive data for
`HIDDEN` territories. `STALE` data is sent once (on transition) and not updated until
the territory re-enters `INTEL`.

---

### Scene Node Structure

```
Main
  MapRenderer          # instantiates Territory scenes from MapData, pure visual
  ArmyRenderer         # instantiates Army scenes, listens to EventBus for army updates
  InputController      # click detection → Commands → CommandBus
  HUD
    TerritoryPanel     # selected territory info
    ArmyPanel          # selected army info
    MiniMap
```

---

### General Rules Summary

- All generals at a territory join any departing army (auto-assign)
- When an army splits: the **highest-ranked general** goes with the split force; the rest stay
- When an army arrives at a friendly territory: army dissolves, troops merge into garrison,
  generals move to territory general pool
- When an army arrives at an enemy territory: combat resolves first; if the attacker wins,
  territory is captured and army dissolves there

---

### Multiplayer Architecture (deferred to Phase 6)

The game is **server-authoritative**. One machine runs `GameSimulation`; clients send commands
and receive state updates. The `CommandBus` pattern makes this additive: in Phase 1, commands
go directly to `GameSimulation`; in Phase 6, a network layer intercepts `CommandBus`, routes
local commands to the server, and injects remote commands from other clients. No other system
changes.

Lockstep (used by StarCraft/AoE) is not used — it requires deterministic float simulation
which is cumbersome in GDScript.

---

### Map Authoring

Phase 1 uses a **hand-crafted `MapData` resource** (15 territories). A realistic map comes
in Phase 5. Options at that point:

- **GeoJSON pipeline** (best for real-world eras): Python script converts GeoJSON boundary
  data → `MapData` resource. Adjacency is derived from shared borders; gameplay metadata
  (terrain type, strategic value) is added manually. GeoJSON gives polygon shapes for free.
  Historical GeoJSON for Napoleonic/WW2 eras is available but sparse — may require academic
  sources (Euratlas Periodis) or tracing from reference SVG maps.
- **Editor plugin** (best for custom/fantasy maps): Godot plugin to draw territories over a
  reference image, click to set adjacency, export as `MapData`.

Note: administrative/geographic boundaries rarely produce good gameplay chokepoints. The
territory graph and adjacency are always hand-designed regardless of how polygon shapes
are sourced.

---

### Asset Pipeline (Aseprite)

Aseprite files (`.aseprite`) import directly into Godot 4 via the community Aseprite importer
plugin. Animation tags in Aseprite map to `AnimatedSprite2D` animation names. Organize by era:

```
assets/
  themes/
    medieval/
      troops/     heavy_infantry.aseprite, cavalry.aseprite ...
      buildings/  castle.aseprite, barracks.aseprite ...
    ww2/
      troops/     ...
      buildings/  ...
  theme_medieval.tres    # EraTheme resource with inspector-filled Texture2D references
  theme_ww2.tres
```

---

## Build Phases

> **Living Document.** This plan evolves during development. As each phase is implemented,
> design decisions may be revisited, new features added, and architecture adjusted in response
> to what we discover. Implementation surprises are expected to reshape later phases. That
> iteration is part of the learning exercise, not a deviation from it.

---

### Phase 1 — Core Game Loop

**Goal:** A complete core-loop prototype on a hand-crafted 15-territory map, playable
single-player against a minimal placeholder AI (random valid moves). No buildings, no
generals. All core systems established; smart AI replaces the placeholder in Phase 4.

The game is single-player-vs-AI locally. Local human-vs-human is not supported; multiplayer
is online-only (Phase 6).

**Build tasks:**
- [ ] Project setup: folder structure, autoloads registered, base scenes
- [ ] `TerritoryData` and `MapData` resources defined; hand-craft test map (15 territories)
- [ ] Territory rendering: `Polygon2D` (visual) + `CollisionPolygon2D` + click detection
- [ ] `TerritoryGraph`: adjacency list, BFS pathfinding between any two territories
- [ ] `GameSimulation` autoload: territory ownership, garrison counts, production tick
- [ ] `CommandBus` and `EventBus` autoloads wired up
- [ ] `MoveArmyCommand`: validate legality, create `Army`, begin hop-by-hop pathing
- [ ] Army movement along path edges in real time
- [ ] Attrition `CombatResolver`: armies arriving at enemy territory fight 1:1
- [ ] En-route combat: two enemy armies on the same edge collide and fight (direction-agnostic)
- [ ] Retreat mechanic: losing army reverses one hop if met head-on; cannot retreat if caught from behind
- [ ] Army dissolves into garrison on arrival at friendly territory
- [ ] Conquest cooldown: captured territories don't produce immediately
- [ ] `InputController`: click territory to select, click destination to issue move order
- [ ] Partial army selection: three modes — all troops, proportional slice of whole army, specific count of one troop type
- [ ] Minimal placeholder AI: issues random valid `MoveArmyCommand`s each tick (replaced in Phase 4)
- [ ] Army click-to-redirect while in transit (`RedirectArmyCommand`)
- [ ] Basic HUD: selected territory panel, selected army panel, troop counts
- [ ] Win condition: last player with at least one territory
- [ ] `VisibilitySystem`: compute INTEL/STALE/HIDDEN per territory per player each tick
- [ ] `IntelSnapshot`: store last-seen state when territory leaves INTEL
- [ ] Renderer respects visibility — mask troop counts and armies on HIDDEN territories
- [ ] Stale indicator: render `IntelSnapshot` data with question mark overlay on STALE territories
- [ ] Enemy in-transit armies hidden when traveling through non-INTEL territory

**Concepts covered in this phase:**
- Godot 4 project structure and scene tree composition
- Autoloads as singletons — when appropriate vs. passing references down the tree
- The `Resource` system — data objects serialized to `.tres`, separate from scene nodes
- Signals and the Observer pattern — EventBus as decoupling mechanism
- The Command pattern — why all input flows through `CommandBus`
- State machines — `ArmyState` as a formal state machine (your first one)
- BFS pathfinding on an adjacency graph
- Separation of simulation state from rendering (the renderer reacts to events, never polls)
- Visibility as computed state — `VisibilitySystem` derives what each player can see from
  ownership + adjacency + modifiers; renderers are consumers, not decision-makers

---

### Phase 2 — Generals & Combat Depth

**Goal:** Combat becomes strategic. Veterans accumulate over time. Armies have personality.

**Build tasks:**
- [ ] `General` entity: id, name, rank, location tracking in `GameSimulation`
- [ ] `GeneralProgressionData` resource: rank → `CombatModifierData` table
- [ ] General spawn from combat (winning army has no generals → rank-1 general spawned)
- [ ] General level-up from combat (winning army has generals → highest rank incremented)
- [ ] `CombatContext` updated to include general modifiers in resolution
- [ ] `SplitArmyCommand`: player specifies a composition and new destination; spawns a second army from an in-transit army
- [ ] General split rule: highest-ranked general goes with split force on `SplitArmyCommand`
- [ ] General transfer on army dissolution: generals move to territory pool
- [ ] General auto-assign on army departure: territory pool generals join departing army
- [ ] HUD updates: show generals in territory panel and army panel

**Concepts covered:**
- Strategy pattern in full — `CombatResolver` subclasses; resolver is swapped, not edited
- Composition over inheritance — `CombatModifier` as a data object composed into context
- Data-driven design — `GeneralProgressionData` as a designer-editable tuning surface
- Entity lifecycle — how `General` persists independently of the `Army` it travels with

---

### Phase 3 — Territory Features & Buildings

**Goal:** Territories are differentiated. Players make meaningful infrastructure decisions.

**Build tasks:**
- [ ] `TerritoryModifier` base class with `apply_production_modifier()` and `apply_defense_modifier()`
- [ ] `ConquestCooldownModifier` (extract from Phase 1 inline logic into proper modifier)
- [ ] `Fortification` modifier: defense bonus for defenders at this territory
- [ ] `Barracks` modifier: production rate bonus
- [ ] `OfficerSchool` modifier: ticks toward a general spawn event
- [ ] `TerrainModifier`: terrain type drives passability and combat modifiers
- [ ] `BuildStructureCommand`: validates cost, adds modifier to territory
- [ ] Simple resource cost system: building cost is paid in basic infantry deducted immediately from the territory garrison; cannot build if garrison would drop to zero
- [ ] Building UI: show buildable structures for selected territory with costs
- [ ] `Watchtower` modifier: `get_visibility_range()` returns extended hop count
- [ ] `VisibilitySystem` picks up `Watchtower` and scout `TroopType` ranges automatically

**Concepts covered:**
- Component/composition pattern — modifier chain as an alternative to deep class inheritance
- Chain of responsibility — how modifiers stack without knowing about each other
- Data-driven extensibility — adding a building type requires no changes to existing code
- When composition beats inheritance (this phase demonstrates it directly)

---

### Phase 4 — AI Opponent

**Goal:** A functional single-player experience. The AI makes sensible, fun decisions.

**Build tasks:**
- [ ] `AIController` class that issues commands through `CommandBus` (same path as human input)
- [ ] Utility AI: score candidate actions, execute highest-scoring each tick
  - Expand into undefended or weak neighboring territories
  - Reinforce territories under threat
  - Attack when local strength advantage exists
- [ ] Difficulty tiers: vary aggression level, decision frequency, and look-ahead
- [ ] AI general awareness: protect territories with high-rank generals

**Concepts covered:**
- Utility AI — scoring actions vs. hard-coded decision trees (more flexible, easier to tune)
- Why AI uses `CommandBus` just like the player — testability and future multiplayer readiness
- Separation of AI reasoning from game state — AI reads `GameSimulation`, never mutates it
- Iterative AI design — start intentionally simple, tune toward fun

---

### Phase 5 — Era Theme System & Map Tooling

**Goal:** Visual identity per era. A path to authoring real strategic maps.

**Build tasks:**
- [ ] `EraTheme` resource: entity type IDs → `Texture2D` + display names
- [ ] `ThemeManager` autoload: holds active theme, exposes lookup functions
- [ ] All renderers updated to query `ThemeManager` instead of hardcoded asset paths
- [ ] Asset folder structure set up for at least one era
- [ ] Aseprite importer plugin installed and configured
- [ ] First era skinned with Aseprite art (troops, buildings, UI elements)
- [ ] Evaluate and begin map authoring path (GeoJSON pipeline or editor plugin)
- [ ] First "real" map: 25–35 territories with intentional chokepoints and terrain variety

**Concepts covered:**
- Separation of data and presentation — full payoff of the `EraTheme` architecture
- Godot's Resource importer and asset pipeline
- Editor plugin basics (if building the map authoring tool)
- Pixel art workflow in Godot via Aseprite importer

---

### Phase 6 — Multiplayer

**Goal:** Two players can play over a network with server-authoritative state.

**Build tasks:**
- [ ] `NetworkManager` autoload: Godot `MultiplayerAPI`, host/join flow
- [ ] `CommandBus` network layer: local commands sent to server for validation
- [ ] Server re-emits validated commands; clients inject remote commands into local `CommandBus`
- [ ] `GameSimulation` on server is authoritative; clients receive state diffs
- [ ] **State updates filtered through `VisibilitySystem` per client** — clients never receive
      data for HIDDEN territories; STALE data sent once on transition only
- [ ] Lobby UI: host game, join game, player slot assignment
- [ ] Visual smoothing for army movement under latency

**Concepts covered:**
- Client-server architecture in Godot — `MultiplayerAPI`, peer IDs, scene authority
- `@rpc` annotation — Godot's Remote Procedure Call system
- Why the Command pattern made multiplayer additive rather than a rewrite
- Authority and trust — server validates, clients are display layers
- Per-client state filtering — why server-side visibility is a security requirement,
  not just a rendering concern

---

### Phase 7 — Game Modes & Polish

**Goal:** Multiple ways to play. A game worth sharing.

**Build tasks:**
- [ ] Win condition system: last player standing, territory percentage threshold, capitals mode
- [ ] Game mode selection UI
- [ ] Pause and speed controls
- [ ] Sound effects and music hooks
- [ ] Save/load game state
- [ ] Settings: keybindings, audio volume, display options
- [ ] Tutorial or in-game tooltip system

---

## Design Decisions Log

| Decision | Choice | Reason |
|---|---|---|
| Army identity | Armies dissolve on arrival | Territories hold garrison counts; armies are transient transit entities only |
| General persistence | Generals survive army dissolution | Only entity with persistent identity independent of armies |
| Territory representation | `Polygon2D` + `Resource` | Flexible shapes, decoupled from map authoring method |
| State mutation | All through `CommandBus` | Multiplayer-ready without networking in Phase 1 |
| Combat extensibility | Strategy pattern (`CombatResolver`) | Troop types, flanking, terrain bonuses planned; swap resolver, don't edit it |
| Territory features | Modifier chain | New building = new Resource subclass; existing code untouched |
| Asset theming | `EraTheme` resource + `ThemeManager` | Full decoupling; swapping eras is one assignment |
| Map authoring | Hand-crafted Resource for Phase 1 | Resolve GeoJSON vs. plugin at Phase 5 when mechanics are stable |
| Historical map accuracy | Gameplay-first territory design | Administrative borders don't produce interesting chokepoints |
| Multiplayer model | Server-authoritative | Simpler than lockstep; adequate for this game's granularity |
| Fog of war | Core mechanic from Phase 1 | Owned + adjacent = INTEL; outside = STALE (last-known with ? indicator) or HIDDEN |
| Stale state display | Show last-known with question mark overlay | Adds strategic bluffing; stale intel is visually distinct, never confused for live data |
| Visibility extension | Via `TroopType.visibility_range` and `TerritoryModifier.get_visibility_range()` | Scout units and watchtowers extend sight; `VisibilitySystem` picks up modifiers automatically |
| Multiplayer fog | Server filters state per client through `VisibilitySystem` | Clients must not receive HIDDEN data — this is a security requirement, not just a UI concern |
| General assignment | Auto-assign all territory generals on departure | Manual assignment is more strategic but adds UI complexity for unclear gain |
| En-route collision | Direction-agnostic | Two enemy armies on the same edge always collide, regardless of travel direction |
| Retreat mechanic | Legal only if met head-on; illegal if caught from behind | Caught-from-behind armies cannot disengage — adds pursuit/interception depth |
| Terrain movement speed | Bottleneck model: `min(source.speed_modifier, dest.speed_modifier)` | The harder terrain dominates; simpler to reason about than an average |
| Partial army selection | Three modes: all / proportional slice / specific troop type count | Covers all common intent without a complex UI |
| Army redirect mid-edge | Immediately reverses to source territory | Clean and predictable; no "finish current hop first" ambiguity |
| Player mode | Single-player vs AI locally; multiplayer is online-only | Avoids hotseat complexity; keeps local mode focused |
| SplitArmyCommand scope | Phase 2 | Split rule is meaningless without generals to split; defer until generals exist |
| General spawn threshold | Casualties must exceed a configurable threshold (e.g. 50 troops) | Small skirmishes should not mint generals; reward significant engagements |
| Building cost currency | Basic infantry deducted from territory garrison | Simplest possible resource model; creates meaningful tradeoff between troops and buildings |
| Production tick interval | Configurable constant in `GameSimulation` (~5–10 s) | Designer-tunable without touching game logic |
| Neutral territories | Have starting garrisons and produce troops | Creates meaningful early-expansion friction; players must fight through neutrals to grow their economy rather than free-real-estate the map |
| Lifecycle orchestration | `Main` script owns boot order; `GameSimulation` and `MapRenderer` expose `initialize(map_data)` instead of self-bootstrapping in `_ready` | Inversion of control: systems don't decide when they boot. Solves the autoload-fires-before-scene-subscribes bug and sets up Phase 5 map selection / Phase 6 server-driven init in the same stroke |
| Combat outcomes | Three mutually exclusive results: WIN, RETREAT, DEFEAT | "Lost then retreated" is incoherent — if combat resolved and you lost, you're destroyed. Retreat is a disengagement choice taken *instead* of fighting to resolution. `CombatResult` carries an outcome enum, not `winner: Army \| null + retreated_bool` |
| Army state machine encoding | Enum + `LEGAL_TRANSITIONS` const dict on `Army`, not State Pattern subclasses | Per-state behavior is trivial; the only structural concern is "what's legal next." Class hierarchy overhead doesn't pay off for 3 states. Revisit if a future entity has rich per-state behavior |
| `Dissolved` state | Not an enum value — army instance is removed from `GameSimulation.armies` when terminal | "Gone is gone." Avoids ambiguity between "exists but dissolved" and "doesn't exist." `army_dissolved(army_id)` signal fires *before* removal so listeners get one chance to react |
| Army path representation | Immutable; full route preserved including source territory. Position tracked via `current_edge` | Retreating reuses the same path with a direction flip (deferred to Phase 1 retreat work). Cheaper than mutating-path + reconstruction-on-retreat. Direction flag added when retreat is implemented |
| Army merging | Same lifecycle primitive as dissolution — merging army's composition adds to absorbing entity, merging instance removed | Not a state transition. Covers same-edge friendly collision, friendly reinforcement of ongoing combat, and arrival-into-friendly-garrison uniformly |
| State-machine legality layering | Army owns transition graph (structural); `GameSimulation` chooses which transition to apply (contextual) | Same shape as data-vs-presentation and bus-vs-direct-mutation, applied to state transitions. Lets `can_transition_to()` stay on Army as a pure structural check while context-dependent logic stays where the context lives |
| Renderer reads `army.progress` directly | Phase 1 only; Phase 6 will switch to dead-reckoning prediction | In-process shared memory makes direct read trivial; Phase 6's network boundary forces sparse signals + local extrapolation. The "live Army reference" payload on `army_spawned` works for both — discipline (not defensive copy) keeps the path open |
| Movement speed | `ARMY_MOVE_SPEED` constant in `GameSimulation` (Phase 1 only) | Cheap and centralized for now. Phase 2+ replaces with `min(army.troops.move_speed) × min(source.terrain.speed_modifier, dest.terrain.speed_modifier)` per design |
| Combat architecture | Three layers: orchestrator (`GameSimulation`) / integrator (`_apply_combat_result`) / pure resolver (`CombatResolver`). Resolver is `data → data` with no world knowledge | Resolver remains independently testable (drop in a `FixedOutcomeCombatResolver` and verify GameSim's reaction). Integrator owns world-state mutations and signal emission. Orchestrator decides when to call. Same data/presentation separation principle, applied at the combat layer |
| `CombatContext` shape | Perspectiveless: `armies: Array[Army]` + `territory_fight: TerritoryFight \| null`. No "attacker" / "defender" distinction | User-originated S6. Combat has no inherent perspective — territory garrisons can be attacked from any side; en-route collisions are direction-agnostic. The shape generalizes to N-way multi-party combat without a signature break |
| `TerritoryFight` sub-struct | Inner class bundling `territory_id` + `garrison` together (or `null`); not flat fields on `CombatContext` | Expresses the "both-or-neither" invariant in the type itself. Can't construct half of one. Same valid-by-construction principle from S5's state machine |
| `CombatResult` outcome granularity | Per-army `outcomes_by_army_id: Dictionary[army_id → Outcome]`, not a single per-combat outcome | Each army either WIN / RETREAT / DEFEAT independently. Generalizes to N-way; binary case is `{a: WIN, b: DEFEAT}` |
| Multi-party combat resolution (Phase 1) | Sequential pairwise: when 3+ opposing forces arrive at one territory in the same tick, resolve pairwise in arrival order. Order-dependence acknowledged | Simple, deterministic given a fixed order, matches the cascade-skip pattern used for multi-collision edges. True N-way resolver (option b) is the semantically preferred long-term shape and is deferred to Phase 2/3 when troop types and modifiers force combat math to grow up anyway |
| Friendly mid-edge merge | Smaller army dissolves into larger; larger keeps its own destination/path. Smaller's destination is discarded | Game-feel: "reinforcing an existing army on the move." Same lifecycle primitive as territory dissolution. Alternatives considered: pick by oldest army id (less obvious to player); don't merge at all (defensible but loses the design intent of friendly cohesion) |
| Edge-collision detection model | Crossing-detection via canonical-position projection on `[0,1]`, not "same-edge presence" | Crossing-detection gives correct game-feel — two armies marching across an edge meet in the middle, not on departure. "Same edge → collide" is the literal reading of the design spec; this is a spec upgrade (user-originated S6). Phase 1's uniform speed means only opposite-direction pairs can cross; same-direction overtake becomes possible in Phase 2 with variable terrain speed |
| Retreat as Command-layer concern (long-term) | Phase 2/3 reframes retreat as a `RetreatCommand` (army) or constrained `MoveArmyCommand` (garrison declining defense), not a special combat primitive. Phase 1 implements retreat as an automatic `ArmyState` transition for the head-on loser, because instant combat has no "during fight" moment for a command to be issued | User-originated S6 insight. Unifies retreat under the existing Command pattern instead of bolting on special-case logic in the combat layer. Phase 1 form is a stepping stone; Phase 2/3 reintroduces command-driven retreat alongside sustained combat |
| Interface forward-compat vs implementation forward-compat | Invest in *interface boundaries* up front (cheap; touches all callers if changed later); let *implementations* be exactly as ambitious as today's problem demands (YAGNI for behavior; expensive to write speculative math) | S6 principle. The `armies: Array[Army]` signature on `CombatContext` is forward-compat-at-interface (cost zero today); the actual multi-party math is forward-compat-at-implementation (not written; would be speculative). Same principle behind why `Outcome.RETREAT` is in the enum from day 1 but `AttritionCombatResolver` never emits it |
