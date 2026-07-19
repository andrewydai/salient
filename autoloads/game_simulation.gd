extends Node

# constants
const CONQUEST_COOLDOWN: float = 10.0
const PRODUCTION_TICK_INTERVAL: float = 5.0
const PLAYER_ID_HUMAN: String = "player_1"
const PLAYER_ID_AI: String = "player_2"
const TROOP_TYPE_INFANTRY: String = "infantry"
const PLAYER_ID_NEUTRAL: String = "neutral"
const ARMY_MOVE_SPEED: float = 0.5

var _combat_resolver: CombatResolver

# Cache: derived from map_data.territories for O(1) lookup. Rebuild if map_data changes.
var territories : Dictionary = {} # territory_id -> TerritoryData

# State — the authoritative model.
var territory_owner: Dictionary = {} # territory_id -> player_id
var territory_garrison: Dictionary = {}  # territory_id -> Dictionary[troop_type_id, count]
var armies: Dictionary = {}    # army_id -> Army
var _next_army_id: int = 0
var _territory_graph: TerritoryGraph    # built in initialize()
var territory_conquest_cooldown: Dictionary = {} # territory_id -> float

# Production tick driver.
var _production_timer: Timer

func initialize(map_data: MapData, combat_resolver: CombatResolver) -> void:
	for territory in map_data.territories:
		var init_owner: String = map_data.starting_positions.get(territory.id, PLAYER_ID_NEUTRAL)
		territories[territory.id] = territory
		territory_owner[territory.id] = init_owner
		territory_garrison[territory.id] = {
			TROOP_TYPE_INFANTRY: 5 if territory.id in map_data.starting_positions.keys() else 1
		}
		EventBus.territory_owner_changed.emit(territory.id, init_owner)
		EventBus.garrison_changed.emit(territory.id, territory_garrison[territory.id])
	
	_production_timer = Timer.new()
	_production_timer.wait_time = PRODUCTION_TICK_INTERVAL
	_production_timer.timeout.connect(_on_production_tick)
	add_child(_production_timer)
	_production_timer.start()
	
	_territory_graph = TerritoryGraph.new()
	_territory_graph.build(map_data)
	
	_combat_resolver = combat_resolver

# --- Simulation logic (actively running processes) ---
func _process(delta: float) -> void:
	var finished_territory_cooldowns = []
	for cooldown_ter_id in territory_conquest_cooldown.keys():
		var cur_cooldown = territory_conquest_cooldown[cooldown_ter_id]
		cur_cooldown -= delta
		if cur_cooldown <= 0:
			finished_territory_cooldowns.append(cooldown_ter_id)
		else:
			territory_conquest_cooldown[cooldown_ter_id] = cur_cooldown
	for ter_id in finished_territory_cooldowns:
		territory_conquest_cooldown.erase(ter_id)
	
	var arrived_armies: Array[Army] = []
	for army in armies.values():
		army.progress += delta * ARMY_MOVE_SPEED
		if army.progress >= 1.0:
			arrived_armies.push_back(army)
	for army in arrived_armies:
		_on_army_arrived_at_hop(army)
	
	# gather collisions
	var edge_group_dict = {}
	var collision_events = []
	for army: Army in armies.values():
		var edge_key = _edge_key(army.current_edge)
		var edge_list : Array = edge_group_dict.get(edge_key, [])
		var canon_pos = _canonical_position(army)
		var is_reversed = canon_pos != army.progress
		
		var collided_army = _find_collided_army(edge_list, canon_pos, is_reversed)
		if collided_army != null:
			collision_events.append({ 'army_1': army, 'army_2': collided_army })
		edge_list.append({ 'army': army, 'pos': canon_pos, 'is_reversed': is_reversed })
		edge_group_dict[edge_key] = edge_list # even though we're mutating initially the value is null
		
	# process collisions
	for col_event in collision_events:
		# if one of the armies is no longer there just continue
		if not armies.has(col_event.army_1.id) or not armies.has(col_event.army_2.id):
			continue
		_resolve_edge_collision(col_event.army_1, col_event.army_2)
		
		
func _resolve_edge_collision(a: Army, b: Army) -> void:
	if a.owner_id != b.owner_id:
		var ctx = CombatResolver.CombatContext.new()
		ctx.armies = [a, b] as Array[Army]
		var result = _combat_resolver.resolve_combat(ctx)
		_apply_combat_result(ctx, result)
	else:
		_merge_armies(a, b)

func _merge_armies(a: Army, b: Army) -> void:
	var larger = a if _total_troops(a) >= _total_troops(b) else b
	var smaller = b if larger == a else a
	for troop_type in smaller.composition.keys():
		larger.composition[troop_type] = larger.composition.get(troop_type, 0) + smaller.composition[troop_type]
	EventBus.army_dissolved.emit(smaller.id)
	armies.erase(smaller.id)

func _on_army_arrived_at_hop(army: Army) -> void:
	var cur_ter_id = army.current_edge[1]
	var cur_ter_owner: String = territory_owner[cur_ter_id]
	var dest_ter_id = army.path[-1]
		
	if cur_ter_owner != army.owner_id:
		var ctx = CombatResolver.CombatContext.new()
		var territory_fight = CombatResolver.TerritoryFight.new()
		territory_fight.territory_id = cur_ter_id
		territory_fight.garrison = get_garrison(cur_ter_id)
		ctx.armies = [army] as Array[Army]
		ctx.territory_fight = territory_fight
		var result = _combat_resolver.resolve_combat(ctx)
		_apply_combat_result(ctx, result)
		# if after combat the armies gone we're done
		if armies.get(army.id, null) == null:
			return
	# if the army didn't have to fight or it's still around, determine whether
	# it's where it needs to be, was retreating, or should continue
	if cur_ter_id == dest_ter_id or army.state == Army.State.RETREATING:
		_dissolve_army_into_garrison(army)
	else:
		_advance_army_to_next_hop(army)

func _dissolve_army_into_garrison(army: Army) -> void:
	var dest_territory_id: String = army.current_edge[1] # dissolves at the current arrival territory
	var next_garrison = get_garrison(dest_territory_id).duplicate()
	for troop_type in army.composition.keys():
		next_garrison[troop_type] += army.composition[troop_type]
	territory_garrison[dest_territory_id] = next_garrison
	EventBus.garrison_changed.emit(dest_territory_id, next_garrison)
	EventBus.army_dissolved.emit(army.id)
	armies.erase(army.id)

func _advance_army_to_next_hop(army: Army) -> void:	
	army.progress = 0.0
	var army_cur_ter_path_idx = army.path.find(army.current_edge[1])
	army.current_edge = [army.path[army_cur_ter_path_idx], army.path[army_cur_ter_path_idx + 1]] as Array[String]
	EventBus.army_advanced_hop.emit(army)

func _on_production_tick() -> void:
	# For each territory, increment garrison by base_production (default infantry).
	for territory_id in territory_garrison.keys():
		if territory_conquest_cooldown.has(territory_id):
			continue
		var next_garrison = get_garrison(territory_id).duplicate()
		var base_production = territories[territory_id].base_production
		next_garrison[TROOP_TYPE_INFANTRY] += base_production
		territory_garrison[territory_id] = next_garrison
		EventBus.garrison_changed.emit(territory_id, next_garrison)

# --- Command application (called only by CommandBus) ---

func apply(command: Command) -> void:
	if command is MoveArmyCommand:
		_apply_move_army(command)
	elif command is RetreatArmyCommand:
		_apply_retreat_army(command)

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
		push_warning("from_territory %s must be owned" % [command.from_territory])
		return false
	if command.from_territory == command.to_territory:
		push_warning("from_territory %s must not be the same as to_territory" % [command.from_territory])
		return false
		
	for troop_type in command.composition.keys():
		var amount = command.composition[troop_type]
		if cur_territory_garrison.get(troop_type, 0) < amount:
			push_warning("from_territory %s has too few of troop type %s" % [command.from_territory, troop_type])
			return false
		
	# new: reachability via TerritoryGraph.find_path(from, to) != null
	if _territory_graph.find_path(command.from_territory, command.to_territory).size() == 0:
		push_warning("no path from %s to %s" % [command.from_territory, command.to_territory])
		return false
		
	return true

func is_retreat_legal(command: RetreatArmyCommand) -> bool:
	var army: Army = armies.get(command.army_id, null)
	if army == null:
		push_warning("army_id %s not in armies dictionary" % [command.army_id])
		return false
	if army.owner_id != command.issuer_player_id:
		push_warning("command issuer_id %s does not match army owner_id %s" % [command.issuer_player_id, army.owner_id])
		return false
	if !army.can_transition_to(Army.State.RETREATING):
		push_warning("army.state %s not transitionable to retreating" % [army.state])
		return false
	
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

	var path : Array[String] = _territory_graph.find_path(command.from_territory, command.to_territory)
	var army = Army.new()
	army.id = str(_next_army_id)
	_next_army_id += 1
	army.composition = command.composition.duplicate()
	army.path = path
	army.current_edge = [path[0], path[1]] as Array[String]
	army.owner_id = command.issuer_player_id
	
	armies[army.id] = army
	EventBus.army_spawned.emit(army)
	
func _apply_combat_result(combat_context: CombatResolver.CombatContext, combat_result: CombatResolver.CombatResult) -> void:
	# resolve the effect on losers and retreaters, and identify the winning army
	var winning_army_id = null
	for army_id in combat_result.outcomes_by_army_id.keys():
		var army_result = combat_result.outcomes_by_army_id[army_id]
		if army_result == CombatResolver.CombatResult.Outcome.DEFEAT:
			EventBus.army_dissolved.emit(army_id)
			armies.erase(army_id)
		elif army_result == CombatResolver.CombatResult.Outcome.WIN:
			if winning_army_id != null:
				push_warning("2 combat winners detected %s %s" % [winning_army_id, army_id])
			else:
				winning_army_id = army_id

	# resolve the winner's effects and the territory if it's there
	if combat_context.territory_fight == null:
		if winning_army_id == null:
			push_warning("no winner found")
		else:
			var updated_troops = combat_result.updated_army_compositions[winning_army_id]
			var winning_army: Army = armies[winning_army_id]
			winning_army.composition = updated_troops.duplicate()
	else:
		if winning_army_id == null:
			var territory_id = combat_context.territory_fight.territory_id
			territory_garrison[territory_id] = combat_result.updated_territory_garrison.duplicate()
			EventBus.garrison_changed.emit(territory_id, territory_garrison[territory_id])
		else:
			var territory_id = combat_context.territory_fight.territory_id
			var winning_army: Army = armies[winning_army_id]
			territory_owner[territory_id] = winning_army.owner_id
			territory_garrison[territory_id] = combat_result.updated_territory_garrison.duplicate()
			EventBus.territory_owner_changed.emit(territory_id, winning_army.owner_id)
			territory_conquest_cooldown[territory_id] = CONQUEST_COOLDOWN
			EventBus.garrison_changed.emit(territory_id, territory_garrison[territory_id])
			winning_army.composition = combat_result.updated_army_compositions[winning_army.id].duplicate()
			
func _apply_retreat_army(command: RetreatArmyCommand) -> void:
	var army: Army = armies[command.army_id]
	army.current_edge = [army.current_edge[1], army.current_edge[0]] as Array[String]
	army.progress = 1.0 - army.progress
	army.state = Army.State.RETREATING
	
# --- Helpers ---
func _total_troops(army: Army) -> int:
	var sum = 0
	for troop_count in army.composition.values():
		sum += troop_count
	return sum
	
func _find_collided_army(edge_list: Array, cur_pos: float, is_reversed: bool):
	for edge_obj in edge_list:
		if (is_reversed and edge_obj.pos >= cur_pos and not edge_obj.is_reversed) \
			or (not is_reversed and edge_obj.pos <= cur_pos and edge_obj.is_reversed):
			return edge_obj.army
	return null

func _edge_key(edge: Array[String]) -> String:
	var a = edge[0]
	var b = edge[1]
	return (a + "->" + b) if a < b else (b + "->" + a)

func _canonical_position(army: Army) -> float:
	var a = army.current_edge[0]
	var b = army.current_edge[1]
	# Forward = army's current_edge[0] < current_edge[1] (alphabetical)
	return army.progress if a < b else (1.0 - army.progress)
