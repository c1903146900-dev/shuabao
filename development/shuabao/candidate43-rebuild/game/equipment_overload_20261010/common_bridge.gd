extends "res://equipment_colossus_20261010/common_bridge.gd"
const Overload = preload("passive11.gd")
func c03_move_speed_base()->float:
 return float(sim().hero.projected_base_stats.move_speed)

func refresh_stats(detect_external_changes: bool = true) -> void:
 super.refresh_stats(detect_external_changes)
 var s = sim()
 var owner = model.get_ref() if model!=null else null
 var effect: Dictionary = {}
 if owner!=null and owner.has_method("c03_buff_effect"):
  effect=owner.c03_buff_effect(s)
  # Original commerce invokes this only after successful ledger commit. Losing
  # the last source retires the actual buff; undo/rebuy cannot resurrect it.
  if not owner.c03_source_present(s): s.hero.cast_state.erase(Overload.BUFF_KEY)
 else:
  s.hero.cast_state.erase(Overload.BUFF_KEY)
 s.hero.stats.ap+=float(effect.get("AP",0.0))
 s.hero.stats.move_speed+=c03_move_speed_base()*float(effect.get("move_fraction",0.0))
 _last_stats=s.hero.stats.duplicate(true)
func end_room() -> void:
 sim().hero.cast_state.erase(Overload.BUFF_KEY)
 super.end_room()
