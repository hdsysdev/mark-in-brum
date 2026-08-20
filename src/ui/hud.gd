class_name HUD
extends CanvasLayer
## Compact objective/attention HUD. Listens to GameEvents only.

@onready var _objective: Label = $Objective
@onready var _attention_bar: ProgressBar = $AttentionMeter/Bar
@onready var _attention_label: Label = $AttentionMeter/TierLabel
@onready var _prompt: Label = $InteractionPrompt

const TIER_COLORS: Dictionary = {
	"CALM": Color(0.45, 0.5, 0.45),
	"NOTICED": Color(0.75, 0.7, 0.35),
	"SECURITY_ALERT": Color(0.85, 0.5, 0.2),
	"PURSUIT": Color(0.85, 0.2, 0.2),
}


func _ready() -> void:
	GameEvents.objective_changed.connect(set_objective)
	GameEvents.free_roam_unlocked.connect(_on_free_roam)
	GameEvents.attention_changed.connect(_on_attention_changed)
	GameEvents.capture_sequence_finished.connect(_on_capture)
	_attention_bar.value = 0
	_attention_label.text = "CALM"
	_objective.text = ""
	_prompt.text = ""


func _on_free_roam() -> void:
	_objective.text = "Free roam — cause some chaos."


func _on_capture() -> void:
	_prompt.text = "Security escorted Mark to the edge of town. \"And stay out!\""
	_prompt.modulate = Color(0.9, 0.75, 0.4)
	var tween := create_tween()
	tween.tween_interval(4.0)
	tween.tween_property(_prompt, "modulate:a", 0.0, 1.0)


func _on_attention_changed(value: float, tier_name: String) -> void:
	_attention_bar.value = value
	_attention_label.text = tier_name
	_attention_label.modulate = TIER_COLORS.get(tier_name, Color.WHITE)


func set_objective(text: String) -> void:
	_objective.text = text
