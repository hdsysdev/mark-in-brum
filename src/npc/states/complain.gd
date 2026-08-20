class_name NPCComplainState
extends NPCState
## Turns to Mark and complains loudly for a few seconds, then recovers.

var _complain_remaining: float = 0.0


func enter() -> void:
	brain.stop_moving()
	_complain_remaining = brain.reaction_data.complain_seconds
	brain.face_point(brain.mark_position())


func physics_process(delta: float) -> void:
	_complain_remaining -= delta
	brain.face_point(brain.mark_position())
	if _complain_remaining <= 0.0:
		brain.transition_to_recover()


func state_name() -> String:
	return "complain"
