extends GutTest
## Pure arc solver contract: deterministic samples, gravity drop, range cap.

var solver: UrineArcSolver


func before_each() -> void:
	solver = UrineArcSolver.new()
	solver.origin = Vector3(0.0, 1.0, 0.0)
	solver.set_aim(Vector3(0.0, 0.0, -1.0))
	solver.speed = 4.0
	solver.range_max = 4.5
	solver.sample_count = 14


func test_sample_count_and_first_point() -> void:
	var points := solver.sample_points()
	assert_eq(points.size(), 15, "sample_count + 1 points")
	assert_eq(points[0], Vector3(0.0, 1.0, 0.0), "first point is the origin")


func test_horizontal_range_cap() -> void:
	var points := solver.sample_points()
	var start := points[0]
	for point in points:
		var horizontal := Vector3(start.x - point.x, 0.0, start.z - point.z).length()
		assert_lte(horizontal, solver.range_max + 0.01, "no sample may exceed range_max horizontally")


func test_gravity_pulls_samples_down() -> void:
	var points := solver.sample_points()
	var last := points[points.size() - 1]
	assert_lt(last.y, points[0].y - 0.3,
		"arc end must sag below the aim line (stylized gravity)")


func test_monotonic_advance_along_aim() -> void:
	var points := solver.sample_points()
	var aim := Vector3(0.0, 0.0, -1.0)
	var previous := points[0].dot(aim)
	for point in points:
		var projected := point.dot(aim)
		assert_gte(projected, previous - 0.0001, "samples advance monotonically along the aim")
		previous = projected


func test_aim_direction_is_normalized() -> void:
	solver.set_aim(Vector3(3.0, 0.0, 0.0))
	assert_almost_eq(solver.direction.length(), 1.0, 0.0001, "direction must be normalized")
