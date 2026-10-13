extends "res://tests/ink_e2_boat_foundation_20261005/candidate04/boat_common_bridge.gd"
## Same projected-base dynamic pool; preserve Boat/Rain/Common hit behavior.
var p2_projection_rejected: String = ""

func refresh_stats(detect_external_changes: bool = true) -> void:
 var s = sim()
 var bonus: Dictionary = s._p2_candidate_projection()
 if str(bonus.status) != "OK":
  # This private-only bridge rejects malformed/unbound requests explicitly.
  # No ordinary world or real skill hooks are connected in candidate02.
  p2_projection_rejected = str(bonus.reason)
  return
 p2_projection_rejected = ""
 super.refresh_stats(detect_external_changes)
 var h = s.hero
 h.stats.ap += float(h.projected_base_stats.ap) * float(bonus.ap_fraction)
 h.stats.move_speed += float(h.projected_base_stats.move_speed) * float(bonus.speed_fraction)
 # The next external-change detection must see the final derived output.
 _last_stats = h.stats.duplicate(true)
