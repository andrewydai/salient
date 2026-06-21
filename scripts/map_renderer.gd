class_name MapRenderer
extends Node2D

@export var map_data: MapData

var territories_by_id: Dictionary = {} # String -> TerritoryNode

func _ready() -> void:
	EventBus.territory_owner_changed.connect(_territory_owner_changed_handler)
	EventBus.garrison_changed.connect(_garrison_changed_handler)
	_build_map()

func _color_for_owner(player_id: String) -> Color:
	if player_id == 'player_1':
		return Color.RED
	elif player_id == 'player_2':
		return Color.BLUE
	return Color.GREEN_YELLOW

func _territory_owner_changed_handler(territory_id: String, new_owner_id: String) -> void:
	territories_by_id[territory_id].set_owner_color(_color_for_owner(new_owner_id))

func _garrison_changed_handler(territory_id: String, new_total: int) -> void:
	territories_by_id[territory_id].set_garrison_count(new_total)

func _build_map() -> void:
	# iterate map_data.territories and create a node for each
	for territory_data in map_data.territories:
		_create_territory_node(territory_data)

func _create_territory_node(data: TerritoryData) -> void:
	var territory_node = TerritoryNode.new()
	territory_node.setup(data)
	add_child(territory_node)
	territories_by_id[data.id] = territory_node
	# connect input signal
	territory_node.input_event.connect(_on_territory_input.bind(data.id))

func _on_territory_input(viewport, event, shape_idx, territory_id: String) -> void:
	EventBus.territory_clicked.emit(territory_id)
