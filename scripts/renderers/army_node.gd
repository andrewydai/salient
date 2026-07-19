class_name ArmyNode
extends Node2D

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _army_size_label: Label = $ArmySizeLabel

# temp army size label
func set_army_size(army_size: int) -> void:
	_army_size_label.text = str(army_size)

func set_owner_color(color: Color) -> void:
	_sprite.modulate = color

func set_facing(from_pos: Vector2, to_pos: Vector2) -> void:
	_sprite.rotation = (to_pos - from_pos).angle()
