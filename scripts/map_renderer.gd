class_name MapRenderer
extends Node2D

@export var map_data: MapData

func _ready() -> void:
	_build_map()

func _build_map() -> void:
	# iterate map_data.territories and create a node for each
	for territory_data in map_data.territories:
		_create_territory_node(territory_data)

func _create_territory_node(data: TerritoryData) -> void:
	# create Area2D, Polygon2D, CollisionPolygon2D
	var area_2d = Area2D.new()
	area_2d.name = data.id
	
	var polygon_2d = Polygon2D.new()
	polygon_2d.polygon = data.polygon_points
	polygon_2d.color = Color(0.4, 0.6, 0.3)
	
	var coll_polygon_2d = CollisionPolygon2D.new()
	coll_polygon_2d.polygon = data.polygon_points
	
	add_child(area_2d)
	area_2d.add_child(polygon_2d)
	area_2d.add_child(coll_polygon_2d)
	
	# connect input signal
	area_2d.input_event.connect(_on_territory_input.bind(data.id))

func _on_territory_input(viewport, event, shape_idx, territory_id: String) -> void:
	# translate click into something InputController can use
	pass
