class_name ErrandDirector
extends Node
## Drives the first-day errand chain. Proximity steps check Mark's position;
## spray steps listen for NPC hits; narrative steps complete via API. Emits
## progress through GameEvents so the HUD stays decoupled.

signal step_advanced(step_index: int)
signal chain_completed

@export var chain: ErrandChain
@export var mark_path: NodePath

var current_index: int = -1
var chain_finished: bool = false

var _mark: Node3D


func _ready() -> void:
	_mark = get_node_or_null(mark_path) as Node3D
	if chain == null or chain.steps.is_empty():
		push_warning("ErrandDirector: no chain assigned")
		return
	current_index = 0
	GameEvents.errand_started.emit(chain.chain_id)
	GameEvents.objective_changed.emit(current_step().objective_text)
	step_advanced.emit(0)
	if not GameEvents.target_sprayed.is_connected(_on_target_sprayed):
		GameEvents.target_sprayed.connect(_on_target_sprayed)


func _exit_tree() -> void:
	if GameEvents.target_sprayed.is_connected(_on_target_sprayed):
		GameEvents.target_sprayed.disconnect(_on_target_sprayed)


func current_step() -> ErrandStep:
	return chain.step_at(current_index) if chain != null and not chain_finished else null


func _physics_process(_delta: float) -> void:
	var step := current_step()
	if step == null or _mark == null:
		return
	if step.kind == "proximity":
		var flat := _mark.global_position - step.trigger_position
		flat.y = 0.0
		if flat.length() <= step.trigger_radius:
			_complete_current()


func _on_target_sprayed(target: Node, _hit: Dictionary) -> void:
	var step := current_step()
	if step != null and step.kind == "spray":
		if target is Node3D and (target as Node3D).is_in_group("npc"):
			_complete_current()


func _complete_current() -> void:
	var step := current_step()
	if step == null:
		return
	var completed_id := step.id
	current_index += 1
	if current_index >= chain.steps.size():
		chain_finished = true
		current_index = chain.steps.size()
		GameEvents.errand_step_completed.emit(chain.chain_id, completed_id)
		GameEvents.errand_completed.emit(chain.chain_id)
		GameEvents.free_roam_unlocked.emit()
		GameEvents.objective_changed.emit("")
		chain_completed.emit()
	else:
		GameEvents.errand_step_completed.emit(chain.chain_id, completed_id)
		GameEvents.objective_changed.emit(current_step().objective_text)
		step_advanced.emit(current_index)
