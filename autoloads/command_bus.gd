extends Node

func submit(command: Command) -> void:
	var is_legal : bool = false
	if command is MoveArmyCommand:
		is_legal = GameSimulation.is_move_legal(command)
	elif command is RetreatArmyCommand:
		is_legal = GameSimulation.is_retreat_legal(command)
	else:
		push_warning("Unknown command type")
		return
		
	if is_legal:
		GameSimulation.apply(command)
	else:
		push_warning("Invalid command")
