class_name MarkController
extends CharacterBody3D
## Camera-relative third-person locomotion for Mark. Movement intent comes
## from an InputFrame built by the InputRouter; everything here is
## deterministic so it can be driven headlessly in tests.

@export var movement: MovementSettings
@export var camera_yaw_pivot: Node3D
@export var input_router_path: NodePath = ^"../../Gameplay/InputRouter"

var _router: InputRouter
var _moving: bool = false


func _ready() -> void:
	_router = get_node_or_null(input_router_path)
	if _router == null:
		# Fallback: find an InputRouter anywhere in the tree.
		var group := get_tree().get_nodes_in_group("input_router")
		if not group.is_empty():
			_router = group[0] as InputRouter
	if movement == null:
		movement = MovementSettings.new()


func current_horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func _physics_process(delta: float) -> void:
	var frame: InputFrame = _router.last_frame() if _router != null else InputFrame.new()

	var target_speed: float = movement.sprint_speed if frame.sprint_held else movement.walk_speed
	var target_velocity := _camera_relative_flat(frame.move) * target_speed

	var blend_rate: float = movement.acceleration if frame.move.length_squared() > 0.01 else movement.deceleration
	var flat_velocity := Vector3(velocity.x, 0.0, velocity.z)
	flat_velocity = flat_velocity.move_toward(target_velocity, blend_rate * delta)

	if not is_on_floor():
		velocity.y -= movement.gravity * delta
	else:
		velocity.y = -0.5  # keep grounded contact

	velocity.x = flat_velocity.x
	velocity.z = flat_velocity.z
	move_and_slide()

	_moving = frame.move.length_squared() > 0.01


func is_moving() -> bool:
	return _moving


func _camera_relative_flat(move: Vector2) -> Vector3:
	var forward: Vector3
	var right: Vector3
	if camera_yaw_pivot != null and is_instance_valid(camera_yaw_pivot):
		forward = -camera_yaw_pivot.global_transform.basis.z
		right = camera_yaw_pivot.global_transform.basis.x
	else:
		forward = -global_transform.basis.z
		right = global_transform.basis.x
	forward.y = 0.0
	right.y = 0.0
	if forward.length_squared() < 0.001:
		return Vector3.ZERO
	forward = forward.normalized()
	right = right.normalized()
	return (forward * -move.y + right * move.x).normalized()
