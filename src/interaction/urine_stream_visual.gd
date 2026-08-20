class_name UrineStreamVisual
extends MeshInstance3D
## Ribbon visual for the active stream. Re-samples the same arc shape as the
## controller (pure visual — hits always come from raycasts). Translucent
## yellow; reduced-grossness mode lowers opacity and desaturates.

const SOLVER_GRAVITY: float = UrineArcSolver.STYLIZED_GRAVITY

@export var controller_path: NodePath
@export var sample_count: int = 14
@export var radius: float = 0.016
@export var reduced_grossness: bool = false

var _controller: UrineController
var _mesh: ArrayMesh
var _material: StandardMaterial3D
var _built: bool = false


func _ready() -> void:
	_controller = get_node_or_null(controller_path) as UrineController
	_mesh = ArrayMesh.new()
	mesh = _mesh
	_material = StandardMaterial3D.new()
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = Color(1.0, 0.92, 0.45, 0.62)
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = _material
	visible = false


func _process(_delta: float) -> void:
	if _controller == null or not is_instance_valid(_controller):
		visible = false
		return
	visible = _controller.is_streaming
	if not visible:
		return
	_apply_material_tuning()
	var origin: Vector3 = _controller.global_position
	var aim: Vector3 = _controller.current_aim_direction()
	var speed: float = _controller.solver.speed
	var range_max: float = _controller.solver.range_max
	var flight: float = range_max / speed
	_rebuild_ribbon(origin, aim, speed, flight)


func _apply_material_tuning() -> void:
	if _material == null:
		return
	if reduced_grossness:
		_material.albedo_color = Color(0.95, 0.95, 0.8, 0.30)
	else:
		_material.albedo_color = Color(1.0, 0.92, 0.45, 0.62)


func _rebuild_ribbon(origin: Vector3, aim: Vector3, speed: float, flight: float) -> void:
	_mesh.clear_surfaces()
	var points: PackedVector3Array = []
	for i in sample_count + 1:
		var t: float = flight * float(i) / float(sample_count)
		var p: Vector3 = origin + aim.normalized() * (speed * t)
		p.y -= 0.5 * SOLVER_GRAVITY * t * t
		points.append(p)
	if points.size() < 2:
		return
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for i in points.size():
		var tangent := (points[i + 1] - points[i]).normalized() if i < points.size() - 1 else (points[i] - points[i - 1]).normalized()
		var side := tangent.cross(Vector3.UP)
		if side.length_squared() < 0.0001:
			side = Vector3.RIGHT
		side = side.normalized() * radius
		vertices.append(points[i] + side)
		vertices.append(points[i] - side)
	for i in points.size() - 1:
		var base := i * 2
		indices.append(base)
		indices.append(base + 1)
		indices.append(base + 2)
		indices.append(base + 1)
		indices.append(base + 3)
		indices.append(base + 2)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
