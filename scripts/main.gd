extends Node

@onready var map_renderer: MapRenderer = $MapRenderer
@onready var army_renderer: ArmyRenderer = $ArmyRenderer

func _ready() -> void:
	var map_data: MapData = preload("res://resources/map_data.tres")
	map_renderer.initialize(map_data)
	army_renderer.initialize(map_data)
	GameSimulation.initialize(map_data, AttritionCombatResolver.new())
