extends GutTest
## First-day errand chain: proximity objectives, the spray objective, and
## the free-roam unlock. Runs the real ErrandDirector against the real
## first_day.tres resource.

const MARK_SCENE: String = "res://scenes/player/mark.tscn"
const CIVILIAN_SCENE: String = "res://scenes/npc/civilian.tscn"
const CHAIN_PATH: String = "res://data/errands/first_day.tres"


func _make_floor_and_nav() -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60.0, 1.0, 60.0)
	shape.shape = box
	shape.position = Vector3(0.0, -0.5, 0.0)
	body.add_child(shape)
	add_child_autofree(body)
	var nav := FlatNavRegion.new()
	nav.size = Vector2(60.0, 60.0)
	add_child_autofree(nav)


func _spawn_errand_scene() -> Dictionary:
	_make_floor_and_nav()
	var router := InputRouter.new()
	add_child_autofree(router)
	router.add_to_group("input_router")
	var mark := (load(MARK_SCENE) as PackedScene).instantiate() as MarkController
	mark.input_router_path = NodePath(router.get_path())
	mark.position = Vector3(0.0, 2.0, 0.0)
	add_child_autofree(mark)
	await wait_physics_frames(30, "settle")
	var director := ErrandDirector.new()
	add_child_autofree(director)
	director.chain = load(CHAIN_PATH) as ErrandChain
	director.mark_path = NodePath(mark.get_path())
	director._ready()
	return {"router": router, "mark": mark, "director": director}


func test_chain_completes_from_launch_to_free_roam() -> void:
	var ctx := await _spawn_errand_scene()
	var director: ErrandDirector = ctx["director"]
	var mark: MarkController = ctx["mark"]
	var router: InputRouter = ctx["router"]

	assert_eq(director.current_step().id, "get_bearings", "chain must start at step one")

	# Step 1: proximity at (0, 0, -6). Drive forward.
	router.joystick_vector = Vector2(0.0, -1.0)
	await wait_physics_frames(160, "walk to New Street marker")
	router.joystick_vector = Vector2.ZERO
	assert_eq(director.current_step().id, "toilet_closed", "proximity must advance to step two")

	# Step 2: proximity at (4, 0, 3). Teleport nearby and step physics.
	mark.global_position = Vector3(4.0, 0.9, 3.0)
	await wait_physics_frames(10, "stand at the blocked toilet")
	assert_eq(director.current_step().id, "take_the_piss", "toilet discovery must advance to the spray step")

	# Step 3: spray an adult NPC.
	var civilian := (load(CIVILIAN_SCENE) as PackedScene).instantiate()
	civilian.position = Vector3(4.0, 0.9, 1.0)
	add_child_autofree(civilian)
	var aim := Node3D.new()
	mark.add_child(aim)
	aim.position = Vector3(0.0, 0.8, 0.0)
	aim.look_at(Vector3(4.0, 1.2, 1.0), Vector3.UP)
	var controller: UrineController = mark.get_node("UrineController")
	controller.aim_override = aim
	router.touch_action_held = true
	await wait_physics_frames(60, "spray the guard... erm, the civilian")
	router.touch_action_held = false
	assert_eq(director.current_step().id, "leg_it", "spraying an NPC must advance to the final step")

	# Step 4: proximity at (-7, 0, -2).
	mark.global_position = Vector3(-7.0, 0.9, -2.0)
	await wait_physics_frames(10, "reach Victoria Square")
	assert_true(director.chain_finished, "the chain must be finished after the final objective")


func test_director_reports_objective_changes() -> void:
	var ctx := await _spawn_errand_scene()
	var director: ErrandDirector = ctx["director"]
	var objectives: Array = []
	GameEvents.objective_changed.connect(func(text: String) -> void: objectives.append(text))
	(director.chain.steps[0] as ErrandStep).trigger_radius = 100.0  # capture Mark immediately
	await wait_physics_frames(5, "let proximity fire")
	assert_eq(objectives.size(), 1, "advancing a step must publish the next objective")
