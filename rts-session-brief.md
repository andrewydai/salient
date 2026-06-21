# RTS Game — Session Brief

> **How to use this file:** Paste it (along with `rts-game-design.md` and
> `rts-teaching-guide.md`) at the start of any new Claude session. Claude updates this file
> at the end of every session. The user adds their self-assessment verbally; Claude records it.

---

## Current State

- **Phase:** 1 — Core Game Loop
- **Session Number:** 3 (complete)
- **Current Task:** Ready to begin Session 4
- **Next Session Goal:** CommandBus, GameSimulation & the Command pattern — wire up CommandBus
  as the chokepoint for all state mutations, give GameSimulation real territory ownership and
  garrison state, introduce `MoveArmyCommand` as a data object (no execution yet). The signals
  declared today (`territory_owner_changed`, `garrison_changed`) start firing for real reasons.

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
    `@export`, instantiates a `TerritoryNode` per territory and stores them in
    `territories_by_id: Dictionary`. Subscribes to `EventBus.territory_owner_changed` and
    `EventBus.garrison_changed`; dispatches to the corresponding `TerritoryNode` by ID.
    `_on_territory_input` emits `EventBus.territory_clicked(territory_id)`.
  - `res://scripts/territory_node.gd` — `TerritoryNode` class (`extends Area2D`). Owns its
    own `Polygon2D`, `CollisionPolygon2D`, and `Label` children. Exposes a small intentional
    API: `setup(data)`, `set_owner_color(color)`, `set_garrison_count(n)`. Encapsulates
    per-territory visual state so handlers never reach inside.
  - `res://scripts/territory_graph.gd` — `TerritoryGraph` plain class (`RefCounted`). Methods:
    `build(map_data)`, `get_neighbors(id)`, `find_path(from, to)` (BFS with `came_from` path
    reconstruction). Not yet instantiated or owned by any system.
  - `res://scripts/dev_keys.gd` — debug-only script attached to `Main`. On key press, emits
    EventBus signals directly to prove the renderer reacts without any other system running.
    Keys 1/2 fire `territory_owner_changed`; key 3 fires `garrison_changed`.
  - `res://autoloads/event_bus.gd` — declares three signals: `territory_clicked(String)`,
    `territory_owner_changed(String, String)`, `garrison_changed(String, int)`. All typed.
  - `res://scenes/main.tscn` — Main scene with `MapRenderer` and `dev_keys.gd` as children,
    `map_data.tres` assigned to `MapRenderer.map_data`

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
- [~] `CommandBus` and `EventBus` autoloads wired up
      (EventBus wired with 3 signals; `MapRenderer` subscribes; `dev_keys.gd` proves emission.
      CommandBus still an empty stub — Session 4.)
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
- **Strong reflection muscle (new, Session 3):** User's end-of-session reflection was
  unprompted and accurate. Already named the Observer pattern, OCP, and system independence
  via interface mediation without being asked to. The Session 2 worry about "originating
  architecture vs. recognizing it" is showing real progress. By Session 6 (Strategy),
  start asking them to *predict* the pattern from the problem rather than name it after
  the fact — they may be ready for that test.
- **Continuous-state-via-prediction is loaded into context (new, Session 3):** Session 5
  (Army movement) will hit this directly. User has the mental model — `Army.progress` is
  visual-only, renderer interpolates from sparse signals using its own clock. Recall this
  framing in Session 5 when implementing `_process(delta)` on the army movement loop.
  Same framing reappears in Session 10 for `VisibilitySystem` (derived state).
- **Dev-keys pattern is now in the toolkit:** When future systems need standalone
  verification before their upstream producers exist (e.g., HUD before selection state,
  ArmyRenderer before army movement), the dev-keys pattern is the right tool. Reuse it.
- **`dev_keys.gd` should be removed (or gated) before Phase 6:** Right now it can fake any
  EventBus signal. Fine for development; not fine if it ships. Either delete it before
  release or hard-gate it on `OS.is_debug_build()`. Flag this when we cross Phase 6.
- **Minor cleanup:** `territory_node.gd:24` has a stray tab between `polygon_2d.` and
  `color`. Cosmetic only; runs correctly. Mention if visiting that file again.

---

## Open Questions / Deferred Decisions

- **Sustained vs. instantaneous battles** (raised Session 3). Current design has combat
  resolve in one `CombatResolver.resolve()` call. User flagged that sustained, tickable
  engagements would give players time to react and commit reinforcements mid-fight —
  more interesting at the war/scale of this game. Architecturally cheap to swap later
  (Strategy pattern handles it: new `SustainedCombatResolver` subclass, no consumer
  changes). **Decision:** keep instant resolution for Phase 1 to keep scope manageable;
  revisit during or after Phase 2 (when Generals & Combat Depth lands and the combat
  UI gets real attention).

---

## How Claude Should Start Each Session

1. Read this file, `rts-game-design.md`, and `rts-teaching-guide.md`.
2. Greet the user, state the current task and what was done last session (one sentence each).
3. Ask if anything has changed or if they have carry-over questions before starting.
4. Follow the session structure in the teaching guide: Orient → Concept → Scaffold →
   Implement → Reflect → Wrap.
5. At session end: ask for the user's self-assessment, record it verbatim, update this file.
