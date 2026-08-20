extends GutTest
## Urination hit integration: raycast hits land on world and NPC layers,
## respect per-target cooldowns, and never depend on particle rendering.

const MARK_SCENE: String = "res://scenes/player/mark.tscn"


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


func _make_npc(at: Vector3) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.add_to_group("npc")
	body.collision_layer = 4
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.7
	shape.shape = capsule
	shape.position = Vector3(0.0, 0.9, 0.0)
	body.add_child(shape)
	body.position = at
	add_child_autofree(body)
	return body


func _spawn_mark_and_aim(target: Vector3) -> Dictionary:
	_make_floor()
	var router := InputRouter.new()
	add_child_autofree(router)
	router.add_to_group("input_router")
	var mark := (load(MARK_SCENE) as PackedScene).instantiate() as MarkController
	mark.input_router_path = NodePath(router.get_path())
	mark.position = Vector3(0.0, 2.0, 4.0)
	add_child_autofree(mark)
	await wait_physics_frames(30, "settle fully (fall takes ~16 frames)")
	# Aim follows Mark like the camera rig does in-game.
	var aim := Node3D.new()
	mark.add_child(aim)
	aim.position = Vector3(0.0, 0.8, 0.0)
	aim.look_at(target, Vector3.UP)
	var controller: UrineController = mark.get_node("UrineController")
	controller.aim_override = aim
	return {"router": router, "mark": mark, "controller": controller, "aim": aim}


func test_world_surface_hit_emits_surface_sprayed() -> void:
	var target := Vector3(0.0, 0.0, 0.5)
	var ctx := await _spawn_mark_and_aim(target)
	var controller: UrineController = ctx["controller"]
	var hits: Array = []
	var handler := func(hit: UrineHit) -> void:
		hits.append(hit)
	controller.surface_sprayed.connect(handler)
	(ctx["router"] as InputRouter).touch_action_held = true
	await wait_physics_frames(40, "hold action toward ground")
	assert_true(hits.size() > 0, "stream aimed at the world must emit surface_sprayed")
	assert_false(controller.is_streaming == false and hits.size() == 0)


func test_npc_hit_emits_target_sprayed_with_cooldown() -> void:
	_make_floor()
	var router := InputRouter.new()
	add_child_autofree(router)
	router.add_to_group("input_router")
	var mark := (load(MARK_SCENE) as PackedScene).instantiate() as MarkController
	mark.input_router_path = NodePath(router.get_path())
	mark.position = Vector3(0.0, 2.0, 4.0)
	add_child_autofree(mark)
	await wait_physics_frames(30, "settle fully")
	var npc := _make_npc(Vector3(0.0, 0.0, 1.0))
	var aim := Node3D.new()
	mark.add_child(aim)
	aim.position = Vector3(0.0, 0.8, 0.0)
	aim.look_at(Vector3(0.0, 1.2, 1.0), Vector3.UP)
	var controller: UrineController = mark.get_node("UrineController")
	controller.aim_override = aim

	var targets: Array = []
	controller.target_sprayed.connect(func(target: Node, _hit: UrineHit) -> void: targets.append(target))

	router.touch_action_held = true
	await wait_physics_frames(30, "spray npc")
	assert_eq(targets.size(), 1, "continuous stream must emit exactly one target hit per cooldown window")
	assert_same(targets[0], npc, "the hit target must be the npc body")
	router.touch_action_held = false
	await wait_physics_frames(5)
	controller._tick_timers(controller.per_target_cooldown_seconds + 0.1)
	router.touch_action_held = true
	await wait_physics_frames(30, "spray npc again after cooldown")
	assert_eq(targets.size(), 2, "a second hit must land after the cooldown expires")


func test_stream_stops_when_action_released() -> void:
	var target := Vector3(0.0, 0.0, 0.5)
	var ctx := await _spawn_mark_and_aim(target)
	var controller: UrineController = ctx["controller"]
	var router: InputRouter = ctx["router"]
	router.touch_action_held = true
	await wait_physics_frames(25, "hold")
	assert_true(controller.is_streaming, "stream must start after hold threshold")
	router.touch_action_held = false
	await wait_physics_frames(4, "release")
	assert_false(controller.is_streaming, "stream must stop when action is released")
