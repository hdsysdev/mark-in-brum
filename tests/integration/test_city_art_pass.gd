extends GutTest
## Birmingham art-pass contract: all six landmark families remain addressable
## as named, lightweight scene nodes, with route anchors matching the existing
## condensed city-centre navigation targets.

const CITY_SCENE: String = "res://scenes/world/city_centre.tscn"

const LANDMARKS: Array[String] = [
	"GrandCentralNewStreet",
	"VictoriaSquareTownHall",
	"CouncilHouseChamberlainSquare",
	"BullringFacade",
	"StMartinInTheBullRing",
	"Rotunda",
]


func test_birmingham_landmark_families_are_present() -> void:
	var city := (load(CITY_SCENE) as PackedScene).instantiate()
	add_child_autofree(city)
	await wait_process_frames(2, "let landmark art assemble")
	var art := city.get_node_or_null("LandmarkArt")
	assert_not_null(art, "city must expose the LandmarkArt root")
	for landmark_name in LANDMARKS:
		var landmark := art.get_node_or_null(landmark_name)
		assert_not_null(landmark, "%s landmark must exist" % landmark_name)
		assert_true(landmark.is_in_group("landmark"), "%s must be tagged as a landmark" % landmark_name)
		assert_true(landmark.has_meta("landmark_id"), "%s must expose a stable id" % landmark_name)


func test_landmark_anchors_match_condensed_route() -> void:
	var city := (load(CITY_SCENE) as PackedScene).instantiate()
	add_child_autofree(city)
	await wait_process_frames(2, "let landmark art assemble")
	var art := city.get_node("LandmarkArt")
	assert_eq(art.get_node("GrandCentralNewStreet").position, Vector3(28.0, 0.0, -105.0))
	assert_eq(art.get_node("VictoriaSquareTownHall").position, Vector3(-250.0, 0.0, -150.0))
	assert_eq(art.get_node("CouncilHouseChamberlainSquare").position, Vector3(-204.0, 0.0, -230.0))
	assert_eq(art.get_node("BullringFacade").position, Vector3(420.0, 0.0, 80.0))
	assert_eq(art.get_node("StMartinInTheBullRing").position, Vector3(362.0, 0.0, 61.0))
	assert_eq(art.get_node("Rotunda").position, Vector3(230.0, 0.0, -65.0))


func test_licensed_assets_and_collision_proxies_are_integrated() -> void:
	var city := (load(CITY_SCENE) as PackedScene).instantiate()
	add_child_autofree(city)
	await wait_process_frames(3, "let imported assets and collisions assemble")
	var art := city.get_node("LandmarkArt")
	var dressing := art.get_node_or_null("LicensedAssetDressing")
	assert_not_null(dressing, "the playable city must include the licensed asset dressing root")
	assert_eq(dressing.get_meta("license", ""), "CC0-1.0")
	assert_gte(get_tree().get_nodes_in_group("licensed_city_asset").size(), 40, "commercial, road, and vehicle assets must be instantiated")
	assert_gte(get_tree().get_nodes_in_group("city_collision").size(), 20, "landmarks and large dressing assets need coarse collision proxies")
	var first_asset := get_tree().get_nodes_in_group("licensed_city_asset")[0]
	assert_true(first_asset.has_meta("source_path"), "runtime assets must expose provenance")


func test_generated_landmark_faces_point_outward_for_godot_culling() -> void:
	var city := (load(CITY_SCENE) as PackedScene).instantiate()
	add_child_autofree(city)
	await wait_process_frames(3, "let procedural meshes assemble")
	var art := city.get_node("LandmarkArt")

	# Godot treats clockwise triangles as front-facing. These generated normals
	# prove the visible exterior faces point outward rather than relying on node
	# presence alone.
	var pediment := art.get_node("VictoriaSquareTownHall/TownHallPediment") as MeshInstance3D
	var pediment_arrays := pediment.mesh.surface_get_arrays(0)
	var pediment_normals: PackedVector3Array = pediment_arrays[Mesh.ARRAY_NORMAL]
	assert_lt(pediment_normals[0].z, -0.6, "pediment front must face the approach camera")
	assert_gt(pediment_normals[3].z, 0.6, "pediment back must face away from the approach camera")

	var facade := art.get_node("BullringFacade/BullringCurvedDiscFacade") as MeshInstance3D
	var facade_arrays := facade.mesh.surface_get_arrays(0)
	var facade_vertices: PackedVector3Array = facade_arrays[Mesh.ARRAY_VERTEX]
	var facade_normals: PackedVector3Array = facade_arrays[Mesh.ARRAY_NORMAL]
	var outer_radial := Vector3(facade_vertices[0].x, 0.0, facade_vertices[0].z).normalized()
	var inner_radial := Vector3(facade_vertices[6].x, 0.0, facade_vertices[6].z).normalized()
	assert_gt(facade_normals[0].dot(outer_radial), 0.8, "curved outer wall must face outward")
	assert_lt(facade_normals[6].dot(inner_radial), -0.8, "curved inner wall must face inward")
	assert_gt(facade_normals[12].y, 0.7, "curved wall top cap must face upward")
