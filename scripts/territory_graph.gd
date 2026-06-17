class_name TerritoryGraph

var _adjacency: Dictionary = {}

func build(map_data: MapData) -> void:
	for territory_data in map_data.territories:
		_adjacency[territory_data.id] = territory_data.neighbors
	
func get_neighbors(territory_id: String) -> Array[String]:
	return _adjacency[territory_id]
	
func find_path(from_id: String, to_id: String) -> Array[String]:
	var came_from : Dictionary = {}
	var ter_to_visit : Array[String] = [from_id]
	var visited_ter : Array[String] = []
	
	while ter_to_visit.size() > 0:
		var cur_ter = ter_to_visit.pop_front()
		
		if cur_ter in visited_ter:
			continue
		elif cur_ter == to_id:
			return trace_came_from(came_from, cur_ter)
		else:
			visited_ter.append(cur_ter)
			var cur_neighbors = get_neighbors(cur_ter)
			for neighbor in cur_neighbors:
				if neighbor not in visited_ter:
					ter_to_visit.push_back(neighbor)
					came_from[neighbor] = cur_ter
	return []
			
func trace_came_from(came_from : Dictionary, to_id : String) -> Array[String]:
	var path : Array[String] = [to_id]
	var prev_ter = came_from[to_id]
	while prev_ter != null:
		path.push_front(prev_ter)
		prev_ter = came_from.get(prev_ter, null)
	
	return path
