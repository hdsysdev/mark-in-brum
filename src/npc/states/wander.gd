class_name NPCWanderState
extends NPCState
## Picks a nearby waypoint and walks to it, then idles.

var _target: Vector3 = Vector3.ZERO


func enter() -> void:
	_target = brain.pick_waypoint()
	brain.set_nav_target(_target)


func physics_process(delta: float) -> void:
	var arrived := brain.navigate_to(_target, brain.walk_speed, delta)
	if arrived:
		brain.transition_to_idle()


func state_name() -> String:
	return "wander"
