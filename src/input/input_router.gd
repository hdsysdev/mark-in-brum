class_name InputRouter
extends Node
## Merges every input source (keyboard, mouse, touch widgets) into one
## normalized InputFrame per physics tick. Touch widgets call the set_/add_
## methods; keyboard/mouse are read from the Input singleton. Gameplay code
## only ever sees InputFrame.

signal frame_built(frame: InputFrame)

@export var deadzone: float = 0.2
@export var look_sensitivity: float = 1.0
@export var look_invert_y: bool = false

# --- Touch/widget sources (written by UI widgets) ---
var joystick_vector: Vector2 = Vector2.ZERO
var touch_sprint_held: bool = false
var touch_action_held: bool = false
var touch_recenter_pressed: bool = false
var touch_pause_pressed: bool = false

var _accumulated_look: Vector2 = Vector2.ZERO
var _last_frame: InputFrame = InputFrame.new()


func _physics_process(_delta: float) -> void:
	# Build exactly one frame per physics tick so every consumer
	# (controller, camera, UI) reads consistent, fresh input state.
	build_frame()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_accumulated_look += event.relative


func build_frame() -> InputFrame:
	var frame := InputFrame.new()

	# Move: keyboard axes + joystick, clamped to unit circle, dead-zoned.
	var keyboard_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var combined: Vector2 = keyboard_vector + joystick_vector
	if combined.length() > 1.0:
		combined = combined.normalized()
	if combined.length() < deadzone:
		combined = Vector2.ZERO
	frame.move = combined

	# Look: mouse + touch deltas. build_frame() leaves the accumulation
	# intact so the camera can consume it once per rendered frame via
	# consume_look_delta(); tests may inspect it through the frame too.
	var look := _accumulated_look
	look.y *= -1.0 if look_invert_y else 1.0
	frame.look_delta = look * look_sensitivity

	frame.sprint_held = Input.is_action_pressed("sprint") or touch_sprint_held
	frame.action_held = Input.is_action_pressed("action") or touch_action_held
	frame.recenter_pressed = Input.is_action_just_pressed("recenter") or touch_recenter_pressed
	frame.pause_pressed = Input.is_action_just_pressed("pause") or touch_pause_pressed
	touch_recenter_pressed = false
	touch_pause_pressed = false

	_last_frame = frame
	frame_built.emit(frame)
	return frame


func last_frame() -> InputFrame:
	return _last_frame


func consume_look_delta() -> Vector2:
	var look := _accumulated_look
	_accumulated_look = Vector2.ZERO
	look.y *= -1.0 if look_invert_y else 1.0
	return look * look_sensitivity


func add_look_delta(delta: Vector2) -> void:
	_accumulated_look += delta


func press_recenter() -> void:
	touch_recenter_pressed = true


func press_pause() -> void:
	touch_pause_pressed = true


func clear_all_touch_state() -> void:
	joystick_vector = Vector2.ZERO
	touch_sprint_held = false
	touch_action_held = false
	touch_recenter_pressed = false
	touch_pause_pressed = false
	_accumulated_look = Vector2.ZERO
