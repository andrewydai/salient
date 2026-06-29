class_name CombatResolver
extends RefCounted

# ---------:- Data carriers (inner classes) ----------

# Represents the territory side of a territory-arrival combat.
# null on the context = edge combat (no territory involved).
class TerritoryFight extends RefCounted:
	var territory_id: String
	var garrison: Dictionary  # TroopType (String) -> count (int)
	
class CombatContext extends RefCounted:
	var armies : Array[Army]
	var territory_fight
	
class CombatResult extends RefCounted:
	enum Outcome { WIN, RETREAT, DEFEAT }
	var outcomes_by_army_id: Dictionary       # army_id (String) -> Outcome
	var updated_army_compositions: Dictionary # army_id (String) -> Dictionary[TroopType -> int]
	var updated_territory_garrison            # Dictionary or null (mirrors context)
	
# ---------- Strategy contract ----------

# Abstract — subclasses must override.
# GDScript has no real abstract keyword; we assert at call time.
func resolve_combat(context: CombatContext) -> CombatResult:
	push_error("CombatResolver.resolve_combat must be overridden")
	return null
