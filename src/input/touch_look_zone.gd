class_name TouchLookZone
extends Control
## Right-side drag region for camera look. Deltas go to the InputRouter in
## the same screen-space convention as mouse relative motion.

var _router: InputRouter
var _touch_index: int = -1
var _last_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	_router = _find_router()
	mouse_filter = Control.MOUSE_FILTER_STOP


func _find_router() -> InputRouter:
	var group := get_tree().get_nodes_in_group("input_router")
	if group.is_empty():
		return null
	return group[0] as InputRouter


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			_touch_index = event.index
			_last_pos = event.position
		elif not event.pressed and event.index == _touch_index:
			_touch_index = -1
	elif event is InputEventScreenDrag and event.index == _touch_index:
		var delta: Vector2 = event.position - _last_pos
		_last_pos = event.position
		if _router != null:
			_router.add_look_delta(delta)
