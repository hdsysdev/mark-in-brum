extends GutTest
## Security pursuit integration: escalation chases Mark, proximity captures,
## and the capture sequence resets the loop cleanly.

const MARK_SCENE: String = "res://scenes/player/mark.tscn"
const GUARD_SCENE: String = "res://scenes/npc/security_guard.tscn"


func _make_world() -> void:
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


func _spawn_scene() -> Dictionary:
	_make_world()
	var router := InputRouter.new()
	add_child_autofree(router)
	router.add_to_group("input_router")
	var mark := (load(MARK_SCENE) as PackedScene).instantiate() as MarkController
	mark.input_router_path = NodePath(router.get_path())
	mark.position = Vector3(0.0, 2.0, 0.0)
	add_child_autofree(mark)
	await wait_physics_frames(30, "settle")
	var attention := AttentionSystem.new()
	attention.tiers = AttentionTiers.new()
	add_child_autofree(attention)
	attention.mark_path = NodePath(mark.get_path())
	attention._ready()
	var guard := (load(GUARD_SCENE) as PackedScene).instantiate() as CharacterBody3D
	guard.position = Vector3(0.0, 0.9, 10.0)
	add_child_autofree(guard)
	var brain: SecurityBrain = guard.get_node("Brain")
	brain.mark_path = NodePath(mark.get_path())
	brain.attention_system_path = NodePath(attention.get_path())
	brain._ready()
	var capture := CaptureSequence.new()
	add_child_autofree(capture)
	capture.mark_path = NodePath(mark.get_path())
	capture.attention_system_path = NodePath(attention.get_path())
	capture.checkpoint = Vector3(0.0, 1.2, 0.0)
	capture._ready()
	return {"router": router, "mark": mark, "attention": attention, "guard": guard, "brain": brain, "capture": capture}


func test_guard_patrols_at_calm() -> void:
	var ctx := await _spawn_scene()
	var brain: SecurityBrain = ctx["brain"]
	assert_eq(brain.mode, SecurityBrain.Mode.PATROL)


func test_escalation_chases_and_captures_mark() -> void:
	var ctx := await _spawn_scene()
	var attention: AttentionSystem = ctx["attention"]
	var guard: CharacterBody3D = ctx["guard"]
	var mark: MarkController = ctx["mark"]
	var brain: SecurityBrain = ctx["brain"]

	attention.add_event(90.0)  # straight to PURSUIT
	assert_eq(brain.mode, SecurityBrain.Mode.CHASE)
	var captured: Array = []
	GameEvents.player_captured.connect(func() -> void: captured.append(true))
	var start_distance := guard.global_position.distance_to(mark.global_position)
	await wait_physics_frames(240, "let the guard chase and capture")
	var end_distance := guard.global_position.distance_to(mark.global_position)
	assert_true(end_distance < start_distance or captured.size() > 0,
		"pursuing guard must close the gap (or have already captured Mark)")

	# Capture hold resolves and the sequence resets the loop.
	await wait_physics_frames(240, "let capture hold elapse")
	assert_eq(captured.size(), 1, "capture must fire once")
	assert_almost_eq(attention.value, 0.0, 0.001, "capture must reset attention")
	assert_almost_eq(mark.global_position.x, 0.0, 0.3, "mark must be back at the checkpoint")
	assert_almost_eq(mark.global_position.z, 0.0, 0.3, "mark must be back at the checkpoint")
	assert_eq(brain.mode, SecurityBrain.Mode.PATROL, "guard must return to patrol after capture")


func test_guard_sighting_feeds_attention() -> void:
	var ctx := await _spawn_scene()
	var attention: AttentionSystem = ctx["attention"]
	var guard: CharacterBody3D = ctx["guard"]
	var mark: MarkController = ctx["mark"]
	var brain: SecurityBrain = ctx["brain"]
	# Mirror the GameRoot wiring: sightings add attention.
	brain.guard_sighted.connect(func(_position: Vector3) -> void:
		attention.add_event(3.0))
	# Put the guard right next to Mark so sighting fires.
	guard.position = mark.global_position + Vector3(1.0, 0.0, 0.0)
	await wait_physics_frames(40, "let sighting tick")
	assert_gt(attention.value, 0.0, "guard sightings must add attention")
