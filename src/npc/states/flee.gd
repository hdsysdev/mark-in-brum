class_name NPCFleeState
extends NPCState
## Runs away from Mark for a bounded time, then recovers.

var _flee_remaining: float = 0.0
var _flee_target: Vector3 = Vector3.ZERO


func enter() -> void:
	_flee_remaining = brain.reaction_data.flee_seconds
	var away: Vector3 = brain._body.global_position - brain.mark_position()
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = Vector3(brain._rng.randf_range(-1.0, 1.0), 0.0, brain._rng.randf_range(-1.0, 1.0))
	away = away.normalized()
	_flee_target = brain._body.global_position + away * 9.0 + brain.pick_local_offset(2.5)
	brain.set_nav_target(_flee_target)


func physics_process(delta: float) -> void:
	_flee_remaining -= delta
	var arrived := brain.navigate_to(_flee_target, brain.flee_speed, delta)
	if arrived or _flee_remaining <= 0.0:
		brain.transition_to_recover()


func state_name() -> String:
	return "flee"
