class_name MoveArmyCommand
extends Command

var from_territory : String
var to_territory : String
var composition : Dictionary

func _init(issuer: String, from_id: String, to_id: String, troops: Dictionary) -> void:
	issuer_player_id = issuer
	from_territory = from_id
	to_territory = to_id
	composition = troops
