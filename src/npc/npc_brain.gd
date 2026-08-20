class_name NPCBrain
extends Node
## State machine + navigation driver for adult civilian NPCs. Movement runs
## in _physics_process through NavigationAgent3D; think ticks are staggered.
## Reactions are selected deterministically from a per-NPC seed.

signal state_changed(state_name: String)
signal reaction_started(reaction: String)

enum Reaction { COMPLAIN, FLEE, CALL_SECURITY }

@export var reaction_data: NPCReactionData
@export var walk_speed: float = 1.7
@export var flee_speed: float = 3.6
@export var rng_seed: int = 0
@export var think_interval: float = 0.25
@export var waypoints: Array[Vector3] = []
@export var simulation_range: float = 40.0
@export var arrival_distance: float = 0.9

var next_reaction_override: int = -1  # -1 = seeded choice; else forced Reaction

var _state: NPCState
var _rng := RandomNumberGenerator.new()
var _agent: NavigationAgent3D
var _body: CharacterBody3D
var _mark: Node3D
var _think_phase: float = 0.0
var _reaction: int = Reaction.COMPLAIN


func _ready() -> void:
	_rng.seed = rng_seed
	_agent = get_node_or_null("../Feet/NavigationAgent3D") as NavigationAgent3D
	_body = get_parent() as CharacterBody3D
	var group := get_tree().get_nodes_in_group("mark")
	_mark = group[0] as Node3D if not group.is_empty() else null
	_think_phase = fmod(float(rng_seed), 1.0) * think_interval
	if reaction_data == null:
		reaction_data = NPCReactionData.new()
	GameEvents.target_sprayed.connect(_on_global_spray)
	_set_state(NPCIdleState.new(self))

func _exit_tree() -> void:
	if GameEvents.target_sprayed.is_connected(_on_global_spray):
		GameEvents.target_sprayed.disconnect(_on_global_spray)


func state_name() -> String:
	return _state.state_name() if _state != null else "none"


func current_reaction() -> int:
	return _reaction


func _physics_process(delta: float) -> void:
	if _state != null:
		_state.physics_process(delta)


func tick_think(delta: float) -> void:
	# Called by the crowd budgeter so think work is staggered across frames.
	if _state != null and _state.has_method("think"):
		_state.think(delta)


# --- State plumbing ----------------------------------------------------------

func _set_state(next: NPCState) -> void:
	if _state != null:
		_state.exit()
	_state = next
	state_changed.emit(_state.state_name())
	_state.enter()


func transition_to_sprayed() -> void:
	_set_state(NPCStartledState.new(self))


func transition_to_idle() -> void:
	_set_state(NPCIdleState.new(self))


func transition_to_wander() -> void:
	_set_state(NPCWanderState.new(self))


func transition_to_recover() -> void:
	_set_state(NPCRecoverState.new(self))


func start_reaction_transition() -> void:
	# Called by StartledState on timeout. Picks the reaction deterministically.
	if next_reaction_override >= 0:
		_reaction = next_reaction_override
	else:
		var roll := _rng.randf()
		var call_chance: float = reaction_data.call_security_chance
		var complain_chance: float = reaction_data.complaint_chance
		if roll < call_chance:
			_reaction = Reaction.CALL_SECURITY
		elif roll < call_chance + complain_chance:
			_reaction = Reaction.COMPLAIN
		else:
			_reaction = Reaction.FLEE
	match _reaction:
		Reaction.CALL_SECURITY:
			_set_state(NPCCallSecurityState.new(self))
		Reaction.COMPLAIN:
			_set_state(NPCComplainState.new(self))
		Reaction.FLEE:
			_set_state(NPCFleeState.new(self))
	reaction_started.emit(["complain", "flee", "call_security"][_reaction])


# --- Shared helpers used by states -------------------------------------------

func pick_waypoint() -> Vector3:
	if waypoints.is_empty():
		return _body.global_position
	return waypoints[_rng.randi_range(0, waypoints.size() - 1)]


func pick_local_offset(max_radius: float) -> Vector3:
	var angle := _rng.randf() * TAU
	var radius := _rng.randf() * max_radius
	return Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)


func set_nav_target(target: Vector3) -> void:
	if _agent != null:
		_agent.target_position = target


func navigate_to(target: Vector3, speed: float, delta: float) -> bool:
	"""Move the body toward target. Returns true when arrived."""
	if _agent == null or _body == null:
		return false
	# Direct distance check first: navigation sync can lag a frame or two,
	# and this keeps arrival deterministic in headless tests.
	var flat := target - _body.global_position
	flat.y = 0.0
	if flat.length() <= arrival_distance:
		stop_moving()
		return true
	if _agent.is_navigation_finished():
		return true
	var next := _agent.get_next_path_position()
	var dir := next - _body.global_position
	dir.y = 0.0
	if dir.length() > arrival_distance:
		_body.velocity.x = dir.normalized().x * speed
		_body.velocity.z = dir.normalized().z * speed
	else:
		_body.velocity.x = 0.0
		_body.velocity.z = 0.0
	if not _body.is_on_floor():
		_body.velocity.y -= 22.0 * delta
	_body.move_and_slide()
	return false


func stop_moving() -> void:
	if _body != null:
		_body.velocity.x = 0.0
		_body.velocity.z = 0.0


func face_point(point: Vector3) -> void:
	if _body == null:
		return
	var dir := point - _body.global_position
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	_body.global_transform.basis = Basis.looking_at(dir.normalized(), Vector3.UP)


func mark_position() -> Vector3:
	return _mark.global_position if _mark != null and is_instance_valid(_mark) else Vector3.ZERO


func distance_to_mark() -> float:
	if _mark == null or not is_instance_valid(_mark):
		return INF
	return _body.global_position.distance_to(_mark.global_position)


func _on_global_spray(target: Node, _hit: Dictionary) -> void:
	if target == _body and _state != null:
		_state.on_sprayed()
