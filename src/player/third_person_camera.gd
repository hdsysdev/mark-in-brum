class_name ThirdPersonCamera
extends Node3D
## Collision-safe over-the-shoulder camera rig. Yaw/pitch are driven by
## look deltas consumed from the InputRouter; SpringArm3D handles wall
## avoidance; recenter returns the camera behind Mark. Framing profiles
## differ between portrait and landscape.

const MIN_PITCH: float = deg_to_rad(-72.0)
const MAX_PITCH: float = deg_to_rad(28.0)
const PITCH_SCALE: float = 0.72  # vertical look slightly slower than horizontal

@export var sensitivity_scale: float = 0.0024  # radians per look pixel
@export var shoulder_offset: Vector3 = Vector3(0.55, 0.12, 0.0)
@export var shoulder_offset_mobile: Vector3 = Vector3(0.32, 0.22, 0.0)
@export var spring_length_desktop: float = 3.4
@export var spring_length_mobile: float = 6.2
@export var default_pitch_desktop: float = -0.10
@export var default_pitch_mobile: float = -0.12
@export var fov_desktop: float = 60.0
@export var fov_mobile: float = 72.0
@export var recenter_speed: float = 8.0
@export var fade_near_distance: float = 1.1
@export var fade_alpha: float = 0.35
@export var fade_target_path: NodePath
@export var input_router_path: NodePath = ^"../../Gameplay/InputRouter"

@onready var yaw_pivot: Node3D = $YawPivot
@onready var pitch_pivot: Node3D = $YawPivot/PitchPivot
@onready var spring_arm: SpringArm3D = $YawPivot/PitchPivot/SpringArm3D
@onready var camera: Camera3D = $YawPivot/PitchPivot/SpringArm3D/Camera3D

var pitch: float = -0.10
var _router: InputRouter
var _yaw: float = 0.0
var _default_pitch: float = -0.10
var _recentering: bool = false
var _fade_target: Node3D
var _fade_material: StandardMaterial3D
var _fade_amount: float = 0.0
var _portrait: bool = false
var _bridge_timer: float = 0.0


func _ready() -> void:
	_router = get_node_or_null(input_router_path)
	if _router == null:
		var group := get_tree().get_nodes_in_group("input_router")
		if not group.is_empty():
			_router = group[0] as InputRouter
	if not fade_target_path.is_empty():
		_fade_target = get_node_or_null(fade_target_path)
		_prepare_fade_material()
	spring_arm.position = shoulder_offset
	pitch = default_pitch_desktop
	_apply_profile()
	camera.current = true
	get_viewport().size_changed.connect(_apply_profile)


func _process(delta: float) -> void:
	var frame: InputFrame = _router.last_frame() if _router != null else null
	var look: Vector2 = _router.consume_look_delta() if _router != null else Vector2.ZERO
	if frame == null:
		frame = InputFrame.new()

	_yaw -= look.x * sensitivity_scale
	pitch -= look.y * sensitivity_scale * PITCH_SCALE
	pitch = clampf(pitch, MIN_PITCH, MAX_PITCH)

	if frame.recenter_pressed:
		_recentering = true

	if _recentering:
		_yaw = move_toward(_yaw, 0.0, recenter_speed * delta)
		pitch = move_toward(pitch, _default_pitch, recenter_speed * delta)
		if absf(_yaw) < 0.001 and absf(pitch - _default_pitch) < 0.001:
			_yaw = 0.0
			pitch = _default_pitch
			_recentering = false

	yaw_pivot.rotation.y = _yaw
	pitch_pivot.rotation.x = pitch
	_update_fade(delta)
	_report_to_web_bridge(delta)


func current_yaw() -> float:
	return _yaw


func is_portrait_profile() -> bool:
	return _portrait


static func should_use_portrait_profile(viewport_size: Vector2) -> bool:
	# Web builds cannot rely on native mobile detection: Android browsers and
	# Playwright emulation may both report a desktop-like platform. The rendered
	# canvas aspect is the authoritative presentation signal.
	return viewport_size.y > viewport_size.x * 1.1


func _apply_profile() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	var viewport_size := viewport.get_visible_rect().size
	_portrait = should_use_portrait_profile(viewport_size)
	if _portrait:
		spring_arm.position = shoulder_offset_mobile
		spring_arm.spring_length = spring_length_mobile
		_default_pitch = default_pitch_mobile
		camera.fov = fov_mobile
	else:
		spring_arm.position = shoulder_offset
		spring_arm.spring_length = spring_length_desktop
		_default_pitch = default_pitch_desktop
		camera.fov = fov_desktop


func _prepare_fade_material() -> void:
	if _fade_target == null and not fade_target_path.is_empty():
		_fade_target = get_node_or_null(fade_target_path)
	if _fade_target == null:
		return
	var mesh_instance := _fade_target as MeshInstance3D
	if mesh_instance == null:
		return
	_fade_material = StandardMaterial3D.new()
	_fade_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fade_material.albedo_color = Color(0.62, 0.58, 0.52, 1.0)
	_fade_material.roughness = 0.9
	mesh_instance.material_override = _fade_material


func _update_fade(delta: float) -> void:
	if _fade_target == null or not is_instance_valid(_fade_target):
		return
	var cam_distance: float = camera.global_position.distance_to(spring_arm.global_position)
	var compressed: bool = cam_distance < spring_arm.spring_length - fade_near_distance
	var target_amount: float = 1.0 if compressed else 0.0
	_fade_amount = move_toward(_fade_amount, target_amount, delta * 10.0)
	if _fade_material != null:
		_fade_material.albedo_color.a = lerpf(1.0, fade_alpha, _fade_amount)


func _report_to_web_bridge(delta: float) -> void:
	if OS.get_name() != "Web":
		return
	_bridge_timer -= delta
	if _bridge_timer > 0.0:
		return
	_bridge_timer = 0.25
	JavaScriptBridge.eval("window.__markInBrum.camYaw = %.4f; window.__markInBrum.camPitch = %.4f;" % [_yaw, pitch])
