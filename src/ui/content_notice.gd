class_name ContentNotice
extends CanvasLayer
## First-launch mature-content gate. Overlays the game until accepted; the
## choice is persisted in SaveManager. The simulation keeps running behind
## it (no tree pause), and the accept button rect is reported to the QA
## bridge so browser tests can dismiss it.

@onready var _panel: Panel = $Panel
@onready var _accept: Button = $Panel/AcceptButton
@onready var _decline: Button = $Panel/DeclineButton

var _reported: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_accept.pressed.connect(_on_accept)
	_decline.pressed.connect(_on_decline)
	if SaveManager.get_setting("content/notice_accepted", false):
		visible = false
		set_process(false)
		_report_visible.call_deferred(false)
	else:
		_accept.grab_focus()


func _process(_delta: float) -> void:
	# Report the accept-button rect once per session, computed from the
	# viewport size (the panel is fixed 560x440, centred; button offsets
	# are fixed) so QA never races the anchor layout.
	if _reported:
		set_process(false)
		return
	_report_visible(true)
	_reported = true
	set_process(false)


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
	# Panel is 560x440 centred; accept button sits 140px from panel left,
	# 376px from panel top, 192x44.
	var viewport := get_viewport().get_visible_rect().size
	var bx: int = int((viewport.x - 560.0) / 2.0) + 140
	var by: int = int((viewport.y - 440.0) / 2.0) + 376
	var js := "window.__markInBrum.notice = {visible: " + ("true" if is_visible else "false") \
		+ ", accept: [" + "%d, %d, %d, %d" % [bx, by, 192, 44] \
		+ "], cssScale: [" \
		+ "document.getElementById('canvas').clientWidth / document.getElementById('canvas').width," \
		+ "document.getElementById('canvas').clientHeight / document.getElementById('canvas').height]};"
	JavaScriptBridge.eval(js)
