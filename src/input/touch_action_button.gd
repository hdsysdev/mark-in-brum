class_name TouchActionButton
extends Control
## Generic touch button. Modes: HOLD (action), TOGGLE (sprint), PRESS
## (recenter/pause). Writes only to the InputRouter; gameplay never sees
## this widget.

enum Mode { HOLD, TOGGLE, PRESS }
enum ButtonAction { ACTION, SPRINT, RECENTER, PAUSE }

@export var mode: Mode = Mode.HOLD
@export var button_action: ButtonAction = ButtonAction.ACTION
@export var fill_color: Color = Color(1.0, 1.0, 1.0, 0.12)
@export var active_color: Color = Color(0.91, 0.72, 0.29, 0.45)

var _router: InputRouter
var _pressed: bool = false
var _toggle_on: bool = false


func _ready() -> void:
	_router = _find_router()
	mouse_filter = Control.MOUSE_FILTER_STOP


func _find_router() -> InputRouter:
	var group := get_tree().get_nodes_in_group("input_router")
	if group.is_empty():
		return null
	return group[0] as InputRouter


func is_active() -> bool:
	return _toggle_on if mode == Mode.TOGGLE else _pressed


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_begin()
		else:
			_end()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin()
		else:
			_end()


func _begin() -> void:
	match mode:
		Mode.HOLD:
			_pressed = true
			_apply(true)
		Mode.TOGGLE:
			_toggle_on = not _toggle_on
			_apply(_toggle_on)
		Mode.PRESS:
			_apply_press()
	queue_redraw()


func _end() -> void:
	if mode == Mode.HOLD:
		_pressed = false
		_apply(false)
	queue_redraw()


func _apply(held: bool) -> void:
	if _router == null:
		return
	match button_action:
		ButtonAction.ACTION:
			_router.touch_action_held = held
		ButtonAction.SPRINT:
			_router.touch_sprint_held = held


func _apply_press() -> void:
	if _router == null:
		return
	match button_action:
		ButtonAction.RECENTER:
			_router.press_recenter()
		ButtonAction.PAUSE:
			_router.press_pause()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var inset: float = minf(size.x, size.y) * 0.06
	var circle_rect := rect.grow(-inset)
	draw_circle(circle_rect.get_center(), circle_rect.size.x / 2.0, active_color if is_active() else fill_color)
