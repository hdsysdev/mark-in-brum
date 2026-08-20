class_name NPCStartledState
extends NPCState
## Brief freeze when sprayed; faces Mark, then hands off to the reaction.

var _startle_remaining: float = 0.0


func enter() -> void:
	brain.stop_moving()
	_startle_remaining = brain.reaction_data.startle_seconds
	brain.face_point(brain.mark_position())


func physics_process(delta: float) -> void:
	_startle_remaining -= delta
	if _startle_remaining <= 0.0:
		brain.start_reaction_transition()


func on_sprayed() -> void:
	# Restart the startle while already startled.
	_startle_remaining = brain.reaction_data.startle_seconds


func state_name() -> String:
	return "startled"
