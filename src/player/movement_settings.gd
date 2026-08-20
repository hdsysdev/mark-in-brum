class_name MovementSettings
extends Resource
## Balance data for Mark's locomotion. Values tuned for a dense city-centre
## walking scale; kept in a Resource so quality tiers and mods can swap them.

@export_group("Speeds (m/s)")
@export var walk_speed: float = 3.2
@export var sprint_speed: float = 6.0

@export_group("Blend")
@export var acceleration: float = 26.0
@export var deceleration: float = 34.0

@export_group("Vertical")
@export var gravity: float = 22.0
@export var step_height: float = 0.25
