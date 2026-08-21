extends GutTest
## Regression coverage for the real portrait-mobile presentation shown to users.

const CAMERA_SCENE: PackedScene = preload("res://scenes/player/third_person_camera_rig.tscn")
const GAME_SCENE: PackedScene = preload("res://scenes/main/game_root.tscn")
const MARK_SCENE: PackedScene = preload("res://scenes/player/mark.tscn")
const CIVILIAN_SCENE: PackedScene = preload("res://scenes/npc/civilian.tscn")
const GUARD_SCENE: PackedScene = preload("res://scenes/npc/security_guard.tscn")


func test_tall_web_viewport_uses_portrait_camera_without_platform_detection() -> void:
	var rig := CAMERA_SCENE.instantiate() as ThirdPersonCamera
	assert_true(rig.has_method("should_use_portrait_profile"), "camera needs a pure viewport-based profile selector")
	if not rig.has_method("should_use_portrait_profile"):
		return
	assert_true(rig.should_use_portrait_profile(Vector2(960.0, 1955.0)), "tall web canvas must use portrait framing")
	assert_false(rig.should_use_portrait_profile(Vector2(1920.0, 1080.0)), "landscape canvas must keep landscape framing")
	assert_gte(rig.spring_length_mobile, 5.5, "portrait camera must keep the player below one third of screen height")
	assert_gte(rig.fov_mobile, 70.0, "portrait camera needs a wider field of view")
	rig.free()


func test_game_has_no_initial_content_dialog() -> void:
	var game := GAME_SCENE.instantiate()
	assert_null(game.get_node_or_null("UI/ContentNotice"), "gameplay must start immediately without a modal gate")
	game.free()


func test_player_and_npcs_use_human_visuals_not_capsule_placeholders() -> void:
	for packed_scene in [MARK_SCENE, CIVILIAN_SCENE, GUARD_SCENE]:
		var actor := packed_scene.instantiate() as Node3D
		var visual := actor.get_node_or_null("CharacterVisual")
		assert_not_null(visual, "%s must include a human CharacterVisual" % actor.name)
		var placeholder := actor.get_node_or_null("PlaceholderMesh")
		if placeholder == null:
			placeholder = actor.get_node_or_null("Mesh")
		assert_not_null(placeholder, "%s retains its hidden test placeholder" % actor.name)
		if placeholder is GeometryInstance3D:
			assert_false((placeholder as GeometryInstance3D).visible, "%s capsule placeholder must be hidden" % actor.name)
		actor.free()


func test_game_starts_at_grand_central_not_an_empty_origin() -> void:
	var game := GAME_SCENE.instantiate()
	var mark := game.get_node("Actors/Mark") as Node3D
	var grand_central := Vector3(0.0, 0.0, -100.0)
	assert_lt(mark.position.distance_to(grand_central), 55.0, "spawn must immediately frame the first Birmingham landmark")
	game.free()


func test_imported_locomotion_animations_loop() -> void:
	var mark := MARK_SCENE.instantiate() as CharacterBody3D
	add_child_autofree(mark)
	await wait_process_frames(2, "initialize imported humanoid animation player")
	var players := mark.get_node("CharacterVisual").find_children("*", "AnimationPlayer", true, false)
	assert_false(players.is_empty(), "Mark visual must expose an AnimationPlayer")
	if players.is_empty():
		return
	var player := players[0] as AnimationPlayer
	for animation_name in [&"Idle", &"Walk", &"Run"]:
		assert_eq(player.get_animation(animation_name).loop_mode, Animation.LOOP_LINEAR, "%s must loop continuously" % animation_name)
