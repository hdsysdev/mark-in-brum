class_name FlatNavRegion
extends NavigationRegion3D
## Flat rectangular navigation region. For the open city floor and for
## headless tests. Built via create_from_mesh (canonical valid polygon
## data) so no editor bake is required.

@export var size: Vector2 = Vector2(200.0, 200.0)
@export var cell_size: float = 0.5
@export var agent_radius: float = 0.45


func _ready() -> void:
	var nav_mesh := NavigationMesh.new()
	nav_mesh.cell_size = cell_size
	nav_mesh.agent_radius = agent_radius
	var plane := PlaneMesh.new()
	plane.size = size
	nav_mesh.create_from_mesh(plane)
	navigation_mesh = nav_mesh
