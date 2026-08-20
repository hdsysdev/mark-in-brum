extends GutTest
## Bootstrap contract: the entry scene loads and announces readiness through
## the global event bus before attempting to hand off to GameRoot.

const BOOTSTRAP_SCENE: String = "res://scenes/bootstrap/bootstrap.tscn"


func test_bootstrap_scene_loads() -> void:
	var scene: PackedScene = load(BOOTSTRAP_SCENE)
	assert_not_null(scene, "bootstrap scene must load")
	var node := scene.instantiate()
	assert_not_null(node, "bootstrap scene must instantiate")
	node.free()


func test_bootstrap_emits_game_ready() -> void:
	# GDScript lambdas capture primitives by value; capture through a
	# Dictionary so the handler's write is visible to the test.
	var flags: Dictionary = {ready: false}
	var handler := func() -> void:
		flags.ready = true
	GameEvents.game_ready.connect(handler)
	var scene: PackedScene = load(BOOTSTRAP_SCENE)
	var node := scene.instantiate()
	add_child_autofree(node)
	await wait_process_frames(3, "wait for bootstrap ready flow")
	assert_true(flags.ready, "bootstrap must emit GameEvents.game_ready")
	GameEvents.game_ready.disconnect(handler)
