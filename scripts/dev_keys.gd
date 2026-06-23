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
				EventBus.garrison_changed.emit("iron_hills_0_0", { GameSimulation.TROOP_TYPE_INFANTRY : 42 })
			KEY_4:
				# Issue a real MoveArmyCommand through CommandBus.
				var cmd := MoveArmyCommand.new(
					GameSimulation.PLAYER_ID_HUMAN,       # issuer
					"rivermouth_0_2",                     # from — player's starting territory
					"sunken_road_1_2",                     # to — an adjacent neighbor
					{GameSimulation.TROOP_TYPE_INFANTRY: 1},  # composition: 1 infantry
				)
				CommandBus.submit(cmd)
