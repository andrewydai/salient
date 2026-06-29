# RTS Game — Session Brief

> **How to use this file:** Paste it (along with `rts-game-design.md` and
> `rts-teaching-guide.md`) at the start of any new Claude session. Claude updates this file
> at the end of every session. The user adds their self-assessment verbally; Claude records it.

---

## Current State

- **Phase:** 1 — Core Game Loop
- **Session Number:** 6 (complete)
- **Current Task:** Ready to begin Session 7
- **Next Session Goal:** Retreat & Conquest Cooldown. **Open with throwaway fix** of the
  `_find_collided_army` field-name typo (`edge_obj.is_reversed` → `edge_obj.reversed`,
  lines 261-262), verified with a head-on multi-army test (one human army + one AI army on
  opposite ends of the same edge — they should meet mid-edge and collide/merge cleanly).
  Then main arc: implement retreat as an `ArmyState` transition for the loser of a head-on
  edge collision (Phase 1 form — automatic, no Command involvement). Note S6 reframe: the
  *long-term* design has retreat as a Command-layer concern (player issues `RetreatCommand`
  mid-fight); Phase 1's instant resolution doesn't have a "during fight" moment so retreat
  collapses to a state-machine transition. Phase 2/3 reintroduces command-driven retreat when
  sustained combat lands. Also: conquest cooldown for captured territories — set timer on
  capture, suppress production during cooldown. Stub semantics here; the proper
  `ConquestCooldownModifier` Resource lives in Phase 3.

---

## What Exists

- `rts-game-design.md` — complete design spec with all Phase 1 decisions settled
- `rts-teaching-guide.md` — teaching curriculum (now includes a "Reading Project Files" section
  directing Claude to read source files directly rather than asking for paste)
- `rts-session-brief.md` — this file
- Godot 4.6 project at `res://`, window size 1280×720
  - Folder structure: `autoloads/`, `resources/`, `scenes/`, `scripts/`, `scripts/commands/`,
    `tools/`, `assets/`
  - Autoloads registered: `GameSimulation`, `CommandBus`, `EventBus`, `ThemeManager`
  - `res://resources/territory_data.gd` — `TerritoryData` Resource schema
  - `res://resources/map_data.gd` — `MapData` Resource schema
  - `res://resources/map_data.tres` — 15-territory hand-crafted `MapData` instance, 5×3 grid,
    IDs in `display_name_col_row` format, cardinal adjacency, player starts `rivermouth_0_2`,
    AI starts `dragons_rest_4_0`
  - `res://tools/generate_map.gd` — `@tool` `EditorScript` that programmatically generates
    `map_data.tres` (re-run after any schema or coordinate change)
  - **Commands (new in Session 4):**
    - `res://scripts/commands/command.gd` — `class_name Command extends RefCounted`. Marker
      base class. One shared field: `issuer_player_id: String`. Inherited by every concrete
      command type so the bus has a usable type signature and validation can check who issued.
    - `res://scripts/commands/move_army_command.gd` — `class_name MoveArmyCommand extends
      Command`. Pure data: `from_territory: String`, `to_territory: String`, `composition:
      Dictionary`. No execute() method — anemic-command flavor; `GameSimulation` executes.
  - **CommandBus (real in Session 4):**
    - `res://autoloads/command_bus.gd` — `submit(command: Command)`. Dispatches on type
      (`if command is MoveArmyCommand`), asks `GameSimulation.is_move_legal(command)`, hands
      to `GameSimulation.apply(command)` if legal. Distinguishes "unknown command type"
      (warn + return) from "known command, illegal" (warn, drop).
  - **GameSimulation (real in Session 4):**
    - `res://autoloads/game_simulation.gd` — constants for `PLAYER_ID_HUMAN`, `PLAYER_ID_AI`,
      `PLAYER_ID_NEUTRAL`, `TROOP_TYPE_INFANTRY`. State dicts: `territories` (cache of
      `TerritoryData` by ID — derived, marked as such), `territory_owner`, `territory_garrison`.
      Lifecycle is **not** in `_ready`: exposes `initialize(data: MapData)` for an orchestrator
      to call. `apply(command)` dispatches; `_apply_move_army` deducts composition from source
      garrison and emits `garrison_changed` (no Army entity yet — Session 5). `is_move_legal`
      checks existence, ownership against `issuer_player_id`, `from != to`, composition is
      achievable from garrison. Production `Timer` instantiated in `initialize`, ticks every
      `PRODUCTION_TICK_INTERVAL = 5.0` seconds, increments every territory's garrison by
      `base_production` and emits `garrison_changed` per territory.
  - **Main orchestrator (new in Session 4):**
    - `res://scripts/main.gd` — script attached to the Main scene. Preloads `map_data.tres`,
      calls `map_renderer.initialize(map)` FIRST, then `GameSimulation.initialize(map)`.
      Order matters: consumer must be subscribed before producer emits the seed signals.
  - `res://scripts/map_renderer.gd` — `MapRenderer` `Node2D`. Removed `@export var map_data` —
    now receives `MapData` via `initialize(data)`. Subscribes to EventBus signals in `_ready`,
    builds territories in `initialize`. `_garrison_changed_handler` now receives a Dictionary
    and sums troop counts to a display int.
  - `res://scripts/territory_node.gd` — `TerritoryNode` (`extends Area2D`). Refactored to use
    centroid-based positioning: each node is positioned at its polygon's centroid; vertices
    are stored in local coordinates relative to that position. Owns `polygon_2d`,
    `coll_polygon_2d`, `garrison_label`, and now `title_label`. Children at local (0,0) live
    at the territory's true center.
  - `res://scripts/territory_graph.gd` — `TerritoryGraph` plain class. Methods: `build(map_data)`,
    `get_neighbors(id)`, `find_path(from, to)` (BFS). **Now wired into GameSimulation as of S5
    — built in `initialize()`, used for reachability check in `is_move_legal` and for full-path
    resolution in `_apply_move_army`.** `find_path` returns the *full* path including the source
    territory (`[from, hop1, ..., to]`).
  - `res://scripts/dev_keys.gd` — keys 1/2 still fake `territory_owner_changed` for renderer
    sanity. Key 3 fakes `garrison_changed`. Key 4 issues a real `MoveArmyCommand` through
    `CommandBus.submit(...)` — `rivermouth_0_2 → sunken_road_1_2`. With S5 movement live, this
    now spawns an Army that ticks across the edge and hits the enemy-arrival `print('fight')`
    stub (since `sunken_road_1_2` is neutral).
  - `res://autoloads/event_bus.gd` — six signals: `territory_clicked(String)`,
    `territory_owner_changed(String, String)`, `garrison_changed(String, Dictionary)`,
    `army_spawned(army: Army)`, `army_dissolved(army_id: String)`, `army_advanced_hop(army: Army)`.
    Note in file: no per-frame progress signals — renderer reads `army.progress`
    directly each frame (discrete-vs-continuous-state framing from S3 made concrete). **S6
    deliberately did NOT add an `army_composition_changed` or `combat_resolved` signal** — the
    renderer reads composition directly from the live Army ref, and no Phase 1 consumer needs to
    *react* to the combat event. When reactive consumers appear (Phase 2 UI / audio / AI
    awareness), the right signal is `combat_resolved(ctx, result)` carrying full event payload,
    not a value-update signal. Same S3 push-rich-payload rule.
  - **Army entity (new in S5):**
    - `res://scripts/army.gd` — `class_name Army extends RefCounted`. `State` enum
      (`MOVING, FIGHTING, RETREATING`). `const LEGAL_TRANSITIONS` dict encodes the structural
      transition graph (`MOVING → FIGHTING`; `FIGHTING → MOVING | RETREATING`;
      `RETREATING → FIGHTING`). No `DISSOLVED` enum value — "gone is gone," entity removed from
      `armies` dict. Fields: `id`, `owner_id`, `composition`, `path: Array[String]`,
      `current_edge: Array[String]`, `progress: float`, `state: State`. `can_transition_to(target)`
      one-liner is the structural-legality API; `GameSimulation` calls it. No `transition_to()` —
      Army is pure data + schema; simulation owns the transition decision (structural vs
      contextual layering).
    - Path representation: **immutable, source preserved** (Option B from S5 discussion).
      `army.path = [from, hop1, ..., dest]` for the whole army lifetime. Position is tracked via
      `current_edge`; the helpers use `path.find(current_edge[1])` to advance. Direction flag
      deferred to S7 when retreat is implemented.
  - **GameSimulation (expanded in S5):**
    - Now owns: `armies: Dictionary`, `_next_army_id: int`, `_territory_graph: TerritoryGraph`.
      `ARMY_MOVE_SPEED: float = 0.5` constant (≈ 2 s/edge).
    - `initialize(map_data)` now also builds `_territory_graph`.
    - `is_move_legal` adds a reachability check via `_territory_graph.find_path(...).size() == 0`.
    - `_apply_move_army` upgraded: deducts garrison (existing) → calls `find_path` → constructs
      Army (state defaults to `MOVING`, `current_edge = [path[0], path[1]]`) → inserts into
      `armies` → emits `army_spawned(army)`.
    - `_process(delta)` collects-then-processes: advances every army's progress by
      `ARMY_MOVE_SPEED * delta`, collects arrivals (progress ≥ 1.0), calls
      `_on_army_arrived_at_hop` *after* iteration (safe mutation pattern).
    - `_on_army_arrived_at_hop(army)` branches on owner of `current_edge[1]` and final-hop
      status: enemy/neutral → `print('fight')` (Session 6 stub); friendly + final → dissolve;
      friendly + more hops → advance. Known intentional limitation: army stays in dict after
      enemy arrival and re-fires every frame ("fight" spams console) until Session 6 introduces
      `FIGHTING` state transition.
    - `_dissolve_army_into_garrison`: adds composition into destination garrison, emits
      `garrison_changed` and `army_dissolved(army.id)`, removes from `armies`.
    - `_advance_army_to_next_hop`: locates current edge destination in path via `find()`,
      builds new `current_edge` two hops forward, resets `progress = 0.0`, emits
      `army_advanced_hop(army)`. Path is never mutated.
    - Typed-array gotcha applied: `current_edge` assignments use `as Array[String]` casts on
      array literals (Godot 4 typed arrays reject untyped Array literals on assignment).
  - `res://scenes/main.tscn` — Main has `main.gd` attached. Children: `MapRenderer`, `DevKeys`,
    `Camera2D` (offset (640, 400), zoom (0.75, 0.75) — centers on the 1280×720 map).
  - **Combat (new in S6):**
    - `res://scripts/combat/combat_resolver.gd` — `class_name CombatResolver extends RefCounted`.
      Abstract Strategy base. Inner classes: `TerritoryFight` (territory_id + garrison —
      bundles the both-or-neither invariant into the type per user's option 2 in S6),
      `CombatContext` (armies: Array[Army], territory_fight: TerritoryFight or null —
      perspectiveless, multi-party-shaped from day 1), `CombatResult` (Outcome enum
      WIN/RETREAT/DEFEAT, outcomes_by_army_id: Dictionary — per-army granularity not per-combat,
      updated_army_compositions, updated_territory_garrison). `resolve_combat(context) -> result`
      is the contract — abstract, push_error if unoverridden.
    - `res://scripts/combat/attrition_combat_resolver.gd` — `class_name AttritionCombatResolver
      extends CombatResolver`. 4-case binary 1:1 attrition (territory_fight × who-wins
      permutation). Builds dicts incrementally then assigns to result fields at the end (clean
      after the GDScript dict-literal computed-key learning).
  - **GameSimulation (expanded heavily in S6):**
    - `initialize(map_data, combat_resolver)` — IoC continued, resolver injected at boot.
    - Holds `_combat_resolver: CombatResolver` field. `main.gd` constructs and passes the
      `AttritionCombatResolver` instance.
    - `_on_army_arrived_at_hop` for enemy/neutral arrivals: builds `CombatContext` with single
      attacker + TerritoryFight, calls `_combat_resolver.resolve_combat(ctx)`, applies via
      `_apply_combat_result(ctx, result)`.
    - `_apply_combat_result(ctx, result)` — the integrator. Pass 1 walks
      `outcomes_by_army_id`: DEFEAT → erase + emit `army_dissolved`; WIN → collect winner;
      RETREAT → unreachable in Phase 1 (no `RetreatCommand` issued yet — Phase 2/3 form
      reintroduces it). Pass 2 branches by `ctx.territory_fight != null`: territory WIN updates
      ownership + garrison + dissolves attacker; territory DEFEAT keeps defender garrison from
      result + dissolves attacker; edge WIN applies surviving composition to winner army.
    - `_process(delta)` — extended with en-route collision detection. Phase 1 advances army
      progress + collects arrivals. Phase 2 (new) groups armies by edge_key, calls
      `_find_collided_army` to detect crossings (canonical-position projection on [0,1]; only
      opposite-direction pairs can cross in Phase 1 with uniform speed), collects
      `collision_events`. Phase 3 processes events with cascade-skip
      (`if not armies.has(...) continue`) for the "passes two armies in one frame" case.
    - `_resolve_edge_collision(a, b)` — branches owner_id: enemy → resolve_combat with no
      territory_fight; friendly → `_merge_armies(a, b)`.
    - `_merge_armies(a, b)` — smaller dissolves into larger (per S6 user choice: "reinforcing
      existing army on the move"). Larger absorbs smaller's composition; smaller is erased +
      `army_dissolved` emitted. Larger keeps its own destination/path.
    - Helpers: `_edge_key(edge)` returns lexicographic `min->max` form; `_canonical_position(army)`
      projects progress onto [0,1] forward direction; `_total_troops(army)` sums composition;
      `_find_collided_army(edge_list, cur_pos, is_reversed)` returns first opposite-direction
      neighbor whose canonical position has crossed the current army's.
    - **Known bug (filed for S7 throwaway open):** `_find_collided_army` lines 261-262 use
      `edge_obj.is_reversed` but the dict key stored at line 70 is `'reversed'`. Field access on
      missing key silently returns `null` → branch 1's third clause always passes (false
      positives for same-direction backwards, masked in Phase 1 by uniform-speed gap stability);
      branch 2's third clause always fails (false negatives — forward armies never detect
      backward existing entries). Rename and verify with multi-army head-on test.
  - `res://scripts/main.gd` — now constructs `AttritionCombatResolver` and passes it to
    `GameSimulation.initialize(map, resolver)`.

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
- [x] `GameSimulation` autoload: territory ownership, garrison counts, production tick
      (Production tick fires every 5s and increments every territory's garrison by
      `base_production`. Lifecycle moved out of `_ready` into `initialize(map_data)` for
      orchestrator-driven boot.)
- [x] `CommandBus` and `EventBus` autoloads wired up
      (CommandBus dispatches on command type, validates via `is_move_legal`, applies via
      `apply()`. EventBus garrison signal payload upgraded from int to Dictionary.)
- [x] `MoveArmyCommand`: validate legality, create `Army`, begin hop-by-hop pathing
      (Full pipeline lives — `is_move_legal` checks ownership/composition/reachability,
      `_apply_move_army` spawns a real Army with path resolved via TerritoryGraph and
      `current_edge` initialized.)

### Army Movement & Combat
- [x] Army movement along path edges in real time
      (`_process(delta)` advances `progress` per frame; arrival triggers branching
      via `_on_army_arrived_at_hop`.)
- [x] Attrition `CombatResolver`: territory arrival combat
      (Strategy pattern; 4-case binary attrition math; verified end-to-end via dev key 4 —
      attacker conquers when stronger, repelled when weaker, ownership/garrison signals fire.)
- [x] En-route combat: direction-agnostic collision
      (Crossing-detection via canonical-position projection; collect-then-process with
      cascade-skip. **Field-name typo bug pending S7 throwaway fix** before multi-army
      head-on test verifies it.)
- [ ] Retreat mechanic: head-on = can retreat; caught from behind = cannot (Session 7 main arc)
- [x] Army dissolves into garrison on arrival at friendly territory
      (`_dissolve_army_into_garrison` adds composition, emits signals, removes from dict.)
- [ ] Conquest cooldown: captured territories don't produce immediately (Session 7 alongside retreat)
- [x] Friendly army merging on shared edge or into ongoing combat
      (S6: smaller dissolves into larger, larger keeps destination — user-chosen convention.
      `_merge_armies` is the shared lifecycle primitive with `_dissolve_army_into_garrison`.)

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

### Session 3
**Date:** 2026-06-19
**Status:** Complete

**Tasks completed:**
- `EventBus` populated with three typed signals: `territory_clicked(String)`,
  `territory_owner_changed(String, String)`, `garrison_changed(String, int)`.
- `MapRenderer` refactored: per-territory subtrees promoted into a `TerritoryNode` class
  (`extends Area2D`) that owns its own `Polygon2D`, `CollisionPolygon2D`, and `Label`.
  `MapRenderer` keeps a `territories_by_id: Dictionary` and dispatches signal handlers to
  the corresponding `TerritoryNode` via small intentional methods (`set_owner_color`,
  `set_garrison_count`).
- `MapRenderer._on_territory_input` stub replaced with a one-liner that emits
  `EventBus.territory_clicked(territory_id)`. No listener yet — proves "emit into the void."
- `dev_keys.gd` created and attached to Main. Keys 1/2/3 fire EventBus signals at runtime
  to verify the renderer reacts with no simulation present.

**Concepts taught:**
- **Observer pattern**, named and applied. Subject emits, observers listen, neither side
  knows the other exists.
- **EventBus as a scope choice on top of signals** — not a different mechanism; a deliberate
  decision to globalize the meeting place when emitter/listener shouldn't have a structural
  relationship. Local signals are still right when parties already share a structural tree.
- **Push vs. pull.** Pull means consumers know when to ask, which leaks timing knowledge out
  of the owner. Push (with informative payloads) keeps the source of truth in charge.
  Rejected the "notify-then-pull" smell where a signal says "go look" instead of "here it is."
- **Discrete state vs. continuous state.** Discrete = signal-friendly. Continuous (e.g. army
  position during a hop) = renderer predicts from sparse signals using its own clock and
  corrects when a new signal lands. Comment in `Army.progress: float # visual only` is a
  preview — covered properly in Session 5.
- **The two-models pattern**: simulation owns the authoritative model; renderer owns a
  *disposable prediction*. Not two sources of truth — one truth and one replaceable guess.
- **Godot signal mechanics**: synchronous emission by default, handlers run on the same
  thread in connection order, autoloads process before scene tree, so within one frame the
  full chain (sim advances → emits → handlers run → renderer animates) completes sub-frame.
  `call_deferred` / `await` exist for the cases where you don't want that.
- **Encapsulation as the same data/presentation principle at a smaller scale.** Brittle
  `find_child(...).find_child(...)` in handlers was reaching into another node's internals;
  promoting to `TerritoryNode` gave per-territory visuals a home with a small intentional API.
- **Open/Closed Principle** named explicitly. The pattern's full payoff: adding a new
  observer (audio system, achievement system, AI hook) requires *zero* modification of
  existing files — only a new file and configuration to register it.
- **System independence via interface mediation** — the formal name for what makes both
  "headless simulation" (Phase 6) and "headless renderer" (today's `dev_keys.gd`) possible.

**Claude observations:**
- User raised an unprompted, high-quality meta-question about when decoupling stops being
  worth it (bullet hell, souls-like). Engaged with real engineering nuance — answered with
  "what changes independently, and for what reasons" as the criterion. User seemed to absorb
  the framing well.
- Strong moment: when asked for three concrete pains of direct-call coupling, user named two
  cleanly (OCP violation, signature coupling) and was nudged to the third (headless
  impossibility) with a single Socratic prompt. Got it immediately and articulated it back
  in their own words.
- Excellent question about pull-vs-push timing: "wouldn't the renderer need to read garrison
  values constantly?" Led to the discrete-vs-continuous discussion, which is foundational
  for Sessions 5 and 10. Worth flagging — this user is asking the right architectural
  questions ahead of when the curriculum introduces them.
- The "two mental models" worry was the deepest moment of the session. User correctly
  identified the tension and was anxious about stability. Resolution (prediction is
  disposable, not a second truth) landed visibly. Quote of the session in their reflection:
  the renderer is "dumb" and "tries its best based on the signals it gets."
- Architectural curiosity around signal-handler async behavior and node creation in
  handlers — flagged the right concerns (performance budget, `call_deferred`, `await`).
  Did not need these in practice today but the awareness is in their head now.
- When asked to draft a first signal vocabulary, user produced 5 signals and self-diagnosed
  that two had the "notify-then-pull" smell *before being told*. Very strong sign that the
  push/pull framing landed.
- `find_child` brittleness: user felt it but couldn't fully name it. Walked them through
  three specific problems (O(N) walk, stringly-typed lookups, encapsulation violation),
  offered two options (cache dict / promote to class), let them pick. They chose Option B
  (TerritoryNode class) without hesitation. Implementation was clean.
- Reflection at end was unusually strong. Without prompting, articulated: Observer pattern,
  payload-richness, "MapRenderer and GameSimulation don't know each other's existence,"
  EventBus as bridging interface. Named what `dev_keys.gd` proved (inverse of headless sim).
  Walked through the audio-system thought experiment correctly (new file, no modifications).
- Minor: small typo in `territory_node.gd` line 24 (`polygon_2d.\tcolor = color` — stray
  tab between `.` and `color`). GDScript appears to tolerate it. Worth a quick fix next
  session if it bothers them; not blocking.

**User's Self-Assessment (verbatim):**
"I feel good about the observer subscriber pattern, and learned the overarching pattern it points to with system independence via interface mediation. I also learned about OCP. I learned about the ordering of the process tree, dev keys, and in general best practices with this "source of truth game simulation" and the "tries its best renderer/downstream systems". I think for now nothing's immediately fuzzy."

---

### Session 5
**Date:** 2026-06-25
**Status:** Complete

**Tasks completed:**
- `Army` class (`res://scripts/army.gd`): `class_name Army extends RefCounted`. `State` enum
  (MOVING/FIGHTING/RETREATING), `LEGAL_TRANSITIONS` const dict, fields (`id, owner_id,
  composition, path, current_edge, progress, state`), `can_transition_to(target)` one-liner.
  Pure data + schema; no `transition_to()` method — simulation owns the transition decision.
- `TerritoryGraph` wired into `GameSimulation` (was orphan since S2): built in `initialize()`,
  reachability check added to `is_move_legal`.
- `EventBus` got three new signals: `army_spawned(army: Army)`, `army_dissolved(army_id: String)`,
  `army_advanced_hop(army: Army)`. Payload-richness rule from S3 applied (live Army ref, not
  snapshot — defensive copy would break Phase 6 evolution and conflict with the chosen design
  where renderer reads `army.progress` directly each frame).
- `GameSimulation` got: `armies` dict, `_next_army_id` counter, `_territory_graph` reference,
  `ARMY_MOVE_SPEED = 0.5` const, `_process(delta)` collect-then-process loop,
  `_on_army_arrived_at_hop` four-way branching (owner × final-hop), `_dissolve_army_into_garrison`
  and `_advance_army_to_next_hop` helpers.
- `_apply_move_army` upgraded to spawn a real Army: full path from `find_path`, immutable path
  with source preserved, `current_edge = [path[0], path[1]]`, added to `armies` dict, emits
  `army_spawned`.
- Verified end-to-end via dev key 4: garrison decrements at source, progress ticks per frame,
  arrives at neutral `sunken_road_1_2`, branches to enemy stub (`print('fight')` — expected S6
  TODO). Console spam from re-firing every frame after arrival is correct-for-S5 behavior;
  Session 6's `FIGHTING` transition will short-circuit.

**Concepts taught:**
- **State machine pattern**, formally named. User disclosed OOD/tutorial familiarity up front —
  saved 15+ min of concept time and let us go deeper on the application. Contract-not-just-labels
  framing landed without resistance.
- **Same-state criterion**: two situations are the same state if and only if the legal-operation
  set is identical. Used to defend Retreating as its own state (not "Moving backward") —
  Retreating doesn't accept `RedirectArmyCommand`, Moving does, so they're different states.
- **"Make illegal states unrepresentable" / valid-by-construction.** User landed and rephrased
  the principle themselves before being told the name: "each state by name defines exactly what
  state it's in." Strong unprompted articulation.
- **State name vs state parameters distinction.** Not all data on Army is "state" in the
  state-machine sense. `path`, `progress`, `current_edge` are *parameters* — describe the
  specifics within a state, don't change "what's legal next." Crisp rule: state name answers
  "what's legal next"; parameters answer "the specifics of right now."
- **Structural vs contextual legality.** Army owns the transition graph (structural); GameSimulation
  chooses which transition to apply (contextual). Same shape as data-vs-presentation (S1),
  signal-vs-direct-call (S3), bus-vs-direct-mutation (S4). Same principle, new layer.
- **State Pattern vs enum + const table.** Pattern's complexity must match the problem's actual
  complexity. State Pattern earns its keep when per-state behavior is rich (enter/exit hooks,
  per-state tick logic). For Army's 3 states whose differences are entirely "what's legal next,"
  enum + const dict beats class hierarchy.
- **WIN / RETREAT / DEFEAT outcome enum.** Design refinement triggered by user's sharp
  observation that "losing then retreating" is incoherent. Combat resolves to one of three
  mutually exclusive outcomes — going into Design Decisions Log.
- **Merging as entity-lifecycle, not state transition.** Friendly army collision (same edge or
  into ongoing fight) is the dissolution primitive: merge composition, remove instance, signal.
  State machine doesn't need to know.
- **Authority lives where decisions are made.** Sim drives movement cadence via `_process(delta)`
  because sim makes transition decisions. Armies can't authoritatively drive their own movement
  when the decision-maker is the sim. Connects back to S4 IoC.
- **Collect-then-process iteration pattern** for safe mutation of collections during iteration.
  Phase 1: iterate read-only, collect into side list. Phase 2: act on side list, mutate
  underlying collection.
- **Immutable history vs reconstructed mutable state.** Option B (immutable path) is cheaper at
  retreat time than Option A (mutating path + rebuild on retreat). User self-derived this in Q4.
  General principle worth filing.
- **Phase 6 reality check on the S3 "renderer predicts" framing.** Direct in-process reads work
  in Phase 1 because there's no wire. In Phase 6, sparse-signals + local prediction isn't a
  preference — it's the only architecture that bandwidth/latency permit. Direct read literally
  stops working when the wire goes in; the migration is forced.
- **Typed-array gotcha** (Godot 4 specific). Array literals default to untyped `Array`; assigning
  into a typed-array property requires explicit `as Array[T]` cast or a typed temp var. Handled
  inline per teaching-guide "tighter throwaway discipline."
- **Performance instinct calibration**, take three. User asked about cost of `as Array[String]`
  casts. Same family as S4 bulk-vs-granular signals: perf intuition is healthy but often fires
  at the wrong layer. User accepted the framing immediately.
- **Subsystem extraction preview.** User worried in Reflect about `GameSimulation` file size.
  Previewed orchestrator/subsystem split: `GameSimulation` delegates to `CombatResolver` (S6),
  `VisibilitySystem` (S10), `TerritoryGraph` (already done), `AIController` (Phase 4). The
  resolution to file-size worry is delegation, not per-state class hierarchies for Army.

**Claude observations:**
- Session opened with rapid recalibration: user disclosed state-machine familiarity in their
  *first reply*. Saved meaningful concept-phase time and let us go deeper on application. Worth
  asking this question explicitly at session start in S6+ — "what do you already know about X."
- Q2 of the diagnostic ("where does legality live") was the strongest moment. User reasoned
  from a single nudge ("on Army / in GameSim / in CommandBus — tradeoffs?") to the structural-vs-
  contextual layering. Self-derived, not recognized after introduction.
- WIN/RETREAT/DEFEAT outcome reframing was unprompted and improved the design materially.
  Recorded in Decisions Log as user-credited. This is the kind of architectural origination the
  user worries they can't do — they did it, in this session, on a non-trivial design call.
- Make-illegal-states-unrepresentable principle was rephrased in user's own words *before*
  being named. Quote: "each state by name defines exactly what state it's in." Strong
  pattern-arriving.
- Option B (immutable path) commit was real architectural ownership. The flaw in their initial
  implementation (source still popped at spawn) was caught Socratically by reading code together,
  then they corrected it themselves. Don't rescue prematurely — they get there.
- Friendly-army-merging concern came up unprompted. They verified the state machine doesn't block
  it before moving on. Healthy defensive instinct on the just-introduced architecture.
- Q5 reflection ("worried about GameSimulation file size, expected per-state classes") was a
  quality architectural concern. It opens the S6 door — `CombatResolver` extraction is the first
  concrete answer. Preview landed; user can think about orchestrator/subsystem between sessions.
- User's "originating vs recognizing" self-diagnosis is accurate but slightly too harsh. They
  named patterns *after* introduction this session (state machine, valid-by-construction). They
  *originated* specific architectural decisions (Option B, WIN/RETREAT/DEFEAT, no DISSOLVED enum).
  Mixed-but-trending-positive evidence. Pattern *selection* origination is the next edge.
- Session ran over the 2-hour target again — conversation spanned three calendar days
  (2026-06-23 → 2026-06-25). User engagement stayed high and cognitive load did not break down.
  S4 carry-forward note about "hard 2-hour stop" is now twice violated. Either accept that
  sessions are 2.5–3 hours for this user or be stricter in S6.
- Typed-array gotcha was handled inline in <2 min. Good discipline relative to S4's
  Camera2D/Label rabbit holes.

**User's Self-Assessment (verbatim):**
"I think i'm in a good state, how the army works is clear and i felt confident coding each part. I think i'm still working at being able to come up with the architecture, the vision and game plan myself but i'm feeling adept at filling out the smaller portions especially when the scaffolding is in place. I know the patterns but i'm not as confident using them beyond a mechanical "oh a state machine is probably good here" which makes me afraid that i'll slip into messy code practice. Overall good though"

---

### Session 4
**Date:** 2026-06-22
**Status:** Complete

**Tasks completed:**
- `Command` marker base class (`res://scripts/commands/command.gd`) carrying the shared
  `issuer_player_id: String` field. `MoveArmyCommand` (`move_army_command.gd`) extends it as
  pure data — `from_territory`, `to_territory`, `composition`. Anemic-command flavor; no
  `execute()` method.
- `CommandBus.submit(command: Command)` implemented as the routing chokepoint. Dispatches on
  type via `is`, asks `GameSimulation.is_move_legal(command)`, hands legal commands to
  `GameSimulation.apply(command)`. Two distinct warning paths: unknown command type vs.
  known-but-illegal. Early `return` on unknown to prevent double-warn.
- `GameSimulation` got real state: `territory_owner`, `territory_garrison` dicts, plus a
  `territories` lookup cache for `TerritoryData` (derived — annotated as such). Constants
  for player IDs, troop types. `is_move_legal` checks existence, ownership against issuer,
  `from != to`, composition is achievable from garrison. `_apply_move_army` deducts
  composition from source garrison and emits `garrison_changed`. Production `Timer`
  configured and started in `initialize`; ticks each `PRODUCTION_TICK_INTERVAL` and grows
  every territory's garrison by `base_production`.
- Lifecycle inverted: `GameSimulation._ready` no longer self-bootstraps. Exposes
  `initialize(map_data)` instead. New `res://scripts/main.gd` orchestrates the boot — calls
  `map_renderer.initialize(map)` first (so the renderer subscribes before producer emits),
  then `GameSimulation.initialize(map)`. Same shape applied to `MapRenderer`: `@export var
  map_data` removed, replaced with `initialize(data)`. `Main` is now the single source of
  truth for "which map is loaded."
- `TerritoryNode` refactored to centroid-based positioning: each node's `position` is the
  centroid of its polygon; vertices stored in local space. Children at local (0,0) live at
  the territory's true world center. Added `title_label` for the display name.
- `EventBus.garrison_changed` signal payload upgraded from `int` to `Dictionary[String,int]`
  (composition). `MapRenderer._garrison_changed_handler` sums for display.
- `dev_keys.gd` gained `KEY_4`: issues a real `MoveArmyCommand` through `CommandBus.submit(...)`.
  End-to-end proof of pipeline — issuer → bus → validation → sim → garrison deduction →
  signal → renderer label decrement.
- Design Decisions Log updated in `rts-game-design.md`: neutral territories produce.

**Concepts taught:**
- **Command pattern**, named formally and applied. The user's "fireworks" intuition from
  Session 1 was paid in full. Distinct from the previous flavor (self-executing commands)
  by name and rationale — we chose **anemic command + external executor** because mutation
  requires access to private simulation state.
- **Commands are data, not method calls.** The single mechanical fact that buys serialization,
  validation, queueing, logging, replay, undo, and network broadcast. Emphasized as the
  load-bearing claim of the pattern.
- **Cross-cutting concerns** as the formal name for what the bus centralizes (validation,
  logging, broadcast, anti-cheat). One chokepoint, one place to add concerns.
- **Phase 6 networking story made concrete:** server-authoritative, why commands sail over
  the wire as JSON, why `CommandBus.submit()` is the *one* file that gets wrapped, why every
  other system is unchanged. Used as the killer justification for the pattern.
- **Resource vs. plain class (RefCounted)**: content vs. events. Resources for things that
  exist before runtime, persist on disk, are designer-tunable. Plain classes for transient
  runtime events. Commands are events → RefCounted. The shared-reference gotcha with
  Resources mentioned (would require `.duplicate()` everywhere).
- **Read/write split on `GameSimulation`**: many read methods (`get_territory_owner`,
  `get_garrison`, `is_move_legal`), exactly one write entry point (`apply`). Discipline
  not enforcement.
- **Inversion of Control / Hollywood Principle**: "don't call us, we'll call you." Systems
  don't decide when to boot; an orchestrator tells them. Connected back to Session 1's data
  vs. state separation and Session 3's system independence — same shape, different layer.
- **Bootstrap pull vs. ongoing push** (clarification of Session 3's push-not-pull rule):
  bootstrap reads are a one-time "where am I in the world?" query that uses the existing
  read interface. Doesn't violate push-not-pull, which is about *ongoing* signal payloads.
- **Local vs. world coordinates and the semantic meaning of `node.position`** in Godot. The
  principle: a node's position should *mean* something. Children at local coords, parents
  own world position. TerritoryNode positioned at centroid, vertices in local space.
- **Bottom-up `_ready` order** in the scene tree — children's `_ready` runs before parents'.
  This is why @export-based wiring "just works" while code-based wiring needs an
  orchestrator that runs at the right level.
- **Autoload init order vs scene tree init order** — autoloads `_ready` runs *before* any
  scene node `_ready`. Root cause of the bootstrap bug the user diagnosed.
- **Bulk-signal anti-pattern at the local layer** — performance perf-anxiety drove the user
  to suggest bulking signals; the real fix lives at the network layer, not the local one.
  Granular events locally + batched snapshots at the network layer is the standard pattern.
- **Anatomic Godot gotchas as they arose**: `Camera2D.zoom` semantics, `Label` anchors at
  top-left not center, `push_warning` takes a single string not format args, autoloads
  cannot use `@export` (no scene file to bind to — use `preload` or `initialize`).

**Claude observations:**
- User's Session 1 "fireworks" intuition about CommandBus came back online immediately when
  asked. Listed five specific problems with direct calls including the multiplayer instinct.
  Very strong opening.
- Knowledge gap on game networking paradigms admitted honestly when pushed on multiplayer.
  After a short explainer on server-authoritative architecture, they connected it back to
  their existing decoupling intuition without further prompting. Good gap-closing reflex.
- A/B/C decision style: when given multiple options with tradeoffs (Resource vs. RefCounted
  vs. Dictionary; flat dispatch vs. match vs. lookup table; preload vs. load vs. initialize),
  the user reasoned aloud and frequently self-corrected mid-thought. They went Dict →
  Resource → RefCounted on the command type and found the right answer themselves with
  Socratic nudges.
- Pushback on "preload locks us to one map" was the highest-quality independent architectural
  call this session. Led directly to the orchestrator refactor for both `GameSimulation`
  and `MapRenderer`. Self-driven generalization.
- The bulk-vs-granular signal debate showed an emerging *engineering* instinct (perf) that
  was applied at the wrong layer. After the network-batching explanation, the user accepted
  the answer cleanly. Worth tracking — this is the kind of intuition that's right at scale
  but needs calibration for *where* in the stack it applies.
- Inversion of control: the user *arrived at* the orchestrator pattern spontaneously when
  the bootstrap bug hit (suggested both `call_deferred` and "a more meta game manager"). When
  asked to name the principle, they said "I'm not sure" — strong evidence of intuiting
  without language. Worth retesting in Session 5 (state machines) and Session 6 (Strategy)
  whether they can predict patterns *before* I name them.
- Implementation bugs in `GameSimulation`: `base_production` field access (read whole
  TerritoryData instead of the int field — pure crash), Timer never created (feature dead
  silent), `push_warning` format args (Godot API misunderstanding). All caught via review.
  These are exactly the kind of "first encounter with API surface" issues the teaching
  guide says should go to a throwaway session; we handled them inline today. Worth being
  stricter next time.
- The centroid loop bug was a beautiful logic error — division *inside* the loop produced a
  geometric series biased toward the last point, not the average. The polygon-position
  cancellation that hid it from the polygon rendering while exposing it on labels is a
  great debugging principle ("when only some children show a bug, the parent transform is
  probably wrong and the others mask it via accidental cancellation"). Surfaced in passing.
- Late-session diversion into `Camera2D.zoom`, Label rendering, and Project Settings stretch
  modes pulled us off the architectural arc. The session ran ~30 minutes longer than the
  target 2 hours as a result. Note for Session 5: be stricter about deflecting Godot config
  questions to throwaway sessions per the teaching guide.
- End-of-session reflection was good but visibly tired. User noted "it is a lot to digest at
  once" — acknowledge this in Session 5's opening by lowering the cognitive load on the
  Concept phase. Don't pile on state-machine theory before checking what stuck from today.
- The user has been doing the "explain it back to a teammate" exercise well. The Command
  pattern back-explanation was tight and correct on the load-bearing pieces. The "what
  changes in Phase 6" answer correctly identified the bus + event broadcasting as the
  flexion points.

**User's Self-Assessment (verbatim):**
"I think most of the session clicked the command bus is a powerful pattern for organizing state change and there was a wide breadth of changes across the codebase that we touched to clean the project up progressively and encourage good architecture. Nothing's immediately fuzzy but it is a lot to digest at once."

---

### Session 6
**Date:** 2026-06-25 → 2026-06-28 (multi-day, continued cadence)
**Status:** Complete

**Tasks completed:**
- `CombatResolver` base class (`res://scripts/combat/combat_resolver.gd`) with three inner
  data carriers (`TerritoryFight`, `CombatContext`, `CombatResult` with `Outcome` enum
  WIN/RETREAT/DEFEAT). Abstract Strategy contract: `resolve_combat(context) -> result`.
- `AttritionCombatResolver` (`res://scripts/combat/attrition_combat_resolver.gd`) — 4-case
  binary 1:1 attrition. Verified end-to-end via dev key 4 (territory conquest succeeds with
  enough troops, fails with too few; garrison + ownership signals fire correctly).
- `GameSimulation` integration layer: `_combat_resolver` field, `initialize(map, resolver)`
  signature (IoC continued from S4), `_apply_combat_result(ctx, result)` two-pass integrator
  (process per-army outcomes, then apply winner side-effects branched by territory vs edge).
  Territory WIN updates ownership + garrison + dissolves attacker; territory DEFEAT preserves
  defender garrison from result + dissolves attacker; edge WIN updates winning army's
  composition in place.
- En-route collision detection in `_process`: edge-grouping by canonical `_edge_key`,
  canonical-position projection (`_canonical_position` maps progress to `[0,1]` in
  alphabetical direction), `_find_collided_army` checks opposite-direction crossings.
  Collect-then-process (S5 pattern) into `collision_events`; cascade-skip during processing
  handles "passes two armies in one frame."
- Friendly merging (`_merge_armies`): smaller dissolves into larger; larger keeps its
  destination. Shared lifecycle primitive with `_dissolve_army_into_garrison`.
- `main.gd` constructs `AttritionCombatResolver` at boot and passes to `GameSimulation.initialize`.
- Design Decisions Log updated in `rts-game-design.md` (7 new entries — see log).
- Known bug filed for S7 throwaway: `_find_collided_army` field-name typo
  (`edge_obj.is_reversed` should be `edge_obj.reversed`).

**Concepts taught:**
- **Strategy pattern**, formally named and applied. Distinguished from inheritance alone by
  the load-bearing piece: **the consumer's structural blindness to which concrete subclass it
  holds**. `if _combat_resolver is AttritionCombatResolver` would defeat the pattern entirely.
- **The two-axis disambiguation in S6 setup.** User's Q2 sketch was a registry-based design
  answering "Axis B: instantaneous vs sustained combat" (the deferred S3 question). Today's
  job was "Axis A: swappable combat math." Reframing was a clean intervention — user re-sketched
  the function-call shape correctly afterward.
- **Three-layer combat architecture**: orchestrator (GameSimulation `_on_army_arrived_at_hop`)
  / integrator (`_apply_combat_result`) / pure resolver (`CombatResolver`). Pure resolver is
  data→data with no world knowledge. Integrator translates result into world-state mutations
  and emits signals. Orchestrator decides when to call.
- **Dependency Inversion as the unifying principle** behind EventBus/CommandBus/CombatResolver.
  In all three the consumer depends on a *contract*, not a concrete producer. Each contract is
  a stable boundary either side can evolve behind. The "D" in SOLID.
- **Open/Closed Principle (S3 callback)** applied concretely: new combat math = new resolver
  subclass; AttritionCombatResolver untouched. GameSim's call site never changes.
- **Per-participant outcome granularity** for multi-party shape. `outcomes_by_army_id:
  Dictionary` rather than a single per-combat outcome — generalizes to N-way combat without a
  signature break.
- **Forward-compat at interface boundaries, not implementations.** Interface forward-compat is
  cheap (just type `armies: Array[Army]` instead of `attacker, defender`); behavior forward-compat
  is YAGNI (don't write multi-party resolution math when nobody calls it that way). Invest in
  interfaces; let implementations be exactly as ambitious as today's problem demands.
- **Subsystem extraction criterion** (user-articulated unprompted in R3): "does this subsystem
  have a stable, expressible interface?" `CombatResolver`'s yes. Collision detection's *probably*.
  Army movement's no (the "interface" is just "advance progress" — not much to abstract).
- **Crossing-detection vs same-edge-presence** for edge combat. Design doc said "on same edge →
  collide"; user upgraded the spec to "collide when they meet" via canonical-position projection.
  Better game-feel; spec-improvement origination.
- **Canonical-position projection**: `_edge_key(edge)` returns lexicographic min->max form;
  `_canonical_position(army)` returns `progress` if forward, else `1 - progress`. Two armies on
  same edge are sortable on a shared `[0,1]` number line; head-on collision fires when
  forward.canon >= backward.canon. Phase-1 simplification: uniform speed means same-direction
  armies never close gap, so only opposite-direction pairs can cross.
- **Cascade-skip pattern** for multi-collision safety: process collision events in collection
  order; if a participant was destroyed in an earlier event, skip the later event. Same shape
  as the filed multi-party-arrival sequential resolution (option a).
- **Garrison retreat as MoveArmyCommand variant** — user-originated reframing: retreat is not
  a special combat primitive but a Command issued mid-fight with "destination ≠ attacker's
  source edge" constraint. Unifies retreat under the existing Command-pattern infrastructure
  instead of bolting on special-case combat-layer logic. Filed as Phase 2/3 design intent.
- **Signal granularity revisited**: `army_composition_changed` would be a value-update signal
  (S3 anti-pattern). The right signal — when reactive consumers appear — is
  `combat_resolved(ctx, result)`: an event with rich payload. Phase 1 has no reactive
  consumer, so no signal added. Reinforced the S3 push-rich-payload rule.

**Claude observations:**
- **Pattern-selection origination edge progressed materially.** Going into S6 (per S5
  carry-forward) the open question was: can the user *name* a pattern from the problem alone,
  not just recognize it after introduction? Mixed-positive evidence:
  - Q2 sketch was the registry-based design — solving Axis B (sustained combat) instead of
    Axis A (swappable math). Showed independent design thinking but with axis confusion;
    didn't name Strategy.
  - After Axis A/B reframe, user re-sketched the function-call shape correctly: "one method,
    give me two compositions, return winner + remaining." That's Strategy without needing
    the name. Recognition without naming.
  - When asked Q1 explicitly ("does this remind you of anything?"), user said no. Strategy
    was named *by Claude*. Recognition gap remains.
  - **However:** user *originated* the CombatContext shape genericization (no attacker/defender
    perspective; `armies: Array[Army]` multi-party-shaped). Filed as real pattern-selection
    origination. The interface they sketched is forward-compatible to option-b multi-party
    without us having decided to build it.
  - User *also originated* the garrison-retreat-as-MoveArmyCommand reframing — recognizing
    retreat is a Command-layer concern, not a combat-layer primitive. Genuine design insight,
    unifies retreat with existing architecture instead of bolting on.
  - User *also originated* the subsystem-extraction criterion in R3 ("does this subsystem
    have a stable, expressible interface?") — articulated unprompted. This is engineering
    judgment, not pattern recall.
  - Diagnostic for S7+: pattern *names* still lag pattern *application*. User can sketch
    correct shapes and reason about tradeoffs but doesn't always know the textbook name.
    Probably worth a low-key "have you encountered X before?" at each Concept opening
    (worked well in S5 for State Machine, and revealed prior Strategy exposure today even
    though the recall was incomplete).
- **Multi-day session cadence continued** (S6 spanned 2026-06-25 → 2026-06-28, four calendar
  days). Engagement stayed high throughout. Cognitive load did not break down. Per S5 carry-
  forward this is fine and shouldn't be optimized away.
- **The Category A vs Category B bug categorization** (Claude-introduced this session)
  landed well as a teaching tool. User took syntax/typo bugs to throwaway sessions and
  brought logical/design bugs back to the teaching session. Good calibration; worth reusing.
- **"Take a swing then we'll review" rhythm** worked well throughout. User implements with
  confidence, accepts critique, iterates cleanly. No need to scaffold more skeletal stubs
  than was done; user does fine with `# TODO: implement` markers.
- **R4 self-critique was sharp** ("I didn't know how to visualize it"). User is recognizing
  where their architectural intuition runs out — exactly the meta-awareness needed to grow
  past it. Worth a follow-up technique in S7+: when extraction or generalization is on the
  table, ask "describe what the API would look like for a user of this thing" — forces the
  abstraction to be concrete before commitment.
- **One real lingering bug** (`edge_obj.is_reversed` vs `.reversed`) made it past review
  because user said "I've implemented what i think is everything left" but multi-army
  end-to-end test was not yet run. Note for S7: explicitly request "run dev key 4 with
  multi-army setup" *before* claiming en-route combat done. The unverified-by-test gap was
  the only soft spot in the implementation pass today.
- **The user's "tenability of large files" worry** is now twice-flagged across S5 and S6.
  CombatResolver extraction partially addresses it (and user articulated this themselves).
  Collision detection is the next plausible extraction candidate. Watch for it in S7/S8 —
  if `GameSimulation` keeps growing, propose extracting collision detection as
  `EdgeCollisionDetector` with `find_collisions(armies) -> Array[CollisionEvent]` as the
  shape the user already sketched mentally.

**User's Self-Assessment (verbatim):**
"I feel good, not fuzzy about the concepts covered today but i will just reiterate my nervousness about the tenability of large files and organization of logic. Ultimately our broad arch looks good though. It took a me a while to work through some of these bits of logic which is good practice for me, but taking time"

---

## Carry-Forward Notes

**User trajectory (long-running):**
- **Pattern naming lags pattern application.** S6 reinforced the S5 read: user sketches
  correct architectural shapes and reasons crisply about tradeoffs but doesn't always know
  the textbook name when asked. Strategy pattern: when Claude asked "does this remind you
  of anything?" user said no — but had already sketched the function-call-through-base-ref
  shape correctly. **Diagnostic for S7+:** low-key disclosure question at each Concept
  opening ("have you encountered X before?") — worked well for State Machine in S5 and
  revealed partial Strategy exposure in S6. Costs nothing; calibrates depth.
- **Pattern-selection origination edge** is genuinely progressing. S6 evidence: user
  originated (a) the perspectiveless CombatContext / per-army outcomes shape that's
  multi-party-compatible by signature, (b) the garrison-retreat-as-MoveArmyCommand reframe
  unifying retreat under the Command pattern, (c) the subsystem-extraction criterion
  unprompted in R3. The trend bends upward.
- **Verification gap before claiming done.** S6 had one bug make it past review because user
  said "implemented what i think is everything" without running the multi-army end-to-end
  case. **Diagnostic for S7+:** explicitly request "run dev key 4 with the multi-army setup"
  before accepting "done." Trust *with* verification.
- **Subsystem extraction is now an active toolkit move**, not a deferred concern. User
  *articulated the criterion themselves* in S6 R3 ("does this subsystem have a stable,
  expressible interface?"). Apply this lens proactively in S7+: when `GameSimulation` grows
  further, propose extracting collision detection as `EdgeCollisionDetector` with
  `find_collisions(armies) -> Array[CollisionEvent]` as the signature the user already has
  in their head.

**Session 7 hooks (concrete to-dos for next session):**
- **FIRST: throwaway fix of the `_find_collided_army` field-name bug** (game_simulation.gd
  lines 261-262: `edge_obj.is_reversed` should be `edge_obj.reversed` to match the dict key
  stored at line 70). Verify with multi-army head-on test (one human army from
  `rivermouth_0_2`, one AI army from a position on the same edge in the opposite direction —
  watch them meet mid-edge and resolve via `_resolve_edge_collision` → combat or merge as
  appropriate).
- **Then S7 main arc: Retreat + Conquest cooldown.** Per design doc:
  - Phase 1 retreat: automatic `ArmyState` transition for the loser of a *head-on* edge
    collision (legal only when met head-on; illegal when caught from behind — Phase 1's
    uniform speed means same-direction overtake doesn't happen, so all edge collisions are
    head-on and retreat eligibility is universal for now).
  - Phase 1 retreat ≠ Phase 2/3 retreat. S6 reframe (filed in Open Questions): long-term,
    retreat is a Command-layer concern (player issues `RetreatCommand` mid-fight, garrison
    retreat is a constrained `MoveArmyCommand`). Phase 1's instant resolution doesn't have
    a "during fight" moment, so it collapses to a state-machine transition. Implement
    the Phase 1 form; flag the Phase 2/3 reframe in comments at the retreat call site so
    we know where to come back.
  - Conquest cooldown: when a territory is captured, set a cooldown timer (e.g. 10s). During
    cooldown, production tick *skips* this territory. Stub-level: a `_cooldown_remaining`
    field on the `Territory`-as-state-dict pattern, decremented each tick. The proper
    `ConquestCooldownModifier` Resource (per design doc Phase 3 modifier-chain pattern)
    lives in Phase 3.
- **Watch the file-size lens.** If `GameSimulation` crosses ~400 lines or collision logic
  grows significantly, propose collision detection extraction with the API the user already
  has in their head (matches their R3 articulation).
- **Phase 1 retreat raises a real design question deferred from S5:** does a retreating army
  that wins an interception resume retreating or resume original mission? S5 decision said
  "resume retreating, not mission." Verify this is still the call when implementing.

**Open Question for Phase 2/3 (raised in S6):**
- Garrison retreat as `MoveArmyCommand` variant. User-originated reframing: garrison can
  decline defense by departing as a new army to an adjacent friendly territory. Mechanically
  a constrained move ("destination ≠ attacker's source edge"). Defer until Phase 2/3 when
  buildings/fortifications make "stand and die vs fall back" a more interesting choice.

**Long-horizon flags:**
- **Session cadence.** User confirmed multi-day session spans (S5 ran across three calendar
  days) are driven by real-world scheduling, not by concept-saturation. Don't optimize for
  shorter sessions or push to finish in one sitting — the split cadence is fine. Continue to
  deflect Godot-API questions to throwaway sessions per teaching guide; that's the only
  session-length lever worth pulling.
- **Dev-keys pattern is now in the toolkit.** Reuse for future systems that need standalone
  verification before producers exist (ArmyRenderer before movement existed in S5 — could
  have used this; instead we relied on garrison labels + console). Worth using more
  proactively in S6+ for combat visualization.
- **`dev_keys.gd` must be removed or gated before Phase 6.** It can fake any EventBus signal.
  Either delete or hard-gate on `OS.is_debug_build()`. Flag when crossing Phase 6.
- **State Pattern not yet earned.** Army state machine uses enum + const dict. If a future
  entity has rich per-state behavior (Garrison with Idle/Fortifying/Recruiting modes,
  Generals with morale states), revisit and use State Pattern. The criterion is in S5
  concept notes.

---

## Open Questions / Deferred Decisions

- **Sustained vs. instantaneous battles** (raised Session 3). Current design has combat
  resolve in one `CombatResolver.resolve()` call. User flagged that sustained, tickable
  engagements would give players time to react and commit reinforcements mid-fight —
  more interesting at the war/scale of this game. Architecturally cheap to swap later
  (Strategy pattern handles it: new `SustainedCombatResolver` subclass, no consumer
  changes — confirmed in S6 implementation). **Decision:** keep instant resolution for
  Phase 1 to keep scope manageable; revisit during or after Phase 2 (when Generals &
  Combat Depth lands and the combat UI gets real attention). Sustained combat is also
  where the deferred *garrison retreat* and *command-driven army retreat* mechanics
  become live — they all rest on the same "during fight" temporal model.
- **Garrison retreat as `MoveArmyCommand` variant** (raised Session 6, user-originated).
  Garrison can decline defense by departing as a new army to a friendly neighbor.
  Mechanically a constrained move (destination ≠ attacker's source edge). Phase 1 has
  garrisons fighting to destruction; defer the garrison-retreat option until Phase 2/3
  when buildings/fortifications make "stand and die vs fall back" a more interesting
  strategic decision.
- **True multi-party combat resolver** (option b from S6 setup, deferred). Current Phase 1
  resolves multiple opposing arrivals at one territory sequentially-pairwise (option a;
  order-dependent acknowledged). The semantically preferred long-term form is a real N-way
  resolver taking `Array[Side]` and resolving cross-side casualty math in one pass. Defer
  until Phase 2 when generals/troop-types/modifiers force combat math to grow up anyway.
  The current `CombatResolver` interface (`armies: Array[Army]`) is already shaped for this
  expansion — only the implementation needs to change.

---

## How Claude Should Start Each Session

1. Read this file, `rts-game-design.md`, and `rts-teaching-guide.md`.
2. Greet the user, state the current task and what was done last session (one sentence each).
3. Ask if anything has changed or if they have carry-over questions before starting.
4. Follow the session structure in the teaching guide: Orient → Concept → Scaffold →
   Implement → Reflect → Wrap.
5. At session end: ask for the user's self-assessment, record it verbatim, update this file.
