class_name NPCIdleState
extends NPCState
## Stands in place for a randomized pause, then wanders.

var _idle_remaining: float = 0.0


func enter() -> void:
	brain.stop_moving()
	_idle_remaining = 1.5 + brain._rng.randf() * 4.5


func physics_process(delta: float) -> void:
	_idle_remaining -= delta
	if _idle_remaining <= 0.0:
		brain.transition_to_wander()


func state_name() -> String:
	return "idle"
