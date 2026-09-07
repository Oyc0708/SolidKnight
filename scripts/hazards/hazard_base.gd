# hazard_base.gd
# ─────────────────────────────────────────────────────────────────────────────
# Shared skeleton for environmental hazards (spikes, acid, crushers). Handles
# player detection; subclasses define damage amount/type/timing.
# ─────────────────────────────────────────────────────────────────────────────
extends Area2D
class_name HazardBase

@export var damage: int = 1
@export var knockback_force: float = 200.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(&"player"):
		return
	_apply_hazard_effect(body)

# Override in subclasses
func _apply_hazard_effect(_body: Node2D) -> void:
	pass
