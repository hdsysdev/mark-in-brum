extends Node
## Debug-only bridge for browser QA (Playwright). Exposes game readiness and
## runtime state on `window.__markInBrum`. Compiled out of nothing — simply
## inert on non-Web platforms. Never ships gameplay logic.


func _ready() -> void:
	if OS.get_name() != "Web":
		return
	GameEvents.game_ready.connect(_on_game_ready)


func _on_game_ready() -> void:
	_set_js("window.__markInBrum.ready = true;")
	_set_js("window.__markInBrum.readyAt = Date.now();")


func notify_state(key: String, value: String) -> void:
	if OS.get_name() != "Web":
		return
	_set_js("window.__markInBrum['%s'] = '%s';" % [key, value])


func _set_js(code: String) -> void:
	JavaScriptBridge.eval(code)
