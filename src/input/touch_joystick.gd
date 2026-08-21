class_name TouchJoystick
extends Control
## Left virtual joystick. Pointer capture is per-touch-index; the normalized
## vector is written straight into the InputRouter. Touch-only (desktop uses
## the keyboard).

@export var radius: float = 64.0
@export var knob_radius: float = 26.0
@export var base_color: Color = Color(1.0, 1.0, 1.0, 0.10)
@export var knob_color: Color = Color(1.0, 1.0, 1.0, 0.30)

var _router: InputRouter
var _touch_index: int = -1
var _knob_offset: Vector2 = Vector2.ZERO
var _center: Vector2 = Vector2.ZERO
var _mouse_dragging: bool = false


func _ready() -> void:
	_router = _find_router()
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(func() -> void:
		_center = size / 2.0
		queue_redraw())
	_center = size / 2.0


func _find_router() -> InputRouter:
	var group := get_tree().get_nodes_in_group("input_router")
	if group.is_empty():
		return null
	return group[0] as InputRouter


func current_vector() -> Vector2:
	return _knob_offset / radius if radius > 0.0 else Vector2.ZERO


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			_touch_index = event.index
			_update_knob(event.position)
		elif not event.pressed and event.index == _touch_index:
			_touch_index = -1
			_update_knob(_center)
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_update_knob(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and _touch_index == -1:
		_mouse_dragging = event.pressed
		if _mouse_dragging:
			_update_knob(event.position)
		else:
			_update_knob(_center)
	elif event is InputEventMouseMotion and _mouse_dragging:
		_update_knob(event.position)


func _update_knob(pos: Vector2) -> void:
	var delta: Vector2 = pos - _center
	if delta.length() > radius:
		delta = delta.normalized() * radius
	_knob_offset = delta
	if _router != null:
		_router.joystick_vector = current_vector()
	if OS.get_name() == "Web":
		JavaScriptBridge.eval("window.__markInBrum.joyVector = [%.3f, %.3f];" % [
			current_vector().x, current_vector().y])
	queue_redraw()


func _draw() -> void:
	if _center == Vector2.ZERO:
		_center = size / 2.0
	draw_circle(_center, radius, base_color)
	draw_circle(_center + _knob_offset, knob_radius, knob_color)
