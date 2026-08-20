class_name UrineEffectsRoot
extends Node3D
## Owns the pooled splashes and wet patches. Listens to the controller's
## hit signals; never computes hits itself.

const MAX_SPLASHES: int = 10
const MAX_WET_PATCHES: int = 22

@export var urine_controller_path: NodePath
@export var reduced_grossness: bool = false

const SPLASH_SCENE := preload("res://scenes/effects/splash.tscn")
const WET_PATCH_SCENE := preload("res://scenes/effects/wet_patch.tscn")

var _controller: UrineController
var _splashes: Array[Splash] = []
var _patches: Array[WetPatch] = []


func _ready() -> void:
	_controller = get_node_or_null(urine_controller_path) as UrineController
	if _controller != null:
		_controller.surface_sprayed.connect(_on_surface_sprayed)
		_controller.target_sprayed.connect(_on_target_sprayed)
	for i in MAX_SPLASHES:
		var splash := SPLASH_SCENE.instantiate() as Splash
		splash.reduced_grossness = reduced_grossness
		add_child(splash)
		_splashes.append(splash)
	for i in MAX_WET_PATCHES:
		var patch := WET_PATCH_SCENE.instantiate() as WetPatch
		patch.reduced_grossness = reduced_grossness
		add_child(patch)
		_patches.append(patch)


func _on_target_sprayed(_target: Node, hit: UrineHit) -> void:
	_spawn_splash(hit.position)


func _on_surface_sprayed(hit: UrineHit) -> void:
	_spawn_splash(hit.position)
	_spawn_wet_patch(hit.position, hit.normal)


func _spawn_splash(position: Vector3) -> void:
	for splash in _splashes:
		if not splash.is_active():
			splash.play_at(position)
			return


func _spawn_wet_patch(position: Vector3, normal: Vector3) -> void:
	for patch in _patches:
		if not patch.is_active():
			patch.place_at(position, normal)
			return
