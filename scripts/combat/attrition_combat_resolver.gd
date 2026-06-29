class_name AttritionCombatResolver
extends CombatResolver

# 1:1 attrition math.
# Phase 1 binary combat: aggregate troops by owner side, subtract the smaller
# total from both, build CombatResult with WIN/DEFEAT per participant.
# Ignores territory_fight.garrison vs. armies asymmetry by treating garrison
# as just another side.
func resolve_combat(context: CombatContext) -> CombatResult:
	var result = CombatResult.new()
	var is_territory_fight = context.territory_fight != null
	# assuming 1 on 1 combat for now and one troop type for now
	var outcomes_by_army_id = {}
	var updated_army_compositions = {}
	if is_territory_fight:
		var updated_territory_garrison = {}
		var attacking_army = context.armies[0]
		var attacking_army_count = attacking_army.composition[GameSimulation.TROOP_TYPE_INFANTRY]
		var defending_army_count = context.territory_fight.garrison[GameSimulation.TROOP_TYPE_INFANTRY]
		if attacking_army_count > defending_army_count:
			outcomes_by_army_id[attacking_army.id] = result.Outcome.WIN
			updated_territory_garrison[GameSimulation.TROOP_TYPE_INFANTRY] = 0
			updated_army_compositions[attacking_army.id] = { GameSimulation.TROOP_TYPE_INFANTRY: attacking_army_count - defending_army_count }
		else:
			outcomes_by_army_id[attacking_army.id] = result.Outcome.DEFEAT
			updated_territory_garrison[GameSimulation.TROOP_TYPE_INFANTRY] = defending_army_count - attacking_army_count
			updated_army_compositions[attacking_army.id] = { GameSimulation.TROOP_TYPE_INFANTRY: 0 }
		result.updated_territory_garrison = updated_territory_garrison
	else:
		var army_1 = context.armies[0]
		var army_2 = context.armies[1]
		var army_1_army_count = army_1.composition[GameSimulation.TROOP_TYPE_INFANTRY]
		var army_2_army_count = army_2.composition[GameSimulation.TROOP_TYPE_INFANTRY]
		if army_1_army_count > army_2_army_count:
			outcomes_by_army_id[army_1.id] = result.Outcome.WIN
			outcomes_by_army_id[army_2.id] = result.Outcome.DEFEAT
			updated_army_compositions[army_1.id] = { GameSimulation.TROOP_TYPE_INFANTRY: army_1_army_count - army_2_army_count}
			updated_army_compositions[army_2.id] = { GameSimulation.TROOP_TYPE_INFANTRY: 0 }
		else:
			outcomes_by_army_id[army_1.id] = result.Outcome.DEFEAT
			outcomes_by_army_id[army_2.id] = result.Outcome.WIN
			updated_army_compositions[army_1.id] = { GameSimulation.TROOP_TYPE_INFANTRY: 0 }
			updated_army_compositions[army_2.id] = { GameSimulation.TROOP_TYPE_INFANTRY: army_2_army_count - army_1_army_count }
	
	result.outcomes_by_army_id = outcomes_by_army_id
	result.updated_army_compositions = updated_army_compositions
	
	return result
