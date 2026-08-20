class_name ChunkStreamer
extends Node3D
## Streams the OSM-derived city chunks. Chunks are 80 m GLBs in chunk-local
## coordinates (origin at the chunk's min corner), so a chunk named
## chunk_CX_CZ is placed at world position (CX*80, 0, CZ*80). Keeps the
## chunks around the target loaded and unloads the rest.

const CHUNK_SIZE: float = 80.0
const SCAN_INTERVAL: float = 0.5

@export var chunk_dir: String = "res://assets/models/world/chunks"
@export var load_radius: int = 1
@export var unload_radius: int = 2
@export var target_path: NodePath
@export var generate_collision: bool = true

signal chunk_loaded(chunk_name: String)
signal chunk_unloaded(chunk_name: String)

var loaded_chunks: Dictionary = {}  # "CX_CZ" -> Node3D

var _target: Node3D
var _all_chunks: PackedStringArray = PackedStringArray()
var _scan_timer: float = 0.0
var _last_chunk: Vector2i = Vector2i(99999, 99999)


func _ready() -> void:
	_target = get_node_or_null(target_path) as Node3D
	_discover_chunks()


func chunk_count_loaded() -> int:
	return loaded_chunks.size()


func _discover_chunks() -> void:
	_all_chunks = PackedStringArray()
	var dir := DirAccess.open(chunk_dir)
	if dir == null:
		push_warning("ChunkStreamer: cannot open %s" % chunk_dir)
		return
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if file.begins_with("chunk_") and file.ends_with(".glb"):
			_all_chunks.append(file.get_basename())
		file = dir.get_next()
	dir.list_dir_end()


func _process(delta: float) -> void:
	_scan_timer -= delta
	if _scan_timer > 0.0:
		return
	_scan_timer = SCAN_INTERVAL
	_update_streaming()


func current_chunk() -> Vector2i:
	var pos := _target.global_position
	return Vector2i(floori(pos.x / CHUNK_SIZE), floori(pos.z / CHUNK_SIZE))


func _update_streaming() -> void:
	if _target == null or not is_instance_valid(_target):
		_target = get_node_or_null(target_path) as Node3D
	if _target == null:
		return
	var center := current_chunk()
	for chunk in _all_chunks:
		var coord := _chunk_name_to_coord(chunk)
		var distance := maxi(absi(coord.x - center.x), absi(coord.y - center.y))
		if distance <= load_radius and not loaded_chunks.has(chunk):
			_load_chunk(chunk, coord)
		elif distance > unload_radius and loaded_chunks.has(chunk):
			_unload_chunk(chunk)


func _chunk_name_to_coord(chunk_name: String) -> Vector2i:
	# chunk_CX_CZ -> (CX, CZ)
	var parts := chunk_name.split("_")
	if parts.size() != 3:
		return Vector2i(0, 0)
	return Vector2i(int(parts[1]), int(parts[2]))


func _load_chunk(chunk_name: String, coord: Vector2i) -> void:
	var path := "%s/%s.glb" % [chunk_dir, chunk_name]
	if not ResourceLoader.exists(path):
		return
	var scene: PackedScene = load(path)
	if scene == null:
		push_warning("ChunkStreamer: failed to load %s" % path)
		return
	var chunk := scene.instantiate() as Node3D
	add_child(chunk)
	chunk.position = Vector3(coord.x * CHUNK_SIZE, 0.0, coord.y * CHUNK_SIZE)
	if generate_collision:
		_add_collision_for(chunk)
	loaded_chunks[chunk_name] = chunk
	chunk_loaded.emit(chunk_name)


func _add_collision_for(chunk: Node3D) -> void:
	# Prefer the dedicated low-poly 'collision' mesh when present.
	var collision_mesh: MeshInstance3D
	for child in chunk.get_children():
		if child is MeshInstance3D and "collision" in child.name.to_lower():
			collision_mesh = child
			break
	if collision_mesh == null:
		for child in chunk.get_children():
			if child is MeshInstance3D:
				collision_mesh = child
				break
	if collision_mesh == null or collision_mesh.mesh == null:
		return
	var body := StaticBody3D.new()
	body.name = "ChunkCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	chunk.add_child(body)
	var shape := CollisionShape3D.new()
	shape.shape = collision_mesh.mesh.create_trimesh_shape()
	body.add_child(shape)


func _unload_chunk(chunk_name: String) -> void:
	var chunk: Node3D = loaded_chunks.get(chunk_name)
	if chunk != null and is_instance_valid(chunk):
		chunk.queue_free()
	loaded_chunks.erase(chunk_name)
	chunk_unloaded.emit(chunk_name)
