extends Node

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				# Fire an ownership change for territory iron_hills_0_0 to player_1
				EventBus.territory_owner_changed.emit("iron_hills_0_0", "player_1")
			KEY_2:
				# Fire an ownership change for the same territory to player_2
				EventBus.territory_owner_changed.emit("iron_hills_0_0", "player_2")
			KEY_3:
				# Bump garrison on iron_hills_0_0
				EventBus.garrison_changed.emit("iron_hills_0_0", 42)
