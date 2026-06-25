class_name Army
extends RefCounted

enum State { MOVING, FIGHTING, RETREATING }

# Structural legality only. Lists what the machine *permits*;
# GameSimulation decides which permitted transition to actually take.
const LEGAL_TRANSITIONS: Dictionary = {
	State.MOVING:     [State.FIGHTING],
	State.FIGHTING:   [State.MOVING, State.RETREATING],
	State.RETREATING: [State.FIGHTING],
}

var id: String
var owner_id: String
var composition: Dictionary       # TroopType (String) -> int
var path: Array[String]           # Remaining territory IDs, including final destination.
								  # path[0] is "next hop I'm heading toward."
var current_edge: Array[String]   # [from_territory_id, to_territory_id]
var progress: float = 0.0         # 0.0 → 1.0 along current_edge. Visual only.
var state: State = State.MOVING

func can_transition_to(target: State) -> bool:
	# Structural check only. Returns true if target is in this state's legal next set.
	return target in LEGAL_TRANSITIONS[state]

# We're NOT putting transition_to() here — the simulation does the transition
# after asking can_transition_to(). Keeps Army a pure data + schema object.
