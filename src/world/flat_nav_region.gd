class_name FlatNavRegion
extends NavigationRegion3D
## Flat rectangular navigation region. For the open city floor and for
## headless tests. NavigationMesh polygons are supplied directly, so no
## editor bake is required.

@export var size: Vector2 = Vector2(200.0, 200.0)
@export var cell_size: float = 0.5


func _ready() -> void:
	var nav_mesh := NavigationMesh.new()
	nav_mesh.cell_size = cell_size
	var half := size * 0.5
	var vertices := PackedVector3Array([
		Vector3(-half.x, 0.0, -half.y),
		Vector3(half.x, 0.0, -half.y),
		Vector3(half.x, 0.0, half.y),
		Vector3(-half.x, 0.0, half.y),
	])
	nav_mesh.vertices = vertices
	nav_mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	navigation_mesh = nav_mesh
