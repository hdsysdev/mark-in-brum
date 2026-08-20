class_name ErrandStep
extends Resource
## One objective in the first-day errand chain. Steps either complete on
## proximity, on a sprayed NPC, or via explicit API for narrative beats.

@export var id: String = "step"
@export var objective_text: String = "Do the thing."
@export var kind: String = "proximity"  # proximity | spray | narrative
@export var trigger_position: Vector3 = Vector3.ZERO
@export var trigger_radius: float = 2.0


func describe() -> String:
	return objective_text
