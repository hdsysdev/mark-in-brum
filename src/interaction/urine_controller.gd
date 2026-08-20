class_name UrineController
extends Node3D
## Hold-to-stream interaction. Reads hold intent from the InputRouter,
## samples the arc through the physics space state, and emits typed hit
## signals. Gameplay reacts to signals; this node never touches the visual
## effects directly (EffectsRoot listens).

signal target_sprayed(target: Node, hit: UrineHit)
signal surface_sprayed(hit: UrineHit)
signal stream_state_changed(active: bool)

@export var hold_to_start_seconds: float = 0.15
@export var max_stream_seconds: float = 12.0
@export var recharge_seconds: float = 5.0
@export var per_target_cooldown_seconds: float = 1.6
@export var surface_hit_interval_seconds: float = 0.35
@export var reduced_grossness: bool = false
@export var aim_override: Node3D
@export var input_router_path: NodePath = ^"../../Gameplay/InputRouter"
@export var exclude_path: NodePath = ^".."

var solver: UrineArcSolver = UrineArcSolver.new()
var is_streaming: bool = false
var recharge_fraction: float = 1.0

var _router: InputRouter
var _hold_time: float = 0.0
var _stream_elapsed: float = 0.0
var _recharge_remaining: float = 0.0
var _surface_hit_timer: float = 0.0
var _target_cooldowns: Dictionary = {}
var _exclude_body: PhysicsBody3D
var _last_aim: Vector3 = Vector3.FORWARD


func _ready() -> void:
	reduced_grossness = bool(SaveManager.get_setting("grossness/reduced", false))
	_router = get_node_or_null(input_router_path)
	if _router == null:
		var group := get_tree().get_nodes_in_group("input_router")
		if not group.is_empty():
			_router = group[0] as InputRouter
	_exclude_body = get_node_or_null(exclude_path) as PhysicsBody3D


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	var frame: InputFrame = _router.last_frame() if _router != null else InputFrame.new()

	if frame.action_held and _recharge_remaining <= 0.0:
		_hold_time += delta
		if not is_streaming and _hold_time >= hold_to_start_seconds:
			_begin_stream()
	else:
		_hold_time = 0.0
		if is_streaming:
			_stop_stream()

	if is_streaming:
		_stream_elapsed += delta
		_sample_stream()
		if _stream_elapsed >= max_stream_seconds:
			_stop_stream()
			_recharge_remaining = recharge_seconds


func _begin_stream() -> void:
	is_streaming = true
	_stream_elapsed = 0.0
	stream_state_changed.emit(true)


func _stop_stream() -> void:
	is_streaming = false
	stream_state_changed.emit(false)


func _tick_timers(delta: float) -> void:
	if _recharge_remaining > 0.0:
		_recharge_remaining = maxf(0.0, _recharge_remaining - delta)
	recharge_fraction = 1.0 if recharge_seconds <= 0.0 else 1.0 - _recharge_remaining / recharge_seconds
	_surface_hit_timer = maxf(0.0, _surface_hit_timer - delta)
	var expired: Array = []
	for id: int in _target_cooldowns:
		_target_cooldowns[id] = _target_cooldowns[id] - delta
		if _target_cooldowns[id] <= 0.0:
			expired.append(id)
	for id: int in expired:
		_target_cooldowns.erase(id)


func current_aim_direction() -> Vector3:
	if aim_override != null and is_instance_valid(aim_override):
		_last_aim = -aim_override.global_transform.basis.z
		return _last_aim
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		_last_aim = -cam.global_transform.basis.z
	else:
		_last_aim = Vector3.FORWARD
	return _last_aim


func _sample_stream() -> void:
	var aim := current_aim_direction()
	solver.origin = global_position
	solver.set_aim(aim)
	var points := solver.sample_points()
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.new()
	query.collision_mask = 1 | 4  # world + NPCs
	if _exclude_body != null:
		query.exclude = [_exclude_body.get_rid()]
	var last_point := points[0]
	for i in range(1, points.size()):
		query.from = last_point
		query.to = points[i]
		var result: Dictionary = space.intersect_ray(query)
		if not result.is_empty():
			var hit := UrineHit.new()
			hit.collider = result["collider"]
			hit.position = result["position"]
			hit.normal = result["normal"]
			hit.distance = global_position.distance_to(hit.position)
			_emit_for_hit(hit)
			return
		last_point = points[i]


func _emit_for_hit(hit: UrineHit) -> void:
	var collider: Object = hit.collider
	if collider is PhysicsBody3D and (collider as PhysicsBody3D).is_in_group("npc"):
		var id := collider.get_instance_id()
		if not _target_cooldowns.has(id):
			_target_cooldowns[id] = per_target_cooldown_seconds
			target_sprayed.emit(collider, hit)
			GameEvents.target_sprayed.emit(collider, {"position": hit.position, "normal": hit.normal, "distance": hit.distance})
	elif _surface_hit_timer <= 0.0:
		_surface_hit_timer = surface_hit_interval_seconds
		surface_sprayed.emit(hit)
		GameEvents.surface_sprayed.emit({"position": hit.position, "normal": hit.normal, "distance": hit.distance})
