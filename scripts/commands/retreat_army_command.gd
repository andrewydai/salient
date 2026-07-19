class_name RetreatArmyCommand
extends Command

var army_id : String

func _init(issuer: String, retreating_army_id: String) -> void:
	issuer_player_id = issuer
	army_id = retreating_army_id
