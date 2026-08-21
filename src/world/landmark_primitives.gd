class_name LandmarkPrimitives
extends RefCounted
## Small, allocation-light procedural building blocks for the city art pass.
## Every mesh is primitive or a compact generated surface; no external asset
## files are required at runtime.


static func box(
	parent: Node3D,
	node_name: String,
	size: Vector3,
	position: Vector3,
	material: Material,
	rotation: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	instance.rotation = rotation
	parent.add_child(instance)
	return instance


static func cylinder(
	parent: Node3D,
	node_name: String,
	radius: float,
	height: float,
	position: Vector3,
	material: Material,
	top_radius: float = -1.0,
	segments: int = 12
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	parent.add_child(instance)
	return instance


static func sphere(
	parent: Node3D,
	node_name: String,	radius: float,
	position: Vector3,
	scale: Vector3,
	material: Material
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	instance.scale = scale
	parent.add_child(instance)
	return instance


static func cone(
	parent: Node3D,
	node_name: String,
	base_radius: float,
	height: float,
	position: Vector3,
	material: Material,
	segments: int = 8
) -> MeshInstance3D:
	return cylinder(parent, node_name, base_radius, height, position, material, 0.0, segments)


static func triangular_prism(
	parent: Node3D,
	node_name: String,
	width: float,
	depth: float,
	height: float,
	position: Vector3,
	material: Material
) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	var half_width := width * 0.5
	var half_depth := depth * 0.5
	var front_left := Vector3(-half_width, 0.0, -half_depth)
	var front_right := Vector3(half_width, 0.0, -half_depth)
	var front_peak := Vector3(0.0, height, -half_depth)
	var back_left := Vector3(-half_width, 0.0, half_depth)
	var back_right := Vector3(half_width, 0.0, half_depth)
	var back_peak := Vector3(0.0, height, half_depth)

	# Front and back gables.
	surface.add_vertex(front_left)
	surface.add_vertex(front_right)
	surface.add_vertex(front_peak)
	surface.add_vertex(back_right)
	surface.add_vertex(back_left)
	surface.add_vertex(back_peak)
	# Left slope, right slope, and two base faces.
	_add_triangle(surface, front_left, back_left, back_peak)
	_add_triangle(surface, front_left, back_peak, front_peak)
	_add_triangle(surface, front_right, front_peak, back_peak)
	_add_triangle(surface, front_right, back_peak, back_right)
	_add_triangle(surface, front_left, front_right, back_right)
	_add_triangle(surface, front_left, back_right, back_left)
	surface.generate_normals()
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = surface.commit()
	instance.position = position
	parent.add_child(instance)
	return instance


static func curved_wall(
	parent: Node3D,
	node_name: String,
	radius: float,
	thickness: float,
	angle_start: float,
	angle_end: float,
	height: float,
	segments: int,
	material: Material
) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	var inner_radius := radius - thickness
	for index in range(segments):
		var t0 := float(index) / float(segments)
		var t1 := float(index + 1) / float(segments)
		var a0 := lerpf(angle_start, angle_end, t0)
		var a1 := lerpf(angle_start, angle_end, t1)
		var outer_bottom_0 := _arc_point(radius, a0, 0.0)
		var outer_top_0 := _arc_point(radius, a0, height)
		var outer_bottom_1 := _arc_point(radius, a1, 0.0)
		var outer_top_1 := _arc_point(radius, a1, height)
		var inner_bottom_0 := _arc_point(inner_radius, a0, 0.0)
		var inner_top_0 := _arc_point(inner_radius, a0, height)
		var inner_bottom_1 := _arc_point(inner_radius, a1, 0.0)
		var inner_top_1 := _arc_point(inner_radius, a1, height)

		# Outer and inner curved faces.
		_add_triangle(surface, outer_bottom_0, outer_top_0, outer_top_1)
		_add_triangle(surface, outer_bottom_0, outer_top_1, outer_bottom_1)
		_add_triangle(surface, inner_bottom_1, inner_top_1, inner_top_0)
		_add_triangle(surface, inner_bottom_1, inner_top_0, inner_bottom_0)
		# Top cap, enough to keep the silhouette clean at mobile distance.
		_add_triangle(surface, outer_top_0, inner_top_0, inner_top_1)
		_add_triangle(surface, outer_top_0, inner_top_1, outer_top_1)
	surface.generate_normals()
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = surface.commit()
	parent.add_child(instance)
	return instance


static func multimesh(
	parent: Node3D,
	node_name: String,
	mesh: Mesh,
	transforms: Array[Transform3D],
	material: Material
) -> MultiMeshInstance3D:
	var multi_mesh := MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.mesh = mesh
	multi_mesh.instance_count = transforms.size()
	for index in range(transforms.size()):
		multi_mesh.set_instance_transform(index, transforms[index])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multi_mesh
	instance.material_override = material
	parent.add_child(instance)
	return instance


static func label(
	parent: Node3D,
	node_name: String,
	text_value: String,
	position: Vector3,
	color: Color = Color.WHITE,
	pixel_size: float = 0.018
) -> Label3D:
	var label_3d := Label3D.new()
	label_3d.name = node_name
	label_3d.text = text_value
	label_3d.font_size = 64
	label_3d.pixel_size = pixel_size * 1.45
	label_3d.outline_size = 12
	label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label_3d.modulate = color
	label_3d.position = position
	parent.add_child(label_3d)
	return label_3d


static func _arc_point(radius: float, angle: float, height: float) -> Vector3:
	return Vector3(sin(angle) * radius, height, cos(angle) * radius)


static func _add_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)
