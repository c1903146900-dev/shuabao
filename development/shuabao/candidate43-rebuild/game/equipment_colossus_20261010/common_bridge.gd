extends "res://elixir_war_20261009/common_bridge.gd"
## One complete original stat projection, then the unique dynamic conversion.
func refresh_stats(detect_external_changes: bool = true) -> void:
 super.refresh_stats(detect_external_changes)
 var s = sim()
 var owner = model.get_ref() if model!=null else null
 if owner!=null and owner.has_method("d01_conversion"):
  var effect: Dictionary=owner.d01_conversion(s,s.hero.stats.max_hp)
  s.hero.stats.ad+=float(effect.get("AD",0.0))
  s.hero.stats.ap+=float(effect.get("AP",0.0))
 _last_stats=s.hero.stats.duplicate(true)
