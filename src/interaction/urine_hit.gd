class_name UrineHit
extends RefCounted
## Result of a deterministic stream hit. The visual stream is never the
## collision authority; only these raycast-derived hits feed gameplay.

var collider: Object
var position: Vector3
var normal: Vector3
var distance: float


func _to_string() -> String:
	return "UrineHit(collider=%s, position=%s, distance=%.2f)" % [collider, position, distance]
