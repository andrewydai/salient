class_name ArmyRenderer
extends Node2D

const ARMY_NODE_SCENE := preload("res://scenes/ArmyNode.tscn")

class TrackedArmy:
	var army: Army
	var army_node: ArmyNode

# army_id -> TrackedArmy
var _tracked_armies: Dictionary = {}
# territory_id -> Vector2 (world position of that territory's visual center)
var _territory_centers: Dictionary = {}

func _ready() -> void:
	EventBus.army_spawned.connect(_handle_army_spawned)
	EventBus.army_dissolved.connect(_handle_army_dissolved)
	
func _process(_delta: float) -> void:
	for tracked_army: TrackedArmy in _tracked_armies.values():
		_update_army_visual(tracked_army)

func initialize(map_data: MapData) -> void:
	for data: TerritoryData in map_data.territories:
		var centroid: Vector2 = Vector2.ZERO
		for point in data.polygon_points:
			centroid += point
		centroid /= data.polygon_points.size()
		_territory_centers[data.id] = centroid
	
func _handle_army_spawned(army: Army) -> void:
	var army_node: ArmyNode = ARMY_NODE_SCENE.instantiate()
	add_child(army_node)
	army_node.set_owner_color(_color_for_owner(army.owner_id))
	var tracked_army = TrackedArmy.new()
	tracked_army.army = army
	tracked_army.army_node = army_node
	_tracked_armies[army.id] = tracked_army
	_update_army_visual(tracked_army)
	
func _handle_army_dissolved(army_id: String) -> void:
	var tracked_army : TrackedArmy = _tracked_armies[army_id]
	tracked_army.army_node.queue_free()
	_tracked_armies.erase(army_id)
	
func _update_army_visual(tracked_army: TrackedArmy) -> void:
	var army = tracked_army.army
	var army_node = tracked_army.army_node
	var source_pos : Vector2 = _territory_centers[army.current_edge[0]]
	var target_pos : Vector2 = _territory_centers[army.current_edge[1]]
	var cur_pos = source_pos.lerp(target_pos, army.progress)
	army_node.set_facing(source_pos, target_pos)
	army_node.global_position = cur_pos
	army_node.set_army_size(army.composition[GameSimulation.TROOP_TYPE_INFANTRY])
	
func _color_for_owner(player_id: String) -> Color:
	if player_id == 'player_1':
		return Color.RED
	elif player_id == 'player_2':
		return Color.BLUE
	return Color.GRAY
