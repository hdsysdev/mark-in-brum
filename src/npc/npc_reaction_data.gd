class_name NPCReactionData
extends Resource
## Balance data for civilian reactions. Every reaction type shares this
## resource so archetypes can vary how jumpy they are.

@export_group("Timing")
@export var startle_seconds: float = 0.65
@export var complain_seconds: float = 2.6
@export var flee_seconds: float = 8.0
@export var call_security_seconds: float = 3.2
@export var recover_seconds: float = 3.5

@export_group("Chances (sum < 1.0; remainder flees)")
@export var complaint_chance: float = 0.55
@export var call_security_chance: float = 0.25

@export_group("Attention")
@export var attention_value: float = 12.0
