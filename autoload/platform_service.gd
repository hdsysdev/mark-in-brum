extends Node
## Thin platform detection service. Gameplay code asks, never sniffs globals.

var is_web: bool = false
var is_mobile: bool = false
var is_touch_capable: bool = false


func _ready() -> void:
	is_web = OS.get_name() == "Web"
	var has_touch: bool = DisplayServer.is_touchscreen_available()
	var viewport_size: Vector2 = _viewport_size()
	# Tablet/phone heuristic: touchscreen present and a portrait-ish or small canvas.
	var min_dimension: float = minf(viewport_size.x, viewport_size.y)
	is_mobile = has_touch and min_dimension < 900.0
	is_touch_capable = has_touch


func viewport_size() -> Vector2:
	return _viewport_size()


func _viewport_size() -> Vector2:
	return get_viewport().get_visible_rect().size
