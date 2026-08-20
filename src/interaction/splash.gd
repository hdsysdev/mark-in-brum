class_name Splash
extends Node3D
## Pooled one-shot splash at a stream hit point. Visual only.

@export var lifetime: float = 0.5
@export var reduced_grossness: bool = false

var _age: float = 0.0
var _particles: CPUParticles3D
var _active: bool = false


func _ready() -> void:
	_particles = $CPUParticles3D
	_particles.emitting = false
	_particles.one_shot = true
	_particles.explosiveness = 1.0
	_particles.lifetime = lifetime
	_particles.amount = 6 if reduced_grossness else 14
	_particles.direction = Vector3(0, 1, 0)
	_particles.spread = 65.0
	_particles.gravity = Vector3(0, -14, 0)
	_particles.initial_velocity_min = 0.8
	_particles.initial_velocity_max = 2.4
	_particles.scale_amount_min = 0.5
	_particles.scale_amount_max = 1.4
	set_process(false)


func play_at(position: Vector3) -> void:
	global_position = position
	_age = 0.0
	_active = true
	_particles.restart()
	_particles.emitting = true
	set_process(true)
	visible = true


func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime + 0.4:
		_active = false
		visible = false
		set_process(false)
		_particles.emitting = false


func is_active() -> bool:
	return _active
