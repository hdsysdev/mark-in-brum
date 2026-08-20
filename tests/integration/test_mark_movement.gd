extends GutTest
## Movement integration: Mark's CharacterBody3D moves camera-relative with
## acceleration, clamps to walk/sprint speeds, and settles under gravity.

const MARK_SCENE: String = "res://scenes/player/mark.tscn"
const PHYSICS_FRAMES_PER_SECOND: int = 60


func _make_floor() -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40.0, 1.0, 40.0)
	shape.shape = box
	shape.position = Vector3(0.0, -0.5, 0.0)
	body.add_child(shape)
	add_child_autofree(body)
	return body


func _spawn_mark_with_router() -> Dictionary:
	var router := InputRouter.new()
	add_child_autofree(router)
	router.add_to_group("input_router")
	var mark := (load(MARK_SCENE) as PackedScene).instantiate() as MarkController
	mark.input_router_path = NodePath(router.get_path())
	mark.position = Vector3(0.0, 2.0, 0.0)
	add_child_autofree(mark)
	return {"router": router, "mark": mark}


func test_mark_moves_forward_and_clamps_to_walk_speed() -> void:
	_make_floor()
	var ctx := _spawn_mark_with_router()
	var mark: MarkController = ctx["mark"]
	var router: InputRouter = ctx["router"]
	await wait_physics_frames(10, "settle onto the floor")
	var start_z := mark.global_position.z
	router.joystick_vector = Vector2(0.0, -1.0)  # forward
	await wait_physics_frames(45, "accelerate and cruise")
	var flat_speed: float = Vector2(mark.velocity.x, mark.velocity.z).length()
	assert_gt(start_z - mark.global_position.z, 1.0, "Mark must travel forward")
	assert_lt(flat_speed, 3.4, "walk speed must not exceed configured walk_speed + tolerance")


func test_sprint_reaches_higher_speed_than_walk() -> void:
	_make_floor()
	var ctx := _spawn_mark_with_router()
	var mark: MarkController = ctx["mark"]
	var router: InputRouter = ctx["router"]
	await wait_physics_frames(10, "settle onto the floor")
	router.joystick_vector = Vector2(0.0, -1.0)
	router.touch_sprint_held = true
	await wait_physics_frames(60, "sprint cruise")
	var sprint_speed: float = Vector2(mark.velocity.x, mark.velocity.z).length()
	assert_gt(sprint_speed, 4.5, "sprint should reach a clearly higher speed")


func test_mark_falls_under_gravity_without_floor() -> void:
	var ctx := _spawn_mark_with_router()
	var mark: MarkController = ctx["mark"]
	var start_y := mark.global_position.y
	await wait_physics_frames(30, "free fall")
	assert_lt(mark.global_position.y, start_y - 2.0, "Mark must fall under gravity")
	assert_lt(mark.velocity.y, -8.0, "falling velocity must grow downward")


func test_releasing_input_decelerates_to_near_stop() -> void:
	_make_floor()
	var ctx := _spawn_mark_with_router()
	var mark: MarkController = ctx["mark"]
	var router: InputRouter = ctx["router"]
	await wait_physics_frames(10, "settle onto the floor")
	router.joystick_vector = Vector2(0.0, -1.0)
	await wait_physics_frames(45, "cruise")
	router.joystick_vector = Vector2.ZERO
	await wait_physics_frames(40, "decelerate")
	var flat_speed: float = Vector2(mark.velocity.x, mark.velocity.z).length()
	assert_lt(flat_speed, 0.3, "released input should bring Mark to a near stop")
