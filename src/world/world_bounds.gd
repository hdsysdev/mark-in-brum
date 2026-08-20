class_name WorldBounds
extends Node3D
## Keeps Mark inside the district. The boundary is disguised by buildings,
## roadworks and fog; this node enforces it silently and nudges via a
## signal so the HUD can show a cheeky message.

signal boundary_hit(side: String)

@export var center: Vector2 = Vector2.ZERO
@export var half_extent: Vector2 = Vector2(700.0, 700.0)
@export var target_path: NodePath

var _target: Node3D


func _ready() -> void:
	_target = get_node_or_null(target_path) as Node3D


func _physics_process(_delta: float) -> void:
	if _target == null:
		return
	var pos := _target.global_position
	var clamped := pos
	var side := ""
	if pos.x < center.x - half_extent.x:
		clamped.x = center.x - half_extent.x
		side = "west"
	elif pos.x > center.x + half_extent.x:
		clamped.x = center.x + half_extent.x
		side = "east"
	if pos.z < center.y - half_extent.y:
		clamped.z = center.y - half_extent.y
		side = "north"
	elif pos.z > center.y + half_extent.y:
		clamped.z = center.y + half_extent.y
		side = "south"
	if side != "":
		_target.global_position = clamped
		boundary_hit.emit(side)


func is_inside(position: Vector3) -> bool:
	return absf(position.x - center.x) <= half_extent.x and absf(position.z - center.y) <= half_extent.y
