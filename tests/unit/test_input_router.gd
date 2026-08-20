extends GutTest
## InputRouter contract: dead-zone normalization, source merging, look-delta
## consumption, and touch-state clearing. Pure headless — no scene needed.

var router: InputRouter


func before_each() -> void:
	router = InputRouter.new()
	add_child_autofree(router)
	router.deadzone = 0.2


func after_each() -> void:
	Input.action_release("move_forward")
	Input.action_release("move_left")
	Input.action_release("sprint")
	Input.action_release("action")
	Input.action_release("recenter")


func test_deadzone_zeroes_small_vectors() -> void:
	router.joystick_vector = Vector2(0.1, 0.05)
	var frame := router.build_frame()
	assert_eq(frame.move, Vector2.ZERO, "sub-deadzone vectors must be zeroed")


func test_joystick_vector_passes_through_above_deadzone() -> void:
	router.joystick_vector = Vector2(0.9, 0.0)
	var frame := router.build_frame()
	assert_almost_eq(frame.move.x, 0.9, 0.001)


func test_keyboard_and_joystick_merge_and_clamp_to_unit_circle() -> void:
	Input.action_press("move_forward")
	router.joystick_vector = Vector2(1.0, 0.0)
	var frame := router.build_frame()
	assert_almost_eq(frame.move.length(), 1.0, 0.001,
		"combined vector must clamp to unit length")


func test_look_deltas_accumulate_and_are_consumed() -> void:
	router.add_look_delta(Vector2(5.0, 3.0))
	var frame := router.build_frame()
	assert_eq(frame.look_delta, Vector2(5.0, 3.0))
	var consumed := router.consume_look_delta()
	assert_eq(consumed, Vector2(5.0, 3.0))
	var second := router.build_frame()
	assert_eq(second.look_delta, Vector2.ZERO, "look delta must be consumed once")


func test_action_and_sprint_from_touch_and_keyboard() -> void:
	router.touch_action_held = true
	router.touch_sprint_held = true
	var frame := router.build_frame()
	assert_true(frame.action_held)
	assert_true(frame.sprint_held)
	router.touch_action_held = false
	router.touch_sprint_held = false
	Input.action_press("action")
	Input.action_press("sprint")
	frame = router.build_frame()
	assert_true(frame.action_held)
	assert_true(frame.sprint_held)


func test_recenter_and_pause_flags_are_one_shot() -> void:
	router.press_recenter()
	router.press_pause()
	var frame := router.build_frame()
	assert_true(frame.recenter_pressed)
	assert_true(frame.pause_pressed)
	frame = router.build_frame()
	assert_false(frame.recenter_pressed, "recenter press must not repeat")
	assert_false(frame.pause_pressed, "pause press must not repeat")


func test_clear_all_touch_state_resets_everything() -> void:
	router.joystick_vector = Vector2(1.0, 0.0)
	router.touch_action_held = true
	router.touch_sprint_held = true
	router.add_look_delta(Vector2(9.0, 9.0))
	router.clear_all_touch_state()
	var frame := router.build_frame()
	assert_eq(frame.move, Vector2.ZERO)
	assert_false(frame.action_held)
	assert_false(frame.sprint_held)
	assert_eq(frame.look_delta, Vector2.ZERO)
