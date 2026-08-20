class_name SpawnDirector
extends Node3D
## Named spawn points for the district. Civilians and security pull from
## here round-robin; errand markers and landmark cues reference the same
## points so spawn placement stays consistent with the world.

@export var spawn_points: Array[Vector3] = []


func point_for(index: int) -> Vector3:
	if spawn_points.is_empty():
		return global_position
	return global_position + spawn_points[index % spawn_points.size()]


func random_point(rng: RandomNumberGenerator) -> Vector3:
	if spawn_points.is_empty():
		return global_position
	return global_position + spawn_points[rng.randi_range(0, spawn_points.size() - 1)]
