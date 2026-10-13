extends "res://scripts/actors/hero_model_core.gd"
## Candidate-only derived temporary attribute. Never a projected/base stat write.
var rain_speed_bonus: float = 0.0
func set_rain_speed_bonus(value: float) -> void: rain_speed_bonus = value
func speed() -> float: return super.speed() * (1.0 + rain_speed_bonus)
