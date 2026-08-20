class_name GameRoot
extends Node
## Wires the systems together: stream and NPC reactions feed Attention,
## security sightings hold alert high. Logic stays in the systems; this
## node only connects signals.

@onready var _attention: AttentionSystem = $Gameplay/AttentionSystem
@onready var _crowd: CrowdBudgeter = $Actors/Civilians
@onready var _mark: MarkController = $Actors/Mark


func _ready() -> void:
	var urine: UrineController = _mark.get_node("UrineController")
	urine.stream_state_changed.connect(_on_stream_state_changed)
	_crowd.civilian_spawned.connect(_on_civilian_spawned)
	for guard in get_tree().get_nodes_in_group("security"):
		var brain: SecurityBrain = guard.get_node("Brain")
		brain.guard_sighted.connect(_on_guard_sighted)


func _on_stream_state_changed(active: bool) -> void:
	if active:
		# First public act adds a little heat.
		_attention.add_event(4.0, _mark)


func _on_civilian_spawned(civilian: Node) -> void:
	var brain: NPCBrain = civilian.get_node("Brain")
	brain.reaction_started.connect(_on_npc_reaction.bind(brain))


func _on_npc_reaction(_reaction: String, brain: NPCBrain) -> void:
	_attention.add_event(brain.reaction_data.attention_value, brain.get_parent())


func _on_guard_sighted(_mark_position: Vector3) -> void:
	_attention.add_event(3.0)
