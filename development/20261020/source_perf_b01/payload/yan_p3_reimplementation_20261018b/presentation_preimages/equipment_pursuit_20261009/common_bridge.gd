extends "res://tests/ink_p2_ordinary_20261006/mechanism01/p2_common_bridge.gd"
## Fresh-construction successor of the current P2/E3/Boat/Rain/Common bridge.
## The leaf transfers the ORIGINAL runtime instance; no second clock is used.
func refresh_stats(detect_external_changes: bool = true) -> void:
 var s = sim()
 var effect: Dictionary = s.b02_current_buff_effect() if s.has_method("b02_current_buff_effect") else {}
 super.refresh_stats(detect_external_changes)
 var h = s.hero
 h.stats.move_speed += float(h.projected_base_stats.move_speed)*float(effect.get("move_fraction",0.0))
 h.stats.attack_speed = minf(float(h.stats.attack_speed)+float(h.projected_base_stats.attack_speed)*float(effect.get("attack_speed_fraction",0.0)),float(context().get("attack_speed_cap",2.5)))
 # Preserve the original external-change detector, including every inherited
 # P2/common contribution. Never bake already-buffed stats into the base.
 _last_stats = h.stats.duplicate(true)
