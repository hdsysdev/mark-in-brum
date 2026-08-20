class_name NPCState
extends RefCounted
## Base class for civilian brain states. States are plain objects owned by
## the brain; they never hold scene references of their own.

var brain: NPCBrain

func _init(owner: NPCBrain) -> void:
	brain = owner


func enter() -> void:
	pass


func exit() -> void:
	pass


func physics_process(_delta: float) -> void:
	pass


func on_sprayed() -> void:
	brain.transition_to_sprayed()


func state_name() -> String:
	return "base"
