class_name ContentNotice
extends CanvasLayer
## First-launch mature-content gate. Overlays the game until accepted; the
## choice is persisted in SaveManager. The simulation keeps running behind
## it (no tree pause), and the accept button rect is reported to the QA
## bridge so browser tests can dismiss it.

@onready var _panel: Panel = $Panel
@onready var _accept: Button = $Panel/AcceptButton
@onready var _decline: Button = $Panel/DeclineButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_accept.pressed.connect(_on_accept)
	_decline.pressed.connect(_on_decline)
	if SaveManager.get_setting("content/notice_accepted", false):
		visible = false
		set_process(false)
		_report_visible.call_deferred(false)
	else:
		_report_visible.call_deferred(true)
	_accept.grab_focus()


func _on_accept() -> void:
	SaveManager.set_setting("content/notice_accepted", true)
	GameEvents.content_notice_accepted.emit()
	visible = false
	set_process(false)
	_report_visible(false)


func _on_decline() -> void:
	_panel.get_node("DeclinedLabel").visible = true


func _report_visible(is_visible: bool) -> void:
	if OS.get_name() != "Web":
		return
	var accept_rect := _accept.get_global_rect()
	var js := "window.__markInBrum.notice = {visible: " + ("true" if is_visible else "false") \
		+ ", accept: [" + "%d, %d, %d, %d" % [
			int(accept_rect.position.x), int(accept_rect.position.y),
			int(accept_rect.size.x), int(accept_rect.size.y)] \
		+ "], cssScale: [" \
		+ "document.getElementById('canvas').clientWidth / document.getElementById('canvas').width," \
		+ "document.getElementById('canvas').clientHeight / document.getElementById('canvas').height]};"
	JavaScriptBridge.eval(js)
