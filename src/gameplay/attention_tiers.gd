class_name AttentionTiers
extends Resource
## Balance data for the civic-attention escalation curve.

@export var noticed_threshold: float = 25.0
@export var security_alert_threshold: float = 55.0
@export var pursuit_threshold: float = 80.0
@export var max_value: float = 100.0

@export_group("Decay")
@export var decay_delay_seconds: float = 5.0
@export var decay_per_second: float = 2.5


func tier_for(value: float) -> String:
	if value >= pursuit_threshold:
		return "PURSUIT"
	if value >= security_alert_threshold:
		return "SECURITY_ALERT"
	if value >= noticed_threshold:
		return "NOTICED"
	return "CALM"
