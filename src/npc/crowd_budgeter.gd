class_name CrowdBudgeter
extends Node3D
## Spawns and throttles the civilian crowd. Staggers brain think ticks
## across frames and disables processing for civilians outside simulation
## range so the mobile budget stays intact.

signal civilian_spawned(npc: Node)

const CIVILIAN_SCENE := preload("res://scenes/npc/civilian.tscn")

@export var spawn_count: int = 12
@export var max_nearby_simulated: int = 12
@export var simulation_range: float = 40.0
@export var spawn_director_path: NodePath
@export var archetype_paths: Array[String] = [
	"res://data/npc/archetypes/commuter.tres",
	"res://data/npc/archetypes/shopper.tres",
	"res://data/npc/archetypes/stallholder.tres",
	"res://data/npc/archetypes/student.tres",
]

var _civilians: Array[Node] = []
var _spawn_director: SpawnDirector
var _mark: Node3D
var _seed_counter: int = 1000


func _ready() -> void:
	_spawn_director = get_node_or_null(spawn_director_path) as SpawnDirector
	var group := get_tree().get_nodes_in_group("mark")
	_mark = group[0] as Node3D if not group.is_empty() else null
	for i in spawn_count:
		_spawn_civilian(i)


func civilian_count() -> int:
	return _civilians.size()


func _spawn_civilian(index: int) -> void:
	var civilian := CIVILIAN_SCENE.instantiate()
	add_child(civilian)
	if _spawn_director != null:
		civilian.global_position = _spawn_director.point_for(index)
	else:
		civilian.global_position = Vector3(float(index) * 1.5 - 6.0, 0.4, 4.0)
	var brain: NPCBrain = civilian.get_node("Brain")
	brain.rng_seed = _seed_counter + index
	if archetype_paths.size() > 0:
		var archetype: NPCArchetype = load(archetype_paths[index % archetype_paths.size()])
		brain.walk_speed = archetype.walk_speed
		brain.reaction_data = archetype.reaction_data
		var mesh: MeshInstance3D = civilian.get_node("Mesh")
		var palette := archetype.palette
		var material := StandardMaterial3D.new()
		material.albedo_color = palette
		material.roughness = 0.85
		mesh.material_override = material
	# Ambient waypoints around the spawn point.
	var waypoints: Array[Vector3] = []
	for i in 4:
		var angle := float(i) / 4.0 * TAU
		waypoints.append(civilian.global_position + Vector3(cos(angle) * 6.0, 0.0, sin(angle) * 6.0))
	brain.waypoints = waypoints
	brain.simulation_range = simulation_range
	_civilians.append(civilian)
	civilian_spawned.emit(civilian)


func _physics_process(delta: float) -> void:
	# Staggered think ticks + distance throttling.
	for civilian in _civilians:
		if not is_instance_valid(civilian):
			continue
		var brain: NPCBrain = civilian.get_node_or_null("Brain")
		if brain == null:
			continue
		var far: bool = _mark == null or brain.distance_to_mark() > simulation_range
		if far:
			civilian.set_physics_process(false)
			civilian.visible = false
			continue
		civilian.set_physics_process(true)
		civilian.visible = true
		brain.tick_think(delta)
