class_name ContentNotice
extends CanvasLayer
## First-launch mature-content gate. Overlays the game until accepted; the
## choice is persisted in SaveManager. The simulation keeps running behind
## it (no tree pause), and the accept button rect is reported to the QA
## bridge so browser tests can dismiss it.

@onready var _panel: Panel = $Panel
@onready var _title: Label = $Panel/Title
@onready var _body: Label = $Panel/Body
@onready var _declined_label: Label = $Panel/DeclinedLabel
@onready var _accept: Button = $Panel/AcceptButton
@onready var _decline: Button = $Panel/DeclineButton

var _reported: bool = false
var _owns_pause: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_accept.pressed.connect(_on_accept)
	_decline.pressed.connect(_on_decline)
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()
	if SaveManager.get_setting("content/notice_accepted", false):
		visible = false
		set_process(false)
		_report_visible.call_deferred(false)
	else:
		if not get_tree().paused:
			get_tree().paused = true
			_owns_pause = true
		_accept.grab_focus.call_deferred()


func _exit_tree() -> void:
	if _owns_pause and get_tree() != null and get_tree().paused:
		get_tree().paused = false
	_owns_pause = false


func _apply_layout() -> void:
	apply_layout_for_size(get_viewport().get_visible_rect().size)
	_reported = false
	set_process(true)


func apply_layout_for_size(viewport_size: Vector2) -> void:
	var panel := (_panel if _panel != null else get_node("Panel")) as Panel
	var title := (_title if _title != null else get_node("Panel/Title")) as Label
	var body := (_body if _body != null else get_node("Panel/Body")) as Label
	var declined_label := (_declined_label if _declined_label != null else get_node("Panel/DeclinedLabel")) as Label
	var accept := (_accept if _accept != null else get_node("Panel/AcceptButton")) as Button
	var decline := (_decline if _decline != null else get_node("Panel/DeclineButton")) as Button
	var portrait := viewport_size.y > viewport_size.x * 1.1
	var panel_width := minf(viewport_size.x - 80.0, 880.0 if portrait else 820.0)
	var panel_height := minf(viewport_size.y - 160.0, 980.0 if portrait else 560.0)
	var margin := 40.0 if portrait else 32.0
	var title_height := 64.0 if portrait else 52.0
	var button_height := 96.0 if portrait else 72.0
	var button_gap := 24.0
	var button_width := (panel_width - margin * 2.0 - button_gap) * 0.5

	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = (viewport_size - Vector2(panel_width, panel_height)) * 0.5
	panel.size = Vector2(panel_width, panel_height)

	title.set_anchors_preset(Control.PRESET_TOP_LEFT)
	title.position = Vector2(margin, 26.0)
	title.size = Vector2(panel_width - margin * 2.0, title_height)
	title.add_theme_font_size_override("font_size", 36 if portrait else 30)

	body.set_anchors_preset(Control.PRESET_TOP_LEFT)
	body.position = Vector2(margin, 104.0 if portrait else 82.0)
	body.size = Vector2(panel_width - margin * 2.0, panel_height - button_height - margin - (126.0 if portrait else 104.0))
	body.add_theme_font_size_override("font_size", 26 if portrait else 20)
	body.add_theme_constant_override("line_spacing", 5 if portrait else 3)

	var button_y := panel_height - margin - button_height
	accept.set_anchors_preset(Control.PRESET_TOP_LEFT)
	accept.position = Vector2(margin, button_y)
	accept.size = Vector2(button_width, button_height)
	accept.add_theme_font_size_override("font_size", 26 if portrait else 22)
	decline.set_anchors_preset(Control.PRESET_TOP_LEFT)
	decline.position = Vector2(margin + button_width + button_gap, button_y)
	decline.size = Vector2(button_width, button_height)
	decline.add_theme_font_size_override("font_size", 26 if portrait else 22)

	declined_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	declined_label.position = Vector2(margin, button_y - 56.0)
	declined_label.size = Vector2(panel_width - margin * 2.0, 44.0)
	declined_label.add_theme_font_size_override("font_size", 20 if portrait else 16)


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
	if _owns_pause:
		get_tree().paused = false
		_owns_pause = false
	visible = false
	set_process(false)
	_report_visible(false)


func _on_decline() -> void:
	_declined_label.visible = true


func _report_visible(is_visible: bool) -> void:
	if OS.get_name() != "Web":
		return
	var rect := _accept.get_global_rect()
	var bx: int = roundi(rect.position.x)
	var by: int = roundi(rect.position.y)
	var bw: int = roundi(rect.size.x)
	var bh: int = roundi(rect.size.y)
	var js := "window.__markInBrum.notice = {visible: " + ("true" if is_visible else "false") \
		+ ", accept: [" + "%d, %d, %d, %d" % [bx, by, bw, bh] \
		+ "], cssScale: [" \
		+ "document.getElementById('canvas').clientWidth / document.getElementById('canvas').width," \
		+ "document.getElementById('canvas').clientHeight / document.getElementById('canvas').height]};"
	JavaScriptBridge.eval(js)
