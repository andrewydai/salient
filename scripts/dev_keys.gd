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
					{GameSimulation.TROOP_TYPE_INFANTRY: 3},  # composition: 1 infantry
				)
				CommandBus.submit(cmd)
			KEY_5:
				# Multi-army head-on test: seed AI ownership + garrison on sunken_road_1_2,
				# then issue opposing moves so two armies meet mid-edge.
				GameSimulation.territory_owner["sunken_road_1_2"] = GameSimulation.PLAYER_ID_AI
				GameSimulation.territory_garrison["sunken_road_1_2"] = {
					GameSimulation.TROOP_TYPE_INFANTRY: 5,
				}
				EventBus.territory_owner_changed.emit("sunken_road_1_2", GameSimulation.PLAYER_ID_AI)
				EventBus.garrison_changed.emit("sunken_road_1_2", GameSimulation.territory_garrison["sunken_road_1_2"])

				var human_move := MoveArmyCommand.new(
					GameSimulation.PLAYER_ID_HUMAN,
					"rivermouth_0_2", "sunken_road_1_2",
					{GameSimulation.TROOP_TYPE_INFANTRY: 3},
				)
				var ai_move := MoveArmyCommand.new(
					GameSimulation.PLAYER_ID_AI,
					"sunken_road_1_2", "rivermouth_0_2",
					{GameSimulation.TROOP_TYPE_INFANTRY: 3},
				)
				CommandBus.submit(human_move)
				CommandBus.submit(ai_move)
			KEY_6:
				# Retreat the first in-flight human army that isn't already retreating.
				for army: Army in GameSimulation.armies.values():
					if army.owner_id == GameSimulation.PLAYER_ID_HUMAN and army.state != Army.State.RETREATING:
						var cmd := RetreatArmyCommand.new(GameSimulation.PLAYER_ID_HUMAN, army.id)
						CommandBus.submit(cmd)
						break
			KEY_7:
				# Issue a real MoveArmyCommand through CommandBus.
				var cmd := MoveArmyCommand.new(
					GameSimulation.PLAYER_ID_HUMAN,       # issuer
					"rivermouth_0_2",                     # from — player's starting territory
					"breadlands_2_2",                     # to — an adjacent neighbor
					{GameSimulation.TROOP_TYPE_INFANTRY: 3},  # composition: 1 infantry
				)
				CommandBus.submit(cmd)
