extends Node

const PRODUCTION_TICK_INTERVAL: float = 5.0
const PLAYER_ID_HUMAN: String = "player_1"
const PLAYER_ID_AI: String = "player_2"
const TROOP_TYPE_INFANTRY: String = "infantry"
const PLAYER_ID_NEUTRAL: String = "neutral"

# Cache: derived from map_data.territories for O(1) lookup. Rebuild if map_data changes.
var territories : Dictionary = {} # territory_id -> TerritoryData

# State — the authoritative model.
var territory_owner: Dictionary = {} # territory_id -> player_id
var territory_garrison: Dictionary = {}  # territory_id -> Dictionary[troop_type_id, count]

# Production tick driver.
var _production_timer: Timer

func initialize(map_data: MapData) -> void:
	for territory in map_data.territories:
		var init_owner: String = map_data.starting_positions.get(territory.id, PLAYER_ID_NEUTRAL)
		territories[territory.id] = territory
		territory_owner[territory.id] = init_owner
		territory_garrison[territory.id] = {
			TROOP_TYPE_INFANTRY: 1
		}
		EventBus.territory_owner_changed.emit(territory.id, init_owner)
		EventBus.garrison_changed.emit(territory.id, territory_garrison[territory.id])
	
	_production_timer = Timer.new()
	_production_timer.wait_time = PRODUCTION_TICK_INTERVAL
	_production_timer.timeout.connect(_on_production_tick)
	add_child(_production_timer)
	_production_timer.start()

# --- Command application (called only by CommandBus) ---

func apply(command: Command) -> void:
	if command is MoveArmyCommand:
		_apply_move_army(command)

# --- Read-only queries ---

func get_territory_owner(territory_id: String) -> String:
	return territory_owner.get(territory_id, null)

func get_garrison(territory_id: String) -> Dictionary:
	return territory_garrison.get(territory_id, null)

func is_move_legal(command: MoveArmyCommand) -> bool:
	var cur_territory_owner = get_territory_owner(command.from_territory)
	var cur_territory_garrison = get_garrison(command.from_territory)
	
	if cur_territory_owner == null or cur_territory_garrison == null:
		push_warning("from_territory %s must be in both territory_owner and territory_garrison" % [command.from_territory])
		return false
	if territories.get(command.to_territory, null) == null:
		push_warning("to_territory %s must be a valid territory" % [command.to_territory])
		return false
	if cur_territory_owner != command.issuer_player_id:
		push_warning("from_territory %s must be owned", [command.from_territory])
		return false
	if command.from_territory == command.to_territory:
		push_warning("from_territory %s must not be the same as to_territory" % [command.from_territory])
		return false
		
	for troop_type in command.composition.keys():
		var amount = command.composition[troop_type]
		if cur_territory_garrison.get(troop_type, 0) < amount:
			push_warning("from_territory %s has too few of troop type %s" % [command.from_territory, troop_type])
			return false
		
	# (Session 5 will add: path exists)
	return true

# --- Mutations (private by convention) ---

func _apply_move_army(command: MoveArmyCommand) -> void:
	# assume operation is valid
	var cur_territory_garrison = get_garrison(command.from_territory)
	var next_garrison = cur_territory_garrison.duplicate()
	for troop_type in command.composition.keys():
		var amount = command.composition[troop_type]
		next_garrison[troop_type] -= amount
	territory_garrison[command.from_territory] = next_garrison
	EventBus.garrison_changed.emit(command.from_territory, next_garrison)
	# Session 5: spawn an Army entity and start it pathing.

# --- Production tick ---

func _on_production_tick() -> void:
	# For each territory, increment garrison by base_production (default infantry).
	for territory_id in territory_garrison.keys():
		var next_garrison = get_garrison(territory_id).duplicate()
		var base_production = territories[territory_id].base_production
		next_garrison[TROOP_TYPE_INFANTRY] += base_production
		territory_garrison[territory_id] = next_garrison
		EventBus.garrison_changed.emit(territory_id, next_garrison)
