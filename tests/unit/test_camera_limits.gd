extends GutTest
## Camera rig contract: pitch clamping, yaw response to look input, recenter
## convergence, and the SpringArm3D setup.

const RIG_SCENE: String = "res://scenes/player/third_person_camera_rig.tscn"


func _spawn_rig() -> Dictionary:
	var router := InputRouter.new()
	add_child_autofree(router)
	router.add_to_group("input_router")
	var rig := (load(RIG_SCENE) as PackedScene).instantiate() as ThirdPersonCamera
	add_child_autofree(rig)
	return {"router": router, "rig": rig}


func test_rig_has_spring_arm_camera_and_current_flag() -> void:
	var ctx := _spawn_rig()
	var rig: ThirdPersonCamera = ctx["rig"]
	assert_not_null(rig.spring_arm, "SpringArm3D must exist")
	assert_gt(rig.spring_arm.spring_length, 0.0, "spring length must be positive")
	assert_not_null(rig.camera, "Camera3D must exist")
	assert_true(rig.camera.current, "rig camera must be current")
	assert_eq(rig.spring_arm.collision_mask, 1, "spring arm must collide with world layer")


func test_pitch_clamps_to_limits() -> void:
	var ctx := _spawn_rig()
	var rig: ThirdPersonCamera = ctx["rig"]
	var router: InputRouter = ctx["router"]
	router.add_look_delta(Vector2(0.0, 5000.0))  # huge downward look
	await wait_process_frames(2, "process look input")
	assert_lte(rig.pitch, ThirdPersonCamera.MAX_PITCH + 0.001, "pitch must clamp at top")
	router.add_look_delta(Vector2(0.0, -5000.0))  # huge upward look
	await wait_process_frames(2, "process look input")
	assert_gte(rig.pitch, ThirdPersonCamera.MIN_PITCH - 0.001, "pitch must clamp at bottom")


func test_yaw_responds_to_look_and_recenter_converges() -> void:
	var ctx := _spawn_rig()
	var rig: ThirdPersonCamera = ctx["rig"]
	var router: InputRouter = ctx["router"]
	router.add_look_delta(Vector2(600.0, 0.0))  # look right
	await wait_process_frames(2, "process look input")
	var swung_yaw: float = rig.current_yaw()
	assert_ne(swung_yaw, 0.0, "yaw must change with look input")

	router.press_recenter()
	rig.recenter_speed = 14.0
	await wait_process_frames(90, "recenter convergence")
	assert_almost_eq(rig.current_yaw(), 0.0, 0.01, "recenter must return yaw to behind Mark")
	assert_almost_eq(rig.pitch, rig.default_pitch_desktop, 0.02, "recenter must restore default pitch")


func test_fade_material_prepared_for_target() -> void:
	var ctx := _spawn_rig()
	var rig: ThirdPersonCamera = ctx["rig"]
	var target := MeshInstance3D.new()
	rig.add_child(target)
	rig.fade_target_path = target.get_path()
	# Re-run the setup path the same way _ready would have.
	rig._prepare_fade_material()
	assert_not_null(rig._fade_material, "fade material must be created for the target")
	assert_eq(rig._fade_material.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA)
