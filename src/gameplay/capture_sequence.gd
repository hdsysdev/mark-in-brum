class_name CaptureSequence
extends Node
## Handles the capture fallout: fade, humorous ejection message, attention
## reset, and repositioning Mark back at a checkpoint. No combat — v1
## resolves capture as a slapstick reset.

signal sequence_finished

@export var mark_path: NodePath
@export var attention_system_path: NodePath
@export var checkpoint: Vector3 = Vector3(0.0, 1.2, 0.0)
@export var fade_seconds: float = 0.8
@export var message: String = "Security escorts Mark to the edge of town. \"And stay out!\""

var _mark: Node3D
var _attention: AttentionSystem
var _busy: bool = false


func _ready() -> void:
	_mark = get_node_or_null(mark_path) as Node3D
	_attention = get_node_or_null(attention_system_path) as AttentionSystem
	if not GameEvents.player_captured.is_connected(_on_player_captured):
		GameEvents.player_captured.connect(_on_player_captured)
	if not GameEvents.capture_sequence_finished.is_connected(_on_sequence_finished):
		GameEvents.capture_sequence_finished.connect(_on_sequence_finished)


func _exit_tree() -> void:
	if GameEvents.player_captured.is_connected(_on_player_captured):
		GameEvents.player_captured.disconnect(_on_player_captured)
	if GameEvents.capture_sequence_finished.is_connected(_on_sequence_finished):
		GameEvents.capture_sequence_finished.disconnect(_on_sequence_finished)


func _on_sequence_finished() -> void:
	_busy = false
	sequence_finished.emit()


func _on_player_captured() -> void:
	if _busy:
		return
	_busy = true
	if _attention != null:
		_attention.reset()
	# Slapstick reset: fade handled by the UI overlay listening to
	# GameEvents; here we reposition immediately (tests rely on this).
	if _mark != null:
		_mark.global_position = checkpoint
		if _mark is CharacterBody3D:
			(_mark as CharacterBody3D).velocity = Vector3.ZERO
	GameEvents.capture_sequence_finished.emit()


func is_busy() -> bool:
	return _busy
