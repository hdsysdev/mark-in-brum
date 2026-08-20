class_name NPCRecoverState
extends NPCState
## Shakes it off: walks to a nearby waypoint, then resumes the ambient loop.

var _recover_remaining: float = 0.0
var _recover_target: Vector3 = Vector3.ZERO


func enter() -> void:
	_recover_remaining = brain.reaction_data.recover_seconds
	_recover_target = brain._body.global_position + brain.pick_local_offset(6.0)
	brain.set_nav_target(_recover_target)


func physics_process(delta: float) -> void:
	_recover_remaining -= delta
	var arrived := brain.navigate_to(_recover_target, brain.walk_speed, delta)
	if arrived or _recover_remaining <= 0.0:
		brain.transition_to_idle()


func state_name() -> String:
	return "recover"
