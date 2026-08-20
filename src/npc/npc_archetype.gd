class_name NPCArchetype
extends Resource
## Content definition for one civilian variant. Palettes, speeds and
## reaction temperament vary per archetype; the body scene stays shared.

@export var display_name: String = "Civilian"
@export var palette: Color = Color(0.55, 0.55, 0.6)
@export var walk_speed: float = 1.7
@export var reaction_data: NPCReactionData
@export var voice_variant: int = 0
