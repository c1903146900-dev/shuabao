extends "res://tests/ink_e3_exchange_foundation_20261005/candidate03/exchange_common_bridge.gd"
## Preserve E3 impact snapshots and the entire Boat/Rain/Common chain.
func refresh_stats(detect_external_changes: bool = true) -> void:
 var s = sim()
 var bonus: Dictionary = s._p2_projection()
 super.refresh_stats(detect_external_changes)
 var h = s.hero
 h.stats.ap += float(h.projected_base_stats.ap) * float(bonus.ap_fraction)
 h.stats.move_speed += float(h.projected_base_stats.move_speed) * float(bonus.speed_fraction)
 _last_stats = h.stats.duplicate(true)
