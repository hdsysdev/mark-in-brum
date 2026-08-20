class_name AttentionSystem
extends Node
## Tracks civic attention (0-100) and its tiers. Purely signal-driven:
## systems call add_event(); this node emits tier transitions and mirrors
## every change onto GameEvents for the HUD and security brains.

signal attention_changed(value: float, tier_name: String)
signal tier_changed(old_tier: String, new_tier: String)

@export var tiers: AttentionTiers
@export var mark_path: NodePath

var value: float = 0.0
var tier_name: String = "CALM"

var _mark: Node3D
var _time_since_last_event: float = 0.0


func _ready() -> void:
	if tiers == null:
		tiers = AttentionTiers.new()
	_mark = get_node_or_null(mark_path) as Node3D
	value = 0.0
	tier_name = tiers.tier_for(value)


func _physics_process(delta: float) -> void:
	_time_since_last_event += delta
	if _time_since_last_event > tiers.decay_delay_seconds:
		_set_value(value - tiers.decay_per_second * delta)


func add_event(amount: float, _source: Node = null) -> void:
	_time_since_last_event = 0.0
	_set_value(value + amount)


func reset() -> void:
	_time_since_last_event = 0.0
	_set_value(0.0)


func mark_is_hidden() -> bool:
	# v1 approximation of "out of sight": no guard is near Mark.
	return true


func _set_value(next: float) -> void:
	next = clampf(next, 0.0, tiers.max_value)
	var old_tier := tier_name
	value = next
	tier_name = tiers.tier_for(value)
	if tier_name != old_tier:
		tier_changed.emit(old_tier, tier_name)
	attention_changed.emit(value, tier_name)
	GameEvents.attention_changed.emit(value, tier_name)
