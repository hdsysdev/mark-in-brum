class_name NPCCallSecurityState
extends NPCState
## Stops, faces Mark, and phones security for a few seconds, then recovers.

var _call_remaining: float = 0.0


func enter() -> void:
	brain.stop_moving()
	_call_remaining = brain.reaction_data.call_security_seconds
	brain.face_point(brain.mark_position())


func physics_process(delta: float) -> void:
	_call_remaining -= delta
	if _call_remaining <= 0.0:
		brain.transition_to_recover()


func state_name() -> String:
	return "call_security"
