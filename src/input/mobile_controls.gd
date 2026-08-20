class_name MobileControls
extends CanvasLayer
## Root of the touch control layer. Handles input clearing on focus loss /
## orientation change and reports control rects to the web QA bridge.

@export var show_on_desktop: bool = false

var _router: InputRouter


func _ready() -> void:
	_router = _find_router()
	_visible_check()
	get_viewport().size_changed.connect(_on_viewport_changed)
	_report_layout.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_clear_all()
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_clear_all()


func _find_router() -> InputRouter:
	var group := get_tree().get_nodes_in_group("input_router")
	if group.is_empty():
		return null
	return group[0] as InputRouter


func _visible_check() -> void:
	var touch_capable: bool = DisplayServer.is_touchscreen_available()
	visible = touch_capable or show_on_desktop


func _on_viewport_changed() -> void:
	_clear_all()
	_report_layout()


func _clear_all() -> void:
	if _router != null:
		_router.clear_all_touch_state()
	# Snap joysticks/knobs back through the widget API.
	for child in get_children():
		if child is TouchJoystick:
			child._touch_index = -1
			child._update_knob(child._center)
		elif child is TouchLookZone:
			child._touch_index = -1
		elif child is TouchActionButton:
			child._end()


func _report_layout() -> void:
	if OS.get_name() != "Web":
		return
	var parts: PackedStringArray = []
	for child in get_children():
		if child is Control:
			var rect := (child as Control).get_global_rect()
			parts.append("%s:%d,%d,%d,%d" % [
				child.name, int(rect.position.x), int(rect.position.y),
				int(rect.size.x), int(rect.size.y)])
	JavaScriptBridge.eval("window.__markInBrum.controls = '%s';" % ",".join(parts))
