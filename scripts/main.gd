extends Node

@onready var map_renderer: MapRenderer = $MapRenderer

func _ready() -> void:
	var map_data: MapData = preload("res://resources/map_data.tres")
	map_renderer.initialize(map_data)
	GameSimulation.initialize(map_data, AttritionCombatResolver.new())
