extends Node

# --- Input layer (emitted by MapRenderer's click handler stub) ---
signal territory_clicked(territory_id: String)

# --- Simulation layer (emitted by GameSimulation, future) ---
signal territory_owner_changed(territory_id: String, new_owner_id: String)
signal garrison_changed(territory_id: String, new_composition: Dictionary)
