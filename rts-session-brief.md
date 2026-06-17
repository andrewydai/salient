# RTS Game — Session Brief

> **How to use this file:** Paste it (along with `rts-game-design.md` and
> `rts-teaching-guide.md`) at the start of any new Claude session. Claude updates this file
> at the end of every session. The user adds their self-assessment verbally; Claude records it.

---

## Current State

- **Phase:** 1 — Core Game Loop
- **Session Number:** 2 (complete)
- **Current Task:** Ready to begin Session 3
- **Next Session Goal:** EventBus & Observer pattern — define initial signals, refactor
  `MapRenderer` click handling to emit through EventBus, demonstrate signal-driven decoupling
  with no direct references between systems

---

## What Exists

- `rts-game-design.md` — complete design spec with all Phase 1 decisions settled
- `rts-teaching-guide.md` — teaching curriculum (now includes a "Reading Project Files" section
  directing Claude to read source files directly rather than asking for paste)
- `rts-session-brief.md` — this file
- Godot 4.6 project at `res://`, window size 1280×720
  - Folder structure: `autoloads/`, `resources/`, `scenes/`, `scripts/`, `tools/`, `assets/`
  - Autoloads registered: `GameSimulation`, `CommandBus`, `EventBus`, `ThemeManager`
    (all at `res://autoloads/*.gd`, all empty `extends Node` stubs)
  - `res://resources/territory_data.gd` — `TerritoryData` Resource schema
  - `res://resources/map_data.gd` — `MapData` Resource schema
  - `res://resources/map_data.tres` — 15-territory hand-crafted `MapData` instance, 5×3 grid,
    IDs in `display_name_col_row` format, cardinal adjacency, player starts `rivermouth_0_2`,
    AI starts `dragons_rest_4_0`
  - `res://tools/generate_map.gd` — `@tool` `EditorScript` that programmatically generates
    `map_data.tres` (re-run after any schema or coordinate change)
  - `res://scripts/map_renderer.gd` — `MapRenderer` `Node2D` script. Reads `MapData` via
    `@export`, creates `Area2D` + `Polygon2D` + `CollisionPolygon2D` per territory, connects
    `input_event` signal with `.bind(data.id)`. `_on_territory_input` is a stub.
  - `res://scripts/territory_graph.gd` — `TerritoryGraph` plain class (`RefCounted`). Methods:
    `build(map_data)`, `get_neighbors(id)`, `find_path(from, to)` (BFS with `came_from` path
    reconstruction). Not yet instantiated or owned by any system.
  - `res://scenes/main.tscn` — Main scene with `MapRenderer` child node, `map_data.tres`
    assigned to its export

---

## Phase 1 Task Checklist

### Foundation
- [x] Project setup: folder structure, Autoloads registered, base scenes
- [x] `TerritoryData` and `MapData` resources defined
- [x] Hand-craft test map (15 territories)

### Map & Graph
- [x] Territory rendering: `Polygon2D` + `CollisionPolygon2D` + click detection
      (renderer + signal wiring done; click handler stub — InputController fills it later)
- [x] `TerritoryGraph`: adjacency list, BFS pathfinding
      (not yet wired into `GameSimulation` — happens when first command needs it)

### Simulation Core
- [ ] `GameSimulation` autoload: territory ownership, garrison counts, production tick
- [ ] `CommandBus` and `EventBus` autoloads wired up
- [ ] `MoveArmyCommand`: validate legality, create `Army`, begin hop-by-hop pathing

### Army Movement & Combat
- [ ] Army movement along path edges in real time
- [ ] Attrition `CombatResolver`: territory arrival combat
- [ ] En-route combat: direction-agnostic collision
- [ ] Retreat mechanic: head-on = can retreat; caught from behind = cannot
- [ ] Army dissolves into garrison on arrival at friendly territory
- [ ] Conquest cooldown: captured territories don't produce immediately

### Input & UI
- [ ] `InputController`: click to select, click destination to issue move order
- [ ] Partial army selection: all / proportional / specific troop type count
- [ ] Army click-to-redirect (`RedirectArmyCommand`)
- [ ] Basic HUD: TerritoryPanel, ArmyPanel, troop counts
- [ ] Win condition: last player with at least one territory

### Visibility
- [ ] `VisibilitySystem`: compute INTEL/STALE/HIDDEN per player per tick
- [ ] `IntelSnapshot`: store last-seen state when territory leaves INTEL
- [ ] Renderer respects visibility levels
- [ ] Stale indicator: `IntelSnapshot` data with question mark overlay
- [ ] Enemy in-transit armies hidden in non-INTEL territory

### Placeholder AI
- [ ] Minimal placeholder AI: random valid `MoveArmyCommand`s each tick

---

## Session Log

### Session 1
**Date:** 2026-06-14
**Status:** Complete

**Tasks completed:**
- Folder structure established (`autoloads/`, `resources/`, `scenes/`, `scripts/`, `assets/`)
- Four Autoloads registered in Project Settings: `GameSimulation`, `CommandBus`, `EventBus`, `ThemeManager`
- `Main` scene created (Node2D), set as main scene
- `TerritoryData` Resource schema written (`id`, `display_name`, `polygon_points`, `terrain_type`, `neighbors`, `base_production`, `passable`)
- `MapData` Resource schema written (`territories: Array[TerritoryData]`, `starting_positions: Dictionary`)

**Concepts taught:**
- Scene tree as behavioral runtime vs. Resources as data containers
- `extends Resource` and what it gives: serialization, reference counting, inspector integration, `duplicate()`
- Autoloads as global persistent singletons; why hierarchy traversal is an anti-pattern
- Definition data (TerritoryData schema) vs. runtime state (ownership, garrison — lives in GameSimulation)
- Why `neighbors` uses `Array[String]` IDs instead of direct Resource references (circular serialization)
- Why `class_name` is needed on Resources but not Autoloads
- CommandBus as state-mutation chokepoint vs. EventBus as notification bus (preview of Sessions 3 & 4)
- `.tres` files as serialized Resource instances; the class/instance distinction

**Claude observations:**
- User arrived at the Command pattern rationale independently and articulated it well before it was named
- Made `extends Node` instead of `extends Resource` twice (TerritoryData and MapData) — likely muscle memory from tutorials. Worth watching in future sessions when new Resource scripts are added.
- Initially put `territory_owner` and `conquest_cooldown` on `TerritoryData` — conflated definition data with runtime state. Corrected quickly once the distinction was named.
- CommandBus vs. EventBus answer (fireworks example) was unprompted and accurate — strong signal that the decoupling intuition has landed.
- Strong moment: independently described the cyclic serialization problem with direct Resource references.

**User's Self-Assessment (verbatim):**
"I think i'm still a little fuzzy on the mechanics of Resources, primarily that such a distinction is necessarily made in a more generic language like python. Alot of other things clicked like AutoLoaders, and I have a better understanding of the overall architecture we're progressing towards"

---

### Session 2
**Date:** 2026-06-16
**Status:** Complete

**Tasks completed:**
- Hand-crafted 15-territory `MapData` resource via `@tool` `EditorScript` (`generate_map.gd`),
  saved to `res://resources/map_data.tres`. 5×3 grid layout, IDs use `display_name_col_row`
  format, cardinal adjacency
- `MapRenderer` (`Node2D`) reads `MapData` via `@export`, instantiates `Area2D` per territory
  with `Polygon2D` (visual) and `CollisionPolygon2D` (collision/input) children. Signal
  `input_event` connected via `_on_territory_input.bind(data.id)` to bake territory ID into
  the callback. Handler stub left for InputController in Session 8.
- `TerritoryGraph` plain class (implicit `RefCounted`): builds adjacency dictionary from
  `MapData`, exposes `get_neighbors()`, `find_path()` BFS with `came_from` path reconstruction.
- `MapRenderer` wired into `main.tscn`; `map_data.tres` assigned in inspector. Project
  window size set to 1280×720 to match map coordinates.
- Teaching guide updated: added "Reading Project Files" section instructing Claude to read
  source files directly rather than ask for paste.

**Concepts taught:**
- Data/presentation separation as the core architectural principle. Renderer reads data;
  data has no outbound knowledge. Verified concretely by regenerating `.tres` with new ID
  format — `MapRenderer` required zero changes.
- The `.tres` machinery made tangible: user created an empty `MapData` resource in the
  inspector, saw the `@export` fields and the script binding, resolving the Session 1 fuzziness.
- Polygon winding order: `Polygon2D` connects vertices in order and closes the loop;
  self-intersecting winding produces visual garbage (no error).
- `Area2D` vs `CollisionPolygon2D` — behavior node vs. shape data. Same data-vs-behavior
  split as the rest of the architecture. "Area" in Godot is the physics-zone sense,
  not the geometric sense.
- `@tool` annotation: makes a script execute in the editor's GDScript runtime. Without it,
  editor scripts are inert.
- `EditorScript` for one-off generation tasks (run via File > Run in Script editor).
- Engine singletons (`ResourceSaver`, `Input`, `OS`) vs user-defined Autoloads.
- `Callable.bind()` — partial application of arguments at signal-connect time; the GDScript
  equivalent of a Python/TS closure capturing a variable.
- BFS pathfinding with `came_from` parent-map reconstruction.
- When to make a scene (`.tscn`) vs. just attach a script: promote to scene when the editor
  needs to see its internal structure for configuration or reuse.

**Claude observations:**
- User immediately generalized to a `for row in rows, for col in cols` loop in
  `generate_map.gd` rather than hardcoding 15 entries. Smart structural instinct.
- Two bugs caught Socratically and fixed without direct fix: (a) all four adjacency appends
  were passing the current territory's coordinates instead of the neighbor's, (b) polygon
  winding order was Z-shape instead of clockwise. User found and explained both.
- Independent ID format change to include display name (`iron_hills_0_0` vs `0_0`) — small
  but indicates ownership of the data model.
- First BFS attempt had a fundamental bug: `prev_ter` initialized once to `from_id`, never
  updated in the loop, so `came_from` was always pointing to source. User reorganized cleanly
  after one Socratic nudge ("where does `prev_ter` get updated?"). Result was textbook BFS.
- Caught the missing-destination bug in `trace_came_from` after one trace request. Reconstruction
  logic is now correct.
- Good architectural curiosity: asked unprompted about scene vs. script choice, and about
  Area2D/CollisionPolygon2D naming asymmetry (which led to a useful detour on what "Area"
  means in physics-engine terminology).
- The user's "where do TerritoryGraph and the path-finding live" reasoning was first incorrect
  (CommandBus) but they self-corrected to GameSimulation with a single nudge about
  CommandBus's actual role.

**User's Self-Assessment (verbatim):**
"I think i feel good about what we covered, but i'm still learning and beginning to wonder how i might plan such a large project or architecture myself, a lot of these decisions and principles make sense when shown to me, but i can recall my previous projects and note their immature designs and it shows me i have a lot to learn still"

---

## Carry-Forward Notes

- **Resources vs. plain classes (resolved Session 2):** User saw the `.tres` machinery first-hand
  by creating an empty `MapData` resource in the inspector before deleting it, and then by
  generating a populated one via `ResourceSaver`. The fuzziness from Session 1 appears resolved.
- **`extends Resource` muscle memory:** Did not recur in Session 2 (no new Resource subclasses
  written). Keep watching when new Resources are added.
- **Command pattern intuition is strong:** User independently articulated the Command pattern rationale. In Session 4, remind them they had this insight in Session 1 before naming it.
- **Originating architecture vs. recognizing it (new, Session 2):** User flagged in their
  self-assessment that they feel architectural principles "make sense when shown" but they
  wouldn't have originated them. This is the right phase of growth to be in — the curriculum's
  strategy of *naming each pattern before coding it* is the answer. By the end of Phase 1,
  the user should be able to name and explain every pattern unprompted. Track this gap:
  starting Session 6 (Strategy) and Session 8 (Command revisited), have them name the pattern
  *before* it is introduced — that's the test.
- **`TerritoryGraph` not yet integrated:** Built and unit-correct, but no system instantiates
  it yet. `GameSimulation` will own it when `MoveArmyCommand` lands (Session 4).
- **`_on_territory_input` is a stub:** Wired but does nothing. Session 3 should consider
  whether the click handler emits through `EventBus` (likely) or whether that's deferred until
  Session 8 with `InputController`. Probably the right move in Session 3: emit a
  `territory_clicked(territory_id)` signal as the demonstration of the Observer pattern.
- **Algorithmic work may need more scaffolding:** BFS implementation took two iterations.
  When future algorithm-heavy work appears (visibility BFS in Session 10, AI scoring in Phase 4),
  consider providing more skeletal structure up-front to reduce thrash.

---

## Open Questions / Deferred Decisions

- None yet.

---

## How Claude Should Start Each Session

1. Read this file, `rts-game-design.md`, and `rts-teaching-guide.md`.
2. Greet the user, state the current task and what was done last session (one sentence each).
3. Ask if anything has changed or if they have carry-over questions before starting.
4. Follow the session structure in the teaching guide: Orient → Concept → Scaffold →
   Implement → Reflect → Wrap.
5. At session end: ask for the user's self-assessment, record it verbatim, update this file.
