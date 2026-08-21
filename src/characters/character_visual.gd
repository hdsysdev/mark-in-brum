class_name CharacterVisual
extends Node3D
## Drives a local humanoid visual from its CharacterBody3D velocity.
## Gameplay remains capsule-based; the imported rig is presentation only.

@export var actor_path: NodePath = ^".."
@export var idle_animation: StringName = &"Idle"
@export var walk_animation: StringName = &"Walk"
@export var run_animation: StringName = &"Run"
@export var run_threshold: float = 3.2

var _actor: CharacterBody3D
var _animation_player: AnimationPlayer
var _current_animation: StringName


func _ready() -> void:
	_actor = get_node_or_null(actor_path) as CharacterBody3D
	var players := find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		_animation_player = players[0] as AnimationPlayer
	_configure_locomotion_loops()
	_play_if_available(idle_animation)


func _process(_delta: float) -> void:
	if _actor == null or _animation_player == null:
		return
	var planar_speed := Vector2(_actor.velocity.x, _actor.velocity.z).length()
	var next_animation := idle_animation
	if planar_speed >= run_threshold:
		next_animation = run_animation
	elif planar_speed > 0.12:
		next_animation = walk_animation
	_play_if_available(next_animation)


func _play_if_available(animation_name: StringName) -> void:
	if _animation_player == null:
		return
	if _current_animation == animation_name and _animation_player.is_playing():
		return
	if not _animation_player.has_animation(animation_name):
		return
	_animation_player.play(animation_name, 0.18)
	_current_animation = animation_name


func _configure_locomotion_loops() -> void:
	if _animation_player == null:
		return
	for animation_name in [idle_animation, walk_animation, run_animation]:
		if not _animation_player.has_animation(animation_name):
			continue
		var animation := _animation_player.get_animation(animation_name)
		animation.loop_mode = Animation.LOOP_LINEAR
