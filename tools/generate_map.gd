@tool
extends EditorScript

var row_max := 3
var col_max := 5
var names = [
	['iron_hills', 'silver_pass', 'spine', 'eagle_peak', 'dragons_rest'],
	['westmarch', 'crossroads', 'heartland', 'eastmarch', 'storm_coast'],
	['rivermouth', 'sunken_road', 'breadlands', 'amber_fields', 'saltmarsh']
]


func _run() -> void:
	var map := MapData.new()
	map.territories = _build_territories()
	map.starting_positions = { 
		"rivermouth_0_2": GameSimulation.PLAYER_ID_HUMAN, 
		"dragons_rest_4_0": GameSimulation.PLAYER_ID_AI
	}
	ResourceSaver.save(map, "res://resources/map_data.tres")
	print("map_data.tres saved.")

func _build_territories() -> Array[TerritoryData]:
	var list: Array[TerritoryData] = []
	for row in range(row_max):
		for col in range(col_max):
			var points : PackedVector2Array = [
				Vector2(col * 256, row * 240),
				Vector2((col + 1) * 256, row * 240),
				Vector2((col + 1) * 256, (row + 1) * 240),
				Vector2(col * 256, (row + 1) * 240)
			]
			var neighbors : Array[String] = []
			if col - 1 >= 0:
				neighbors.append(get_id(row, col - 1))
			if col + 1 < col_max:
				neighbors.append(get_id(row, col + 1))
			if row - 1 >= 0:
				neighbors.append(get_id(row - 1, col))
			if row + 1 < row_max:
				neighbors.append(get_id(row + 1, col))
				
			list.append(_make_territory(
				get_id(row, col),
				names[row][col],
				neighbors,
				points
			))
	
	return list

func _make_territory(id: String, name: String, neighbors: Array[String], points: PackedVector2Array) -> TerritoryData:
	var territory_data = TerritoryData.new()
	territory_data.id = id
	territory_data.display_name = name
	territory_data.neighbors = neighbors
	territory_data.polygon_points = points
	territory_data.passable = true
	territory_data.base_production = 1
	territory_data.terrain_type = 0
	
	return territory_data
	
func get_id(row : int, col : int) -> String:
	var display_name = names[row][col]
	return display_name + '_' + str(col) + '_' + str(row)
