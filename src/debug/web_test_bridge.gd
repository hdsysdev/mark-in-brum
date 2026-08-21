extends Node
## Debug-only bridge for browser QA (Playwright). Exposes game readiness and
## runtime state on `window.__markInBrum`. Compiled out of nothing — simply
## inert on non-Web platforms. Never ships gameplay logic.


var _frame_count: int = 0
var _frame_time: float = 0.0


func _ready() -> void:
	if OS.get_name() != "Web":
		return
	GameEvents.game_ready.connect(_on_game_ready)


func _process(delta: float) -> void:
	if OS.get_name() != "Web":
		return
	_frame_count += 1
	_frame_time += delta
	if _frame_time >= 1.0:
		_set_js("window.__markInBrum.fps = %d;" % int(_frame_count / _frame_time))
		_frame_count = 0
		_frame_time = 0.0


func _on_game_ready() -> void:
	_set_js("window.__markInBrum.ready = true;")
	_set_js("window.__markInBrum.readyAt = Date.now();")


func notify_state(key: String, value: String) -> void:
	if OS.get_name() != "Web":
		return
	_set_js("window.__markInBrum['%s'] = '%s';" % [key, value])


func _set_js(code: String) -> void:
	JavaScriptBridge.eval(code)
