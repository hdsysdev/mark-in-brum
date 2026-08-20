class_name ErrandChain
extends Resource
## Ordered objective list for the first-day slice.

@export var chain_id: String = "first_day"
@export var steps: Array[ErrandStep] = []


func step_at(index: int) -> ErrandStep:
	if index < 0 or index >= steps.size():
		return null
	return steps[index]
