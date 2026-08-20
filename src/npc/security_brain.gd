class_name SecurityBrain
extends Node
## Adult city-centre security. Patrols at low attention, investigates at
## SECURITY_ALERT, chases at PURSUIT, and captures by proximity. Emits
## guard_sighted so the AttentionSystem can hold/increase alert while Mark
## is being watched.

signal guard_sighted(mark_position: Vector3)
signal guard_lost_track

enum Mode { PATROL, ALERT, CHASE, CAPTURE }

@export var walk_speed: float = 2.2
@export var chase_speed: float = 4.4
@export var sight_range: float = 15.0
@export var capture_range: float = 1.25
@export var capture_hold_seconds: float = 1.0
@export var patrol_points: Array[Vector3] = []
@export var mark_path: NodePath
@export var attention_system_path: NodePath

var mode: int = Mode.PATROL

var _body: CharacterBody3D
var _agent: NavigationAgent3D
var _mark: Node3D
var _attention: AttentionSystem
var _patrol_index: int = 0
var _last_seen: Vector3 = Vector3.ZERO
var _capture_timer: float = 0.0
var _sight_timer: float = 0.0
var _target_timer: float = 0.0
var _last_target: Vector3 = Vector3.ZERO


func _ready() -> void:
	_body = get_parent() as CharacterBody3D
	_agent = get_node_or_null("../Feet/NavigationAgent3D") as NavigationAgent3D
	_mark = get_node_or_null(mark_path) as Node3D
	_attention = get_node_or_null(attention_system_path) as AttentionSystem
	if _attention != null:
		if not _attention.attention_changed.is_connected(_on_attention_changed):
			_attention.attention_changed.connect(_on_attention_changed)
		if not GameEvents.player_captured.is_connected(_on_player_captured):
			GameEvents.player_captured.connect(_on_player_captured)


func _exit_tree() -> void:
	if _attention != null and _attention.attention_changed.is_connected(_on_attention_changed):
		_attention.attention_changed.disconnect(_on_attention_changed)
	if GameEvents.player_captured.is_connected(_on_player_captured):
		GameEvents.player_captured.disconnect(_on_player_captured)


func _on_attention_changed(_value: float, tier: String) -> void:
	if mode == Mode.CAPTURE:
		return
	match tier:
		"PURSUIT":
			if mode != Mode.CHASE:
				mode = Mode.CHASE
				if _mark != null:
					_last_seen = _mark.global_position
		"SECURITY_ALERT":
			if mode == Mode.PATROL:
				mode = Mode.ALERT
				if _mark != null:
					_last_seen = _mark.global_position
		"CALM":
			mode = Mode.PATROL
			_last_seen = Vector3.ZERO


func _on_player_captured() -> void:
	mode = Mode.PATROL
	_capture_timer = 0.0


func _physics_process(delta: float) -> void:
	if _mark == null or _body == null:
		return
	_sight_timer -= delta
	var distance := _body.global_position.distance_to(_mark.global_position)
	if distance < sight_range:
		if _sight_timer <= 0.0:
			_sight_timer = 0.5
			guard_sighted.emit(_mark.global_position)
		_last_seen = _mark.global_position
	elif distance > sight_range * 1.5:
		guard_lost_track.emit()

	match mode:
		Mode.PATROL:
			_patrol(delta)
		Mode.ALERT:
			_investigate(delta)
		Mode.CHASE:
			_chase(delta)
		Mode.CAPTURE:
			_capture(delta)


func _patrol(delta: float) -> void:
	if patrol_points.is_empty():
		stop_moving()
		return
	var target := _body.global_position + patrol_points[_patrol_index]
	if navigate_to(target, walk_speed, delta):
		_patrol_index = (_patrol_index + 1) % patrol_points.size()


func _investigate(delta: float) -> void:
	if _last_seen == Vector3.ZERO:
		mode = Mode.PATROL
		return
	if navigate_to(_last_seen, walk_speed, delta):
		# Searched the area, nothing found.
		guard_lost_track.emit()
		_last_seen = Vector3.ZERO
		mode = Mode.PATROL


func _chase(delta: float) -> void:
	if _mark == null:
		return
	var target := _mark.global_position
	# Re-target only when Mark moved meaningfully or on an interval, so the
	# async path computation is not invalidated every single frame.
	_target_timer -= delta
	if _target_timer <= 0.0 or _last_target.distance_to(target) > 1.0:
		_target_timer = 0.25
		_last_target = target
		_agent.target_position = target
	navigate_to(target, chase_speed, delta)
	if _body.global_position.distance_to(target) <= capture_range:
		mode = Mode.CAPTURE
		_capture_timer = 0.0


func _capture(delta: float) -> void:
	stop_moving()
	var distance := _body.global_position.distance_to(_mark.global_position)
	if distance > capture_range * 1.5:
		mode = Mode.CHASE
		_capture_timer = 0.0
		return
	_capture_timer += delta
	if _capture_timer >= capture_hold_seconds:
		GameEvents.player_captured.emit()


func navigate_to(target: Vector3, speed: float, delta: float) -> bool:
	if _agent == null or _body == null:
		return false
	var flat := target - _body.global_position
	flat.y = 0.0
	if flat.length() <= 0.9:
		stop_moving()
		return true
	if _agent.is_navigation_finished():
		return true
	var next := _agent.get_next_path_position()
	var dir := next - _body.global_position
	dir.y = 0.0
	if dir.length() > 0.9:
		_body.velocity.x = dir.normalized().x * speed
		_body.velocity.z = dir.normalized().z * speed
	else:
		_body.velocity.x = 0.0
		_body.velocity.z = 0.0
	if not _body.is_on_floor():
		_body.velocity.y -= 22.0 * delta
	_body.move_and_slide()
	return false


func stop_moving() -> void:
	if _body != null:
		_body.velocity.x = 0.0
		_body.velocity.z = 0.0
