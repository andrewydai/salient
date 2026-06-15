# RTS Game — Session Brief

> **How to use this file:** Paste it (along with `rts-game-design.md` and
> `rts-teaching-guide.md`) at the start of any new Claude session. Claude updates this file
> at the end of every session. The user adds their self-assessment verbally; Claude records it.

---

## Current State

- **Phase:** 1 — Core Game Loop
- **Session Number:** 1 (complete)
- **Current Task:** Ready to begin Session 2
- **Next Session Goal:** Territory rendering — hand-craft `MapData` resource (15 territories),
  `Polygon2D` + `CollisionPolygon2D`, `MapRenderer` reads `MapData`, `TerritoryGraph` adjacency list

---

## What Exists

- `rts-game-design.md` — complete design spec with all Phase 1 decisions settled
- `rts-teaching-guide.md` — teaching curriculum
- `rts-session-brief.md` — this file
- Godot 4.6 project at `res://`
  - Folder structure: `autoloads/`, `resources/`, `scenes/`, `scripts/`, `assets/`
  - Autoloads registered: `GameSimulation`, `CommandBus`, `EventBus`, `ThemeManager`
    (all at `res://autoloads/*.gd`, all empty `extends Node` stubs)
  - `res://resources/territory_data.gd` — `TerritoryData` Resource schema
  - `res://resources/map_data.gd` — `MapData` Resource schema
  - `res://scenes/main.tscn` — base Main scene (Node2D root, no children yet)

---

## Phase 1 Task Checklist

### Foundation
- [x] Project setup: folder structure, Autoloads registered, base scenes
- [x] `TerritoryData` and `MapData` resources defined
- [ ] Hand-craft test map (15 territories)

### Map & Graph
- [ ] Territory rendering: `Polygon2D` + `CollisionPolygon2D` + click detection
- [ ] `TerritoryGraph`: adjacency list, BFS pathfinding

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

## Carry-Forward Notes

- **Resources vs. plain classes:** User is fuzzy on why Godot enforces the Resource/Node distinction when Python doesn't. The engine infrastructure (serialization, inspector, reference counting) is the answer — but it will land more concretely in Session 2 when they hand-author territory data in the inspector and see the `.tres` machinery work. Revisit then.
- **`extends Resource` muscle memory:** User defaulted to `extends Node` twice. Flag gently on any new Resource scripts in future sessions.
- **Command pattern intuition is strong:** User independently articulated the Command pattern rationale. In Session 4, remind them they had this insight in Session 1 before naming it.

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
