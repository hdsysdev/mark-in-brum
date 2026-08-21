class_name BirminghamArtPass
extends Node3D
## Procedural, de-branded Birmingham city-centre art pass.
##
## The route anchors mirror the committed OSM-derived chunk coordinate system
## and the existing navigation tests: New Street/Grand Central is the north-west
## start, Victoria Square and Chamberlain Square sit west, and the Bullring,
## St Martin's, and the Rotunda form the eastern shopping district.
##
## Birmingham-specific silhouettes use compact built-in Godot primitives and
## SurfaceTool meshes. Licensed local Kenney dressing and Poly Haven surface
## maps are preloaded below; all provenance is recorded in the asset ledger.

const GRAND_CENTRAL_POSITION: Vector3 = Vector3(28.0, 0.0, -105.0)
const VICTORIA_SQUARE_POSITION: Vector3 = Vector3(-250.0, 0.0, -150.0)
const COUNCIL_HOUSE_POSITION: Vector3 = Vector3(-204.0, 0.0, -230.0)
const BULLRING_POSITION: Vector3 = Vector3(420.0, 0.0, 80.0)
const ST_MARTIN_POSITION: Vector3 = Vector3(362.0, 0.0, 61.0)
const ROTUNDA_POSITION: Vector3 = Vector3(230.0, 0.0, -65.0)

const PAVING_DIFFUSE: Texture2D = preload("res://assets/textures/city/polyhaven/precast_stone_paving_diffuse_1k.jpg")
const PAVING_ROUGHNESS: Texture2D = preload("res://assets/textures/city/polyhaven/precast_stone_paving_roughness_1k.jpg")
const BRICK_DIFFUSE: Texture2D = preload("res://assets/textures/city/polyhaven/brick_wall_02_diffuse_1k.jpg")
const BRICK_ROUGHNESS: Texture2D = preload("res://assets/textures/city/polyhaven/brick_wall_02_roughness_1k.jpg")
const CONCRETE_DIFFUSE: Texture2D = preload("res://assets/textures/city/polyhaven/concrete_floor_02_diffuse_1k.jpg")
const CONCRETE_ROUGHNESS: Texture2D = preload("res://assets/textures/city/polyhaven/concrete_floor_02_roughness_1k.jpg")
const METAL_DIFFUSE: Texture2D = preload("res://assets/textures/city/polyhaven/metal_plate_diffuse_1k.jpg")
const METAL_ROUGHNESS: Texture2D = preload("res://assets/textures/city/polyhaven/metal_plate_roughness_1k.jpg")

const KENNEY_BUILDINGS: Array[PackedScene] = [
	preload("res://assets/models/world/kenney/commercial/building-a.glb"),
	preload("res://assets/models/world/kenney/commercial/building-b.glb"),
	preload("res://assets/models/world/kenney/commercial/building-c.glb"),
	preload("res://assets/models/world/kenney/commercial/building-d.glb"),
	preload("res://assets/models/world/kenney/commercial/building-e.glb"),
	preload("res://assets/models/world/kenney/commercial/building-f.glb"),
	preload("res://assets/models/world/kenney/commercial/low-detail-building-wide-a.glb"),
	preload("res://assets/models/world/kenney/commercial/low-detail-building-wide-b.glb"),
]
const KENNEY_AWNING: PackedScene = preload("res://assets/models/world/kenney/commercial/detail-awning-wide.glb")
const KENNEY_PARASOL: PackedScene = preload("res://assets/models/world/kenney/commercial/detail-parasol-a.glb")
const KENNEY_LIGHT: PackedScene = preload("res://assets/models/world/kenney/roads/light-square.glb")
const KENNEY_DUMPSTER: PackedScene = preload("res://assets/models/world/kenney/roads/dumpster.glb")
const KENNEY_STREET_SIGN: PackedScene = preload("res://assets/models/world/kenney/roads/road-sign-street.glb")
const KENNEY_WARNING_SIGN: PackedScene = preload("res://assets/models/world/kenney/roads/road-sign-warning.glb")
const KENNEY_TRAFFIC_LIGHT: PackedScene = preload("res://assets/models/world/kenney/roads/traffic-light.glb")
const KENNEY_BARRIER: PackedScene = preload("res://assets/models/world/kenney/roads/construction-barrier.glb")
const KENNEY_CONE: PackedScene = preload("res://assets/models/world/kenney/roads/construction-cone.glb")
const KENNEY_VEHICLES: Array[PackedScene] = [
	preload("res://assets/models/world/kenney/vehicles/sedan.glb"),
	preload("res://assets/models/world/kenney/vehicles/taxi.glb"),
	preload("res://assets/models/world/kenney/vehicles/van.glb"),
	preload("res://assets/models/world/kenney/vehicles/hatchback-sports.glb"),
	preload("res://assets/models/world/kenney/vehicles/delivery.glb"),
]

var _materials: Dictionary = {}


func _ready() -> void:
	call_deferred("_assemble")


func _assemble() -> void:
	_build_grand_central_new_street()
	_build_victoria_square_town_hall()
	_build_council_house_chamberlain_square()
	_build_bullring_facade()
	_build_st_martin_in_the_bull_ring()
	_build_rotunda()
	_build_street_language()
	_build_licensed_asset_dressing()


func _make_landmark(node_name: String, landmark_id: String, position: Vector3) -> Node3D:
	var landmark := Node3D.new()
	landmark.name = node_name
	landmark.position = position
	landmark.add_to_group("landmark")
	landmark.add_to_group("route_landmark")
	landmark.set_meta("landmark_id", landmark_id)
	landmark.set_meta("art_source", "procedural Godot geometry; see docs/ART_PASS_PROVENANCE.md")
	add_child(landmark)
	return landmark


func _material(
	key: String,
	color: Color,
	roughness: float = 0.82,
	metallic: float = 0.0
) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	_configure_surface_texture(material, key)
	_materials[key] = material
	return material


func _configure_surface_texture(material: StandardMaterial3D, key: String) -> void:
	var diffuse: Texture2D
	var roughness_map: Texture2D
	match key:
		"paving":
			diffuse = PAVING_DIFFUSE
			roughness_map = PAVING_ROUGHNESS
		"station_stone", "town_hall_stone", "town_hall_shadow":
			diffuse = CONCRETE_DIFFUSE
			roughness_map = CONCRETE_ROUGHNESS
		"council_house_stone", "church_stone", "church_shadow":
			diffuse = BRICK_DIFFUSE
			roughness_map = BRICK_ROUGHNESS
		"steel", "bullring_cladding", "bullring_highlight", "rotunda_tower":
			diffuse = METAL_DIFFUSE
			roughness_map = METAL_ROUGHNESS
	if diffuse == null:
		return
	material.albedo_texture = diffuse
	material.roughness_texture = roughness_map
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3(0.32, 0.32, 0.32)


func _build_grand_central_new_street() -> void:
	var root := _make_landmark("GrandCentralNewStreet", "grand_central_new_street", GRAND_CENTRAL_POSITION)
	var paving := _material("paving", Color(0.62, 0.66, 0.68), 0.72)
	var station_glass := _material("station_glass", Color(0.12, 0.25, 0.32), 0.35, 0.1)
	var station_stone := _material("station_stone", Color(0.72, 0.76, 0.76), 0.78)
	var steel := _material("steel", Color(0.18, 0.22, 0.24), 0.32, 0.7)
	var warm_light := _material("warm_light", Color(0.82, 0.55, 0.23), 0.42, 0.15)

	LandmarkPrimitives.box(root, "NewStreetPaving", Vector3(78.0, 0.24, 42.0), Vector3(0.0, 0.12, 0.0), paving)
	LandmarkPrimitives.box(root, "StationFrontage", Vector3(72.0, 13.0, 4.5), Vector3(0.0, 6.5, 4.0), station_glass)
	LandmarkPrimitives.box(root, "StationStoneBase", Vector3(76.0, 2.4, 6.0), Vector3(0.0, 1.2, 4.5), station_stone)
	LandmarkPrimitives.box(root, "GrandCentralCanopy", Vector3(86.0, 1.2, 17.0), Vector3(0.0, 14.2, -1.5), steel)
	LandmarkPrimitives.box(root, "CanopyHighlight", Vector3(82.0, 0.22, 0.8), Vector3(0.0, 13.55, -9.8), warm_light)
	for index in range(7):
		var x := -30.0 + float(index) * 10.0
		LandmarkPrimitives.box(root, "GlassMullion" + str(index), Vector3(0.42, 10.0, 0.35), Vector3(x, 7.3, 1.55), steel)
		LandmarkPrimitives.cylinder(root, "CanopySupport" + str(index), 0.28, 13.5, Vector3(x, 6.8, -8.0), steel, -1.0, 8)
		LandmarkPrimitives.box(root, "WarmPanel" + str(index), Vector3(4.8, 0.42, 0.16), Vector3(x, 6.2, 1.68), warm_light)
	LandmarkPrimitives.label(root, "GrandCentralSign", "GRAND CENTRAL\nNEW STREET", Vector3(0.0, 16.8, -10.2), Color(0.92, 0.95, 0.94), 0.022)
	LandmarkPrimitives.label(root, "StationWayfinding", "PLATFORM WALK", Vector3(0.0, 3.0, -12.0), Color(0.72, 0.82, 0.84), 0.014)
	_add_box_collision(root, "GrandCentralCollision", Vector3(76.0, 13.0, 6.0), Vector3(0.0, 6.5, 4.5))


func _build_victoria_square_town_hall() -> void:
	var root := _make_landmark("VictoriaSquareTownHall", "victoria_square_town_hall", VICTORIA_SQUARE_POSITION)
	var paving := _material("paving", Color(0.62, 0.66, 0.68), 0.72)
	var stone := _material("town_hall_stone", Color(0.86, 0.84, 0.76), 0.86)
	var stone_shadow := _material("town_hall_shadow", Color(0.66, 0.65, 0.60), 0.9)
	var roof := _material("town_hall_roof", Color(0.13, 0.16, 0.17), 0.8)
	var brass := _material("town_hall_brass", Color(0.52, 0.36, 0.16), 0.36, 0.55)

	LandmarkPrimitives.box(root, "VictoriaSquarePaving", Vector3(102.0, 0.24, 72.0), Vector3(0.0, 0.12, 0.0), paving)
	LandmarkPrimitives.box(root, "TownHallBase", Vector3(64.0, 10.0, 22.0), Vector3(0.0, 5.0, 1.0), stone)
	LandmarkPrimitives.box(root, "TownHallUpper", Vector3(57.0, 4.5, 16.0), Vector3(0.0, 12.0, 1.5), stone_shadow)
	LandmarkPrimitives.triangular_prism(root, "TownHallPediment", 46.0, 4.5, 8.0, Vector3(0.0, 14.1, -9.0), stone)
	for index in range(6):
		var x := -25.0 + float(index) * 10.0
		LandmarkPrimitives.cylinder(root, "TownHallColumn" + str(index), 1.05, 12.5, Vector3(x, 7.0, -11.8), stone, -1.0, 10)
		LandmarkPrimitives.cylinder(root, "ColumnCap" + str(index), 1.35, 0.45, Vector3(x, 13.2, -11.8), brass, -1.0, 10)
	LandmarkPrimitives.box(root, "TownHallClockTower", Vector3(10.0, 11.0, 9.0), Vector3(0.0, 20.0, 1.0), stone)
	LandmarkPrimitives.cone(root, "TownHallRoof", 7.2, 7.0, Vector3(0.0, 29.0, 1.0), roof, 4)
	LandmarkPrimitives.cylinder(root, "VictoriaSquareFountain", 5.0, 0.5, Vector3(0.0, 0.45, 27.0), brass, -1.0, 16)
	LandmarkPrimitives.label(root, "TownHallSign", "TOWN HALL", Vector3(0.0, 33.0, -12.5), Color(0.95, 0.92, 0.84), 0.024)
	LandmarkPrimitives.label(root, "VictoriaSquareSign", "VICTORIA SQUARE", Vector3(0.0, 2.8, 30.0), Color(0.78, 0.82, 0.81), 0.016)
	_add_box_collision(root, "TownHallCollision", Vector3(64.0, 15.0, 22.0), Vector3(0.0, 7.5, 1.0))


func _build_council_house_chamberlain_square() -> void:
	var root := _make_landmark("CouncilHouseChamberlainSquare", "council_house_chamberlain_square", COUNCIL_HOUSE_POSITION)
	var paving := _material("paving", Color(0.62, 0.66, 0.68), 0.72)
	var blue_stone := _material("council_house_stone", Color(0.56, 0.64, 0.68), 0.82)
	var pale_stone := _material("council_house_trim", Color(0.57, 0.57, 0.52), 0.86)
	var roof := _material("council_house_roof", Color(0.12, 0.14, 0.15), 0.8)
	var fountain := _material("chamberlain_water", Color(0.12, 0.32, 0.40), 0.3, 0.2)

	LandmarkPrimitives.box(root, "ChamberlainSquarePaving", Vector3(90.0, 0.24, 66.0), Vector3(0.0, 0.12, 0.0), paving)
	LandmarkPrimitives.box(root, "CouncilHouseCentral", Vector3(30.0, 22.0, 18.0), Vector3(0.0, 11.0, 2.0), blue_stone)
	LandmarkPrimitives.box(root, "CouncilHouseWestWing", Vector3(34.0, 14.0, 24.0), Vector3(-30.0, 7.0, 3.0), blue_stone)
	LandmarkPrimitives.box(root, "CouncilHouseEastWing", Vector3(34.0, 14.0, 24.0), Vector3(30.0, 7.0, 3.0), blue_stone)
	LandmarkPrimitives.box(root, "CouncilHouseCornice", Vector3(76.0, 1.2, 28.0), Vector3(0.0, 15.0, 3.0), pale_stone)
	LandmarkPrimitives.triangular_prism(root, "CouncilHousePediment", 24.0, 4.0, 7.0, Vector3(0.0, 22.0, -8.0), pale_stone)
	LandmarkPrimitives.sphere(root, "CouncilHouseDome", 8.0, Vector3(0.0, 26.0, 2.0), Vector3(1.2, 0.65, 1.0), roof)
	LandmarkPrimitives.cylinder(root, "CouncilHouseDomeDrum", 6.5, 3.5, Vector3(0.0, 22.5, 2.0), pale_stone, -1.0, 12)
	LandmarkPrimitives.cylinder(root, "ChamberlainFountain", 6.0, 0.45, Vector3(0.0, 0.4, 27.0), fountain, -1.0, 16)
	for index in range(5):
		var x := -20.0 + float(index) * 10.0
		LandmarkPrimitives.cylinder(root, "CouncilColumn" + str(index), 0.72, 9.0, Vector3(x, 6.0, -10.5), pale_stone, -1.0, 8)
	LandmarkPrimitives.label(root, "CouncilHouseSign", "COUNCIL HOUSE", Vector3(0.0, 32.0, -11.5), Color(0.88, 0.91, 0.88), 0.022)
	LandmarkPrimitives.label(root, "ChamberlainSquareSign", "CHAMBERLAIN SQUARE", Vector3(0.0, 2.8, 29.0), Color(0.74, 0.81, 0.82), 0.015)
	_add_box_collision(root, "CouncilCentralCollision", Vector3(30.0, 22.0, 18.0), Vector3(0.0, 11.0, 2.0))
	_add_box_collision(root, "CouncilWestCollision", Vector3(34.0, 14.0, 24.0), Vector3(-30.0, 7.0, 3.0))
	_add_box_collision(root, "CouncilEastCollision", Vector3(34.0, 14.0, 24.0), Vector3(30.0, 7.0, 3.0))


func _build_bullring_facade() -> void:
	var root := _make_landmark("BullringFacade", "bullring_facade", BULLRING_POSITION)
	var paving := _material("paving", Color(0.62, 0.66, 0.68), 0.72)
	var dark_base := _material("bullring_base", Color(0.18, 0.21, 0.22), 0.62)
	var cladding := _material("bullring_cladding", Color(0.76, 0.82, 0.84), 0.34, 0.35)
	var cladding_highlight := _material("bullring_highlight", Color(0.96, 0.98, 0.94), 0.3, 0.25)
	var glass := _material("bullring_glass", Color(0.09, 0.20, 0.24), 0.28, 0.2)
	var sign_material := _material("bullring_sign", Color(0.82, 0.30, 0.10), 0.48, 0.1)

	LandmarkPrimitives.box(root, "BullringPaving", Vector3(124.0, 0.24, 90.0), Vector3(0.0, 0.12, 0.0), paving)
	LandmarkPrimitives.box(root, "BullringLowerPodium", Vector3(88.0, 4.5, 58.0), Vector3(0.0, 2.25, 1.0), dark_base)
	LandmarkPrimitives.curved_wall(root, "BullringCurvedDiscFacade", 43.0, 4.0, -1.25, 1.25, 26.0, 24, cladding)
	LandmarkPrimitives.cylinder(root, "BullringRoofBand", 44.0, 0.9, Vector3(0.0, 26.5, 0.0), dark_base, -1.0, 24)
	LandmarkPrimitives.box(root, "BullringGlassEntry", Vector3(28.0, 15.0, 2.0), Vector3(0.0, 10.0, -31.0), glass)
	LandmarkPrimitives.box(root, "BullringEntryLintel", Vector3(34.0, 1.6, 2.8), Vector3(0.0, 18.0, -31.0), sign_material)

	var disc_mesh := SphereMesh.new()
	disc_mesh.radius = 0.62
	disc_mesh.height = 1.24
	disc_mesh.radial_segments = 8
	disc_mesh.rings = 4
	var disc_transforms: Array[Transform3D] = []
	for row in range(7):
		var y := 3.5 + float(row) * 3.2
		for column in range(17):
			var blend := float(column) / 16.0
			var angle := lerpf(-1.20, 1.20, blend)
			var radius := 43.45
			var position := Vector3(sin(angle) * radius, y, cos(angle) * radius)
			var basis := Basis(Vector3.UP, angle).scaled(Vector3(1.0, 1.0, 0.24))
			disc_transforms.append(Transform3D(basis, position))
	LandmarkPrimitives.multimesh(root, "DiscCladding", disc_mesh, disc_transforms, cladding_highlight)
	LandmarkPrimitives.label(root, "BullringSign", "BULLRING QUARTER", Vector3(0.0, 31.0, 44.0), Color(0.92, 0.94, 0.91), 0.024)
	LandmarkPrimitives.label(root, "ArcadeSign", "ARCADE", Vector3(0.0, 20.5, -33.0), Color(1.0, 0.90, 0.76), 0.018)
	LandmarkPrimitives.label(root, "DebrandedShopNorth", "BRUM MARKET", Vector3(-27.0, 6.0, -30.0), Color(0.88, 0.83, 0.70), 0.014)
	LandmarkPrimitives.label(root, "DebrandedShopSouth", "PAVEMENT & PASTIES", Vector3(27.0, 6.0, -30.0), Color(0.85, 0.88, 0.88), 0.012)
	_add_box_collision(root, "BullringCollision", Vector3(88.0, 26.0, 58.0), Vector3(0.0, 13.0, 1.0))


func _build_st_martin_in_the_bull_ring() -> void:
	var root := _make_landmark("StMartinInTheBullRing", "st_martin_in_the_bull_ring", ST_MARTIN_POSITION)
	var paving := _material("paving", Color(0.62, 0.66, 0.68), 0.72)
	var church_stone := _material("church_stone", Color(0.78, 0.76, 0.68), 0.9)
	var church_shadow := _material("church_shadow", Color(0.52, 0.54, 0.52), 0.86)
	var roof := _material("church_roof", Color(0.12, 0.16, 0.17), 0.82)
	var trim := _material("church_trim", Color(0.66, 0.62, 0.51), 0.84)

	LandmarkPrimitives.box(root, "StMartinsPaving", Vector3(46.0, 0.24, 46.0), Vector3(0.0, 0.12, 0.0), paving)
	LandmarkPrimitives.box(root, "ChurchNave", Vector3(23.0, 11.0, 30.0), Vector3(0.0, 5.5, 3.0), church_stone)
	LandmarkPrimitives.triangular_prism(root, "ChurchGable", 23.0, 30.0, 8.0, Vector3(0.0, 11.0, 3.0), church_shadow)
	LandmarkPrimitives.box(root, "ChurchTower", Vector3(10.0, 24.0, 10.0), Vector3(0.0, 12.0, -11.0), church_stone)
	LandmarkPrimitives.cone(root, "ChurchSpire", 6.5, 14.0, Vector3(0.0, 31.0, -11.0), roof, 4)
	LandmarkPrimitives.box(root, "ChurchCrossVertical", Vector3(0.85, 8.0, 0.85), Vector3(0.0, 42.0, -11.0), trim)
	LandmarkPrimitives.box(root, "ChurchCrossHorizontal", Vector3(4.0, 0.85, 0.85), Vector3(0.0, 43.0, -11.0), trim)
	for index in range(3):
		var x := -7.0 + float(index) * 7.0
		LandmarkPrimitives.box(root, "NaveButtress" + str(index), Vector3(1.4, 7.0, 2.0), Vector3(x, 3.5, -12.0), church_shadow)
	LandmarkPrimitives.label(root, "StMartinsSign", "ST MARTIN IN THE BULL RING", Vector3(0.0, 47.0, -13.0), Color(0.92, 0.90, 0.83), 0.017)
	_add_box_collision(root, "ChurchNaveCollision", Vector3(23.0, 11.0, 30.0), Vector3(0.0, 5.5, 3.0))
	_add_box_collision(root, "ChurchTowerCollision", Vector3(10.0, 24.0, 10.0), Vector3(0.0, 12.0, -11.0))


func _build_rotunda() -> void:
	var root := _make_landmark("Rotunda", "rotunda", ROTUNDA_POSITION)
	var paving := _material("paving", Color(0.62, 0.66, 0.68), 0.72)
	var tower := _material("rotunda_tower", Color(0.70, 0.76, 0.78), 0.7, 0.1)
	var windows := _material("rotunda_windows", Color(0.08, 0.16, 0.19), 0.28, 0.15)
	var bands := _material("rotunda_bands", Color(0.16, 0.20, 0.21), 0.44, 0.3)
	var roof := _material("rotunda_roof", Color(0.10, 0.13, 0.14), 0.7, 0.4)

	LandmarkPrimitives.box(root, "RotundaPlaza", Vector3(42.0, 0.24, 42.0), Vector3(0.0, 0.12, 0.0), paving)
	LandmarkPrimitives.cylinder(root, "RotundaTower", 16.0, 78.0, Vector3(0.0, 39.0, 0.0), tower, 13.0, 16)
	LandmarkPrimitives.cylinder(root, "RotundaBase", 17.0, 2.8, Vector3(0.0, 1.4, 0.0), bands, -1.0, 16)
	for index in range(5):
		var y := 9.0 + float(index) * 13.0
		LandmarkPrimitives.cylinder(root, "RotundaRing" + str(index), 16.35 - float(index) * 0.45, 0.65, Vector3(0.0, y, 0.0), bands, -1.0, 16)
	LandmarkPrimitives.cylinder(root, "RotundaRoof", 14.0, 1.3, Vector3(0.0, 78.7, 0.0), roof, -1.0, 16)
	LandmarkPrimitives.box(root, "RotundaWindowBand", Vector3(20.0, 41.0, 0.42), Vector3(0.0, 40.0, 14.7), windows)
	LandmarkPrimitives.label(root, "RotundaSign", "THE ROTUNDA", Vector3(0.0, 86.0, 15.2), Color(0.91, 0.94, 0.93), 0.022)
	_add_cylinder_collision(root, "RotundaCollision", 16.0, 78.0, Vector3(0.0, 39.0, 0.0))


func _build_street_language() -> void:
	var root := Node3D.new()
	root.name = "StreetLanguage"
	root.set_meta("design_reference", "UK road markings, pedestrian crossings, bollards and wet public realm")
	add_child(root)
	var bollard_material := _material("bollard", Color(0.24, 0.28, 0.28), 0.42, 0.48)
	var marking_material := _material("road_marking", Color(0.88, 0.89, 0.84), 0.72)
	var yellow_material := _material("yellow_line", Color(0.80, 0.62, 0.10), 0.66)

	var bollard_mesh := CylinderMesh.new()
	bollard_mesh.top_radius = 0.12
	bollard_mesh.bottom_radius = 0.16
	bollard_mesh.height = 0.95
	bollard_mesh.radial_segments = 8
	var bollard_transforms: Array[Transform3D] = []
	for index in range(10):
		var x := -10.0 + float(index) * 8.5
		bollard_transforms.append(Transform3D(Basis.IDENTITY, Vector3(28.0 + x, 0.48, -123.0)))
	for index in range(8):
		var x := -28.0 + float(index) * 8.0
		bollard_transforms.append(Transform3D(Basis.IDENTITY, Vector3(420.0 + x, 0.48, 38.0)))
	LandmarkPrimitives.multimesh(root, "PedestrianBollards", bollard_mesh, bollard_transforms, bollard_material)

	var dash_mesh := BoxMesh.new()
	dash_mesh.size = Vector3(0.22, 0.04, 3.6)
	var dash_transforms: Array[Transform3D] = []
	for index in range(9):
		dash_transforms.append(Transform3D(Basis.IDENTITY, Vector3(28.0 + float(index - 4) * 7.0, 0.06, -116.0)))
	LandmarkPrimitives.multimesh(root, "WhiteLaneDashes", dash_mesh, dash_transforms, marking_material)

	var zebra_mesh := BoxMesh.new()
	zebra_mesh.size = Vector3(2.0, 0.045, 0.36)
	var zebra_transforms: Array[Transform3D] = []
	for index in range(9):
		zebra_transforms.append(Transform3D(Basis.IDENTITY, Vector3(420.0 + float(index - 4) * 4.0, 0.07, 41.0)))
	LandmarkPrimitives.multimesh(root, "ZebraCrossing", zebra_mesh, zebra_transforms, marking_material)
	LandmarkPrimitives.box(root, "YellowNoParkingLine", Vector3(0.16, 0.05, 58.0), Vector3(468.0, 0.08, 80.0), yellow_material)


func _build_licensed_asset_dressing() -> void:
	var root := Node3D.new()
	root.name = "LicensedAssetDressing"
	root.add_to_group("licensed_city_assets")
	root.set_meta("license", "CC0-1.0")
	root.set_meta("provenance", "Kenney City Kit Commercial/Roads and Car Kit; see docs/asset_ledger.json")
	add_child(root)

	# Commercial façades fill the gaps between Birmingham-specific silhouettes.
	_spawn_licensed_asset(root, KENNEY_BUILDINGS[0], "NewStreetRetailWest", Vector3(-62.0, 0.0, -105.0), PI * 0.5, 14.0, 520.0, Vector3(13.0, 18.0, 13.0))
	_spawn_licensed_asset(root, KENNEY_BUILDINGS[1], "NewStreetRetailEast", Vector3(115.0, 0.0, -105.0), -PI * 0.5, 15.0, 520.0, Vector3(15.0, 19.0, 14.0))
	_spawn_licensed_asset(root, KENNEY_BUILDINGS[2], "NewStreetSideStreetWest", Vector3(-45.0, 0.0, -35.0), PI, 14.0, 420.0, Vector3(13.0, 13.0, 16.0))
	_spawn_licensed_asset(root, KENNEY_BUILDINGS[3], "NewStreetSideStreetEast", Vector3(105.0, 0.0, -30.0), 0.0, 14.0, 420.0, Vector3(12.0, 18.0, 13.0))
	_spawn_licensed_asset(root, KENNEY_BUILDINGS[4], "VictoriaRetailWest", Vector3(-330.0, 0.0, -150.0), PI * 0.5, 16.0, 480.0, Vector3(26.0, 14.0, 16.0))
	_spawn_licensed_asset(root, KENNEY_BUILDINGS[5], "VictoriaRetailEast", Vector3(-170.0, 0.0, -145.0), -PI * 0.5, 15.0, 480.0, Vector3(13.0, 25.0, 16.0))
	_spawn_licensed_asset(root, KENNEY_BUILDINGS[4], "ChamberlainRetailNorth", Vector3(-124.0, 0.0, -230.0), PI * 0.5, 18.0, 480.0, Vector3(30.0, 16.0, 18.0))
	_spawn_licensed_asset(root, KENNEY_BUILDINGS[5], "ChamberlainRetailSouth", Vector3(-292.0, 0.0, -230.0), -PI * 0.5, 16.0, 480.0, Vector3(14.0, 27.0, 17.0))
	_spawn_licensed_asset(root, KENNEY_BUILDINGS[6], "RotundaContextWest", Vector3(168.0, 0.0, -65.0), PI * 0.5, 20.0, 360.0, Vector3(20.0, 22.0, 10.0))
	_spawn_licensed_asset(root, KENNEY_BUILDINGS[7], "RotundaContextEast", Vector3(300.0, 0.0, -65.0), -PI * 0.5, 20.0, 360.0, Vector3(20.0, 23.0, 10.0))
	_spawn_licensed_asset(root, KENNEY_BUILDINGS[0], "BullringRetailWest", Vector3(335.0, 0.0, 92.0), PI * 0.5, 18.0, 460.0, Vector3(16.0, 23.0, 17.0))
	_spawn_licensed_asset(root, KENNEY_BUILDINGS[1], "BullringRetailEast", Vector3(505.0, 0.0, 92.0), -PI * 0.5, 18.0, 460.0, Vector3(18.0, 23.0, 17.0))
	_spawn_licensed_asset(root, KENNEY_BUILDINGS[4], "BullringRetailNorth", Vector3(450.0, 0.0, 175.0), PI, 16.0, 420.0, Vector3(26.0, 14.0, 16.0))

	_spawn_licensed_asset(root, KENNEY_AWNING, "BullringMarketAwning", Vector3(394.0, 0.0, 42.0), 0.0, 12.0, 180.0)
	for index in range(4):
		_spawn_licensed_asset(root, KENNEY_PARASOL, "MarketParasol" + str(index), Vector3(365.0 + float(index) * 12.0, 0.0, 26.0), 0.0, 8.0, 160.0)

	var lamp_positions: Array[Vector3] = [
		Vector3(0.0, 0.0, -126.0), Vector3(28.0, 0.0, -126.0), Vector3(56.0, 0.0, -126.0),
		Vector3(-285.0, 0.0, -176.0), Vector3(-218.0, 0.0, -176.0), Vector3(-234.0, 0.0, -206.0),
		Vector3(374.0, 0.0, 38.0), Vector3(438.0, 0.0, 38.0), Vector3(460.0, 0.0, 104.0),
		Vector3(210.0, 0.0, -42.0), Vector3(250.0, 0.0, -42.0),
	]
	for index in range(lamp_positions.size()):
		_spawn_licensed_asset(root, KENNEY_LIGHT, "StreetLight" + str(index), lamp_positions[index], 0.0, 8.0, 240.0)

	_spawn_licensed_asset(root, KENNEY_DUMPSTER, "BullringServiceDumpster", Vector3(476.0, 0.0, 112.0), PI * 0.5, 5.0, 150.0)
	_spawn_licensed_asset(root, KENNEY_STREET_SIGN, "NewStreetRoadSign", Vector3(72.0, 0.0, -124.0), 0.0, 5.0, 180.0)
	_spawn_licensed_asset(root, KENNEY_WARNING_SIGN, "VictoriaRoadworksSign", Vector3(-293.0, 0.0, -184.0), 0.0, 5.0, 180.0)
	_spawn_licensed_asset(root, KENNEY_TRAFFIC_LIGHT, "BullringTrafficLight", Vector3(456.0, 0.0, 40.0), 0.0, 8.0, 220.0)
	_spawn_licensed_asset(root, KENNEY_BARRIER, "VictoriaRoadworksBarrier", Vector3(-286.0, 0.0, -184.0), PI * 0.5, 6.0, 150.0)
	for index in range(4):
		_spawn_licensed_asset(root, KENNEY_CONE, "RoadworksCone" + str(index), Vector3(-280.0 + float(index) * 2.0, 0.0, -184.0), 0.0, 8.0, 120.0)

	var vehicle_positions: Array[Vector3] = [
		Vector3(72.0, 0.0, -138.0), Vector3(-306.0, 0.0, -190.0), Vector3(-150.0, 0.0, -270.0),
		Vector3(476.0, 0.0, 24.0), Vector3(260.0, 0.0, -24.0),
	]
	var vehicle_rotations: Array[float] = [PI * 0.5, 0.0, PI * 0.5, PI * 0.5, -PI * 0.5]
	for index in range(KENNEY_VEHICLES.size()):
		_spawn_licensed_asset(root, KENNEY_VEHICLES[index], "ParkedVehicle" + str(index), vehicle_positions[index], vehicle_rotations[index], 1.0, 220.0, Vector3(1.7, 1.7, 3.4))


func _spawn_licensed_asset(
	parent: Node3D,
	scene: PackedScene,
	node_name: String,
	position: Vector3,
	rotation_y: float,
	uniform_scale: float,
	visibility_end: float,
	collision_size: Vector3 = Vector3.ZERO
) -> Node3D:
	var instance := scene.instantiate() as Node3D
	assert(instance != null, "licensed city asset root must be Node3D")
	instance.name = node_name
	instance.position = position
	instance.rotation.y = rotation_y
	instance.scale = Vector3.ONE * uniform_scale
	instance.add_to_group("licensed_city_asset")
	instance.set_meta("source_path", scene.resource_path)
	instance.set_meta("license", "CC0-1.0")
	parent.add_child(instance)
	_set_visibility_range(instance, visibility_end)
	if collision_size != Vector3.ZERO:
		_add_box_collision(parent, node_name + "Collision", collision_size, position + Vector3(0.0, collision_size.y * 0.5, 0.0), Vector3(0.0, rotation_y, 0.0))
	return instance


func _set_visibility_range(node: Node, visibility_end: float) -> void:
	if node is GeometryInstance3D:
		var geometry := node as GeometryInstance3D
		geometry.visibility_range_end = visibility_end
		geometry.visibility_range_end_margin = 16.0
	for child in node.get_children():
		_set_visibility_range(child, visibility_end)


func _add_box_collision(
	parent: Node3D,
	node_name: String,
	size: Vector3,
	position: Vector3,
	rotation: Vector3 = Vector3.ZERO
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	body.rotation = rotation
	body.add_to_group("city_collision")
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	return body


func _add_cylinder_collision(
	parent: Node3D,
	node_name: String,
	radius: float,
	height: float,
	position: Vector3
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	body.add_to_group("city_collision")
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	return body
