class_name TerritoryNode
extends Area2D

var polygon_2d: Polygon2D
var coll_polygon_2d: CollisionPolygon2D
var garrison_label: Label

func setup(data: TerritoryData) -> void:
	name = data.id
	
	polygon_2d = Polygon2D.new()
	polygon_2d.polygon = data.polygon_points
	polygon_2d.color = Color.GREEN_YELLOW
	add_child(polygon_2d)
	
	coll_polygon_2d = CollisionPolygon2D.new()
	coll_polygon_2d.polygon = data.polygon_points
	add_child(coll_polygon_2d)
	
	garrison_label = Label.new()
	add_child(garrison_label)

func set_owner_color(color: Color) -> void:
	polygon_2d.color = color

func set_garrison_count(n: int) -> void:
	garrison_label.text = str(n)
