class_name TerritoryNode
extends Area2D

var polygon_2d: Polygon2D
var coll_polygon_2d: CollisionPolygon2D
var garrison_label: Label
var title_label: Label

func setup(data: TerritoryData) -> void:
	name = data.id
	
	var centroid: Vector2 = Vector2.ZERO
	for point in data.polygon_points:
		centroid += point
	centroid /= data.polygon_points.size()
	
	var shifted_polygon: PackedVector2Array = []
	for point in data.polygon_points:
		shifted_polygon.push_back(point - centroid)
	position = centroid
	
	polygon_2d = Polygon2D.new()
	polygon_2d.polygon = shifted_polygon
	polygon_2d.color = Color.GRAY
	add_child(polygon_2d)
	
	coll_polygon_2d = CollisionPolygon2D.new()
	coll_polygon_2d.polygon = shifted_polygon
	add_child(coll_polygon_2d)
	
	garrison_label = Label.new()
	garrison_label.position = Vector2(0, 4)
	add_child(garrison_label)
	
	title_label = Label.new()
	title_label.text = data.display_name
	title_label.position = Vector2(0, -16)
	add_child(title_label)

func set_owner_color(color: Color) -> void:
	polygon_2d.color = color

func set_garrison_count(n: int) -> void:
	garrison_label.text = str(n)
