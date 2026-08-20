extends GutTest
## AttentionSystem contract: thresholds, accumulation, decay, reset.

var system: AttentionSystem
var tiers: AttentionTiers


func before_each() -> void:
	tiers = AttentionTiers.new()
	system = AttentionSystem.new()
	system.tiers = tiers
	add_child_autofree(system)
	system._ready()


func test_tier_thresholds() -> void:
	assert_eq(tiers.tier_for(0.0), "CALM")
	assert_eq(tiers.tier_for(25.0), "NOTICED")
	assert_eq(tiers.tier_for(55.0), "SECURITY_ALERT")
	assert_eq(tiers.tier_for(80.0), "PURSUIT")


func test_add_event_accumulates_and_emits() -> void:
	var seen: Array = []
	system.attention_changed.connect(func(value: float, tier: String) -> void:
		seen.append([value, tier]))
	system.add_event(20.0)
	system.add_event(10.0)
	assert_almost_eq(system.value, 30.0, 0.001)
	assert_eq(system.tier_name, "NOTICED")
	assert_eq(seen.size(), 2)


func test_tier_transition_signal_fires_once() -> void:
	var transitions: Array = []
	system.tier_changed.connect(func(old: String, new: String) -> void:
		transitions.append([old, new]))
	system.add_event(30.0)  # -> NOTICED
	system.add_event(25.0)  # 55 -> SECURITY_ALERT
	system.add_event(25.0)  # 80 -> PURSUIT
	assert_eq(transitions.size(), 3)
	assert_eq(transitions[0], ["CALM", "NOTICED"])
	assert_eq(transitions[1], ["NOTICED", "SECURITY_ALERT"])
	assert_eq(transitions[2], ["SECURITY_ALERT", "PURSUIT"])


func test_decay_only_after_delay() -> void:
	tiers.decay_delay_seconds = 1.0
	tiers.decay_per_second = 10.0
	system.add_event(50.0)
	# Step within the delay window: no decay.
	for i in 5:
		system._physics_process(0.1)
	await wait_physics_frames(2)
	system.add_event(0.0)  # refresh event clock; value unchanged assert follows
	assert_almost_eq(system.value, 50.0, 0.5)
	# Step past the delay: decay kicks in.
	system._time_since_last_event = tiers.decay_delay_seconds + 0.1
	system._physics_process(0.2)
	assert_lt(system.value, 50.0, "value must decay after the delay elapses")


func test_reset_zeroes_value_and_tier() -> void:
	system.add_event(90.0)
	system.reset()
	assert_almost_eq(system.value, 0.0, 0.001)
	assert_eq(system.tier_name, "CALM")


func test_value_clamps_to_max() -> void:
	system.add_event(500.0)
	assert_almost_eq(system.value, 100.0, 0.001)
