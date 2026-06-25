extends Node

# --- Input layer (emitted by MapRenderer's click handler stub) ---
signal territory_clicked(territory_id: String)

# --- Simulation layer (emitted by GameSimulation, future) ---
signal territory_owner_changed(territory_id: String, new_owner_id: String)
signal garrison_changed(territory_id: String, new_composition: Dictionary)

signal army_spawned(army: Army)
signal army_dissolved(army_id: String)
signal army_advanced_hop(army: Army)   # progress reset, current_edge changed
# Note: we are NOT firing per-frame progress signals. Renderer reads army.progress
# directly each frame via _process. (Discrete-vs-continuous-state from Session 3:
# progress is the canonical "continuous state interpolated visually" case.)
