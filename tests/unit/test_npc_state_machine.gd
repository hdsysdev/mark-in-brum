extends GutTest
## Civilian state machine contract: ambient loop, spray transition, seeded
## deterministic reaction selection, and recovery. States are driven with
## manual deltas where possible to keep the suite fast.

const CIVILIAN_SCENE: String = "res://scenes/npc/civilian.tscn"


func _spawn_civilian() -> NPCBrain:
	var civilian := (load(CIVILIAN_SCENE) as PackedScene).instantiate()
	civilian.position = Vector3(0.0, 0.9, 0.0)
	add_child_autofree(civilian)
	var brain: NPCBrain = civilian.get_node("Brain")
	brain.waypoints = [Vector3(0.0, 0.0, 4.0)]
	return brain


func _step(brain: NPCBrain, seconds: float) -> void:
	var steps := int(ceil(seconds / 0.1))
	for i in steps:
		brain._physics_process(0.1)


func test_brain_starts_idle() -> void:
	var brain := _spawn_civilian()
	assert_eq(brain.state_name(), "idle")


func test_idle_transitions_to_wander_after_timeout() -> void:
	var brain := _spawn_civilian()
	_step(brain, 7.5)  # idle pause is 1.5..6s; 7.5s guarantees the flip
	assert_eq(brain.state_name(), "wander")


func test_wander_arrives_and_returns_to_idle() -> void:
	var brain := _spawn_civilian()
	brain._set_state(NPCWanderState.new(brain))
	_step(brain, 0.2)
	# Force arrival by teleporting onto the waypoint.
	(brain._body as CharacterBody3D).position = Vector3(0.0, 0.9, 3.2)
	_step(brain, 0.2)
	assert_eq(brain.state_name(), "idle", "arrival within arrival_distance must idle")


func test_sprayed_flow_with_forced_complain_reaction() -> void:
	var brain := _spawn_civilian()
	brain.next_reaction_override = NPCBrain.Reaction.COMPLAIN
	GameEvents.target_sprayed.emit(brain._body, {})
	assert_eq(brain.state_name(), "startled")
	_step(brain, 0.8)
	assert_eq(brain.state_name(), "complain", "startle timeout must pick the forced reaction")
	assert_eq(brain.current_reaction(), NPCBrain.Reaction.COMPLAIN)
	_step(brain, brain.reaction_data.complain_seconds + 0.2)
	assert_eq(brain.state_name(), "recover")
	_step(brain, brain.reaction_data.recover_seconds + 0.2)
	assert_eq(brain.state_name(), "idle", "recovery must return to the ambient loop")


func test_reaction_selection_is_deterministic_for_same_seed() -> void:
	var brain_a := _spawn_civilian()
	var brain_b := _spawn_civilian()
	brain_a.rng_seed = 424242
	brain_b.rng_seed = 424242
	brain_a._rng.seed = 424242
	brain_b._rng.seed = 424242
	brain_a.next_reaction_override = -1
	brain_b.next_reaction_override = -1
	brain_a.start_reaction_transition()
	brain_b.start_reaction_transition()
	assert_eq(brain_a.current_reaction(), brain_b.current_reaction(),
		"same seed must produce the same reaction")


func test_call_security_chance_of_one_always_calls() -> void:
	var brain := _spawn_civilian()
	brain.reaction_data.call_security_chance = 1.0
	brain.reaction_data.complaint_chance = 0.0
	brain.next_reaction_override = -1
	brain.start_reaction_transition()
	assert_eq(brain.current_reaction(), NPCBrain.Reaction.CALL_SECURITY)


func test_reaction_signal_emitted_with_name() -> void:
	var brain := _spawn_civilian()
	var reactions: Array = []
	brain.reaction_started.connect(func(name: String) -> void: reactions.append(name))
	brain.next_reaction_override = NPCBrain.Reaction.FLEE
	brain.start_reaction_transition()
	assert_eq(reactions, ["flee"])
