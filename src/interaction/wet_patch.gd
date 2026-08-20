class_name WetPatch
extends MeshInstance3D
## Fading ground stain. Pooled, capped by the EffectsRoot. A flat disc with
## transparency — compatible with the Compatibility renderer.

@export var lifetime: float = 9.0
@export var fade_out_seconds: float = 2.5
@export var max_radius: float = 0.35
@export var reduced_grossness: bool = false

var _age: float = 0.0
var _material: StandardMaterial3D
var _active: bool = false
var _disc: CylinderMesh


func _ready() -> void:
	_disc = CylinderMesh.new()
	_disc.top_radius = 0.01
	_disc.bottom_radius = 0.01
	_disc.height = 0.01
	mesh = _disc
	_material = StandardMaterial3D.new()
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = Color(0.12, 0.12, 0.10, 0.0)
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = _material
	visible = false
	set_process(false)


func place_at(position: Vector3, normal: Vector3) -> void:
	global_position = position + normal * 0.02
	# Orient the disc to lie on the surface.
	if absf(normal.dot(Vector3.UP)) < 0.99:
		global_transform.basis = Basis.looking_at(normal, Vector3.UP)
	_age = 0.0
	_active = true
	visible = true
	set_process(true)
	_disc.top_radius = max_radius
	_disc.bottom_radius = max_radius


func _process(delta: float) -> void:
	_age += delta
	var alpha: float = 0.5 if not reduced_grossness else 0.22
	if _age > lifetime - fade_out_seconds:
		alpha = alpha * clampf((lifetime - _age) / fade_out_seconds, 0.0, 1.0)
	_material.albedo_color.a = alpha
	if _age >= lifetime:
		_active = false
		visible = false
		set_process(false)
		_material.albedo_color.a = 0.0


func is_active() -> bool:
	return _active
