extends GutTest
## End-to-end civilian reaction: Mark sprays a live NPC in a navmesh'd
## scene, the brain reacts through GameEvents, and no soft-lock occurs.

const MARK_SCENE: String = "res://scenes/player/mark.tscn"
const CIVILIAN_SCENE: String = "res://scenes/npc/civilian.tscn"


func _make_floor() -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40.0, 1.0, 40.0)
	shape.shape = box
	shape.position = Vector3(0.0, -0.5, 0.0)
	body.add_child(shape)
	add_child_autofree(body)


func _make_nav() -> void:
	var region := FlatNavRegion.new()
	region.size = Vector2(40.0, 40.0)
	add_child_autofree(region)


func test_spraying_a_civilian_triggers_a_reaction() -> void:
	_make_floor()
	_make_nav()
	var router := InputRouter.new()
	add_child_autofree(router)
	router.add_to_group("input_router")
	var mark := (load(MARK_SCENE) as PackedScene).instantiate() as MarkController
	mark.input_router_path = NodePath(router.get_path())
	mark.position = Vector3(0.0, 2.0, 4.0)
	add_child_autofree(mark)
	await wait_physics_frames(30, "settle")

	var civilian := (load(CIVILIAN_SCENE) as PackedScene).instantiate()
	civilian.position = Vector3(0.0, 0.9, 1.0)
	add_child_autofree(civilian)
	var brain: NPCBrain = civilian.get_node("Brain")
	brain.next_reaction_override = NPCBrain.Reaction.COMPLAIN
	var reactions: Array = []
	brain.reaction_started.connect(func(name: String) -> void: reactions.append(name))

	var aim := Node3D.new()
	mark.add_child(aim)
	aim.position = Vector3(0.0, 0.8, 0.0)
	aim.look_at(Vector3(0.0, 1.0, 1.0), Vector3.UP)
	var controller: UrineController = mark.get_node("UrineController")
	controller.aim_override = aim

	router.touch_action_held = true
	await wait_physics_frames(75, "spray the civilian, let startle finish")
	assert_eq(reactions.size(), 1, "sprayed civilian must react exactly once")
	assert_eq(reactions[0], "complain")
	assert_true(brain.state_name() in ["complain", "recover", "idle"],
		"brain must be in a live reaction/recovery state, not soft-locked")
	router.touch_action_held = false

	# The civilian must eventually recover to the ambient loop.
	# Flow: spray ~0.2s -> startle 0.65s -> complain 2.6s -> recover 3.5s.
	await wait_physics_frames(420, "let the reaction and recovery finish")
	assert_true(brain.state_name() in ["idle", "wander"],
		"civilian must return to ambient behaviour after recovering")


func test_civilian_reaction_is_not_repeated_by_one_stream() -> void:
	_make_floor()
	_make_nav()
	var router := InputRouter.new()
	add_child_autofree(router)
	router.add_to_group("input_router")
	var mark := (load(MARK_SCENE) as PackedScene).instantiate() as MarkController
	mark.input_router_path = NodePath(router.get_path())
	mark.position = Vector3(0.0, 2.0, 4.0)
	add_child_autofree(mark)
	await wait_physics_frames(30, "settle")

	var civilian := (load(CIVILIAN_SCENE) as PackedScene).instantiate()
	civilian.position = Vector3(0.0, 0.9, 1.0)
	add_child_autofree(civilian)
	var brain: NPCBrain = civilian.get_node("Brain")
	brain.next_reaction_override = NPCBrain.Reaction.FLEE
	var sprays: Array = []
	brain.reaction_started.connect(func(_name: String) -> void: sprays.append(1))

	var aim := Node3D.new()
	mark.add_child(aim)
	aim.position = Vector3(0.0, 0.8, 0.0)
	aim.look_at(Vector3(0.0, 1.0, 1.0), Vector3.UP)
	var controller: UrineController = mark.get_node("UrineController")
	controller.aim_override = aim

	router.touch_action_held = true
	await wait_physics_frames(60, "continuous spray")
	assert_eq(sprays.size(), 1,
		"one continuous stream must not trigger repeated reactions (per-target cooldown)")
	router.touch_action_held = false
