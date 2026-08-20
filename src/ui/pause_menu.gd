class_name PauseMenu
extends CanvasLayer
## Pause overlay with the v1 settings: reduced grossness, sensitivity,
## sprint mode, mute, quality. Persisted via SaveManager.

@onready var _reduced: CheckBox = $Panel/VBox/ReducedGrossness
@onready var _sensitivity: HSlider = $Panel/VBox/Sensitivity
@onready var _sprint_toggle: CheckBox = $Panel/VBox/SprintToggle
@onready var _mute: CheckBox = $Panel/VBox/Mute
@onready var _quality: OptionButton = $Panel/VBox/Quality
@onready var _resume: Button = $Panel/VBox/ResumeButton

var _router: InputRouter
var _camera: ThirdPersonCamera


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_resume.pressed.connect(_close)
	visible = false
	if _quality.item_count == 0:
		_quality.add_item("Low")
		_quality.add_item("Medium")
		_quality.add_item("High")
	var group := get_tree().get_nodes_in_group("input_router")
	_router = group[0] as InputRouter if not group.is_empty() else null
	_load_settings()
	_reduced.toggled.connect(func(on: bool) -> void:
		SaveManager.set_setting("grossness/reduced", on)
		GameEvents.settings_changed.emit("grossness"))
	_sprint_toggle.toggled.connect(func(on: bool) -> void:
		SaveManager.set_setting("controls/sprint_toggle", on)
		GameEvents.settings_changed.emit("controls"))
	_mute.toggled.connect(func(on: bool) -> void:
		SaveManager.set_setting("audio/mute", on)
		GameEvents.settings_changed.emit("audio"))
	_sensitivity.value_changed.connect(func(value: float) -> void:
		SaveManager.set_setting("camera/sensitivity", value))
	_quality.item_selected.connect(func(index: int) -> void:
		SaveManager.set_setting("quality/level", index)
		GameEvents.quality_changed.emit(_quality.get_item_text(index)))


func _process(_delta: float) -> void:
	var frame: InputFrame = _router.last_frame() if _router != null else null
	if frame != null and frame.pause_pressed:
		_toggle()


func toggle() -> void:
	_toggle()


func _toggle() -> void:
	visible = not visible
	if visible:
		_resume.grab_focus()


func _close() -> void:
	visible = false


func _load_settings() -> void:
	_reduced.button_pressed = bool(SaveManager.get_setting("grossness/reduced", false))
	_sprint_toggle.button_pressed = bool(SaveManager.get_setting("controls/sprint_toggle", false))
	_mute.button_pressed = bool(SaveManager.get_setting("audio/mute", false))
	_sensitivity.value = float(SaveManager.get_setting("camera/sensitivity", 1.0))
	_quality.select(int(SaveManager.get_setting("quality/level", 1)))
