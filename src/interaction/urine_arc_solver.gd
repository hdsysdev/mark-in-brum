class_name UrineArcSolver
extends RefCounted
## Pure ballistic sampler for the stream. No scene access: given an origin
## and an aim direction it returns sample points along a stylized
## gravity-affected arc. Deterministic and trivially unit-testable.

const STYLIZED_GRAVITY: float = 1.0

var origin: Vector3 = Vector3.ZERO
var direction: Vector3 = Vector3.FORWARD
var speed: float = 4.5
var range_max: float = 4.5
var sample_count: int = 14
var stream_radius: float = 0.016


func sample_points() -> Array[Vector3]:
	"""Return sample_count + 1 points from origin along the arc."""
	var points: Array[Vector3] = []
	var dir := direction.normalized()
	var flight_time: float = range_max / speed
	for i in sample_count + 1:
		var t: float = flight_time * float(i) / float(sample_count)
		var point: Vector3 = origin + dir * (speed * t)
		point.y -= 0.5 * STYLIZED_GRAVITY * t * t
		points.append(point)
	return points


func set_aim(direction_to_aim: Vector3) -> void:
	direction = direction_to_aim.normalized()
