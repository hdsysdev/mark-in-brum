extends Node
## Thin global event bus. Gameplay state never lives here — only typed signals.
## Systems emit past-tense events; interested scenes connect themselves.

signal game_ready
signal session_started
signal content_notice_accepted
signal errand_started(errand_id: String)
signal errand_step_completed(errand_id: String, step_id: String)
signal objective_changed(objective_text: String)
signal errand_completed(errand_id: String)
signal free_roam_unlocked
signal target_sprayed(target: Node, hit: Dictionary)
signal surface_sprayed(hit: Dictionary)
signal npc_reaction_started(npc: Node, reaction: String)
signal attention_changed(value: float, tier_name: String)
signal player_captured
signal capture_sequence_finished
signal quality_changed(quality_name: String)
signal settings_changed(section: String)
