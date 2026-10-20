extends "res://equipment_regeneration_20261009/common_bridge.gd"
## Full E03/B02/P2 chain, same original runtime and clock.
const WarRuntime = preload("runtime.gd")
func refresh_stats(detect_external_changes: bool = true) -> void:
 super.refresh_stats(detect_external_changes)
 var s = sim()
 var owner = model.get_ref() if model != null else null
 var effect: Dictionary = {}
 if owner != null and owner.has_method("war_buff_effect"):
  effect = owner.war_buff_effect(s)
  if not owner.war_elixir_status().active: s.hero.cast_state.erase(WarRuntime.BUFF_KEY)
 else:
  s.hero.cast_state.erase(WarRuntime.BUFF_KEY)
 s.hero.stats.attack_speed = minf(float(s.hero.stats.attack_speed)+float(s.hero.projected_base_stats.attack_speed)*float(effect.get("attack_speed_fraction",0.0)),float(context_values.get("attack_speed_cap",2.5)))
 _last_stats = s.hero.stats.duplicate(true)
func end_room() -> void:
 sim().hero.cast_state.erase(WarRuntime.BUFF_KEY)
 super.end_room()
