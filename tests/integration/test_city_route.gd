extends GutTest
## City assembly contract: the chunk streamer loads OSM-derived chunks
## around the target with collision, the flat navigation surface connects
## the route points, and the world bounds contain the target.

const CITY_SCENE: String = "res://scenes/world/city_centre.tscn"


func test_city_scene_loads_with_nav_and_spawns() -> void:
	var city := (load(CITY_SCENE) as PackedScene).instantiate()
	add_child_autofree(city)
	await wait_process_frames(3, "let city scene ready")
	var spawn: SpawnDirector = city.get_node("SpawnDirector")
	assert_not_null(spawn, "SpawnDirector must exist")
	assert_gte(spawn.spawn_points.size(), 10, "district spawn points must cover the loop")
	var nav: FlatNavRegion = city.get_node("Navigation")
	assert_not_null(nav, "Navigation must exist")
	assert_true(nav.navigation_mesh.get_polygon_count() > 0, "navmesh must have polygons")


func test_streamer_loads_chunks_around_target_with_collision() -> void:
	var city := (load(CITY_SCENE) as PackedScene).instantiate()
	add_child_autofree(city)
	var target := Node3D.new()
	target.position = Vector3(0.0, 0.0, 0.0)
	city.add_child(target)
	var streamer: ChunkStreamer = city.get_node("ChunkStreamer")
	streamer.target_path = NodePath(target.get_path())
	await wait_process_frames(5, "let streamer scan")
	assert_gt(streamer.chunk_count_loaded(), 0,
		"chunks must stream in around the New Street origin")
	# Every loaded chunk must have generated collision.
	var chunks := streamer.loaded_chunks.values()
	var collision_count := 0
	for chunk in chunks:
		if chunk.get_node_or_null("ChunkCollision") != null:
			collision_count += 1
	assert_eq(collision_count, chunks.size(), "every loaded chunk must have collision")
	streamer.queue_free()
	city.queue_free()


func test_navigation_connects_spawn_to_bullring_and_victoria_square() -> void:
	var city := (load(CITY_SCENE) as PackedScene).instantiate()
	add_child_autofree(city)
	await wait_physics_frames(10, "let navigation sync")
	var nav: FlatNavRegion = city.get_node("Navigation")
	var map := nav.get_world_3d().navigation_map
	# Spawn (New Street) -> Bullring/St Martin's direction (east).
	var to_bullring := NavigationServer3D.map_get_path(
		map, Vector3(0.0, 0.1, 0.0), Vector3(420.0, 0.1, 80.0), true)
	assert_gt(to_bullring.size(), 0, "spawn and Bullring must be connected")
	# Spawn -> Victoria Square direction (west).
	var to_victoria := NavigationServer3D.map_get_path(
		map, Vector3(0.0, 0.1, 0.0), Vector3(-250.0, 0.1, -150.0), true)
	assert_gt(to_victoria.size(), 0, "spawn and Victoria Square must be connected")


func test_world_bounds_contain_target() -> void:
	var bounds := WorldBounds.new()
	add_child_autofree(bounds)
	bounds.center = Vector2.ZERO
	bounds.half_extent = Vector2(100.0, 100.0)
	var target := Node3D.new()
	target.position = Vector3(300.0, 0.0, 50.0)
	add_child_autofree(target)
	bounds.target_path = NodePath(target.get_path())
	bounds._ready()
	await wait_physics_frames(3, "let bounds clamp")
	assert_eq(target.global_position.x, 100.0, "target must be clamped to the east edge")
	assert_eq(target.global_position.z, 50.0)
	assert_true(bounds.is_inside(Vector3(0.0, 0.0, 0.0)))
	assert_false(bounds.is_inside(Vector3(200.0, 0.0, 0.0)))
