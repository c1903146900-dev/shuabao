extends "res://elixir_swift_20261010/common_bridge.gd"
const Counterattack=preload("passive27.gd")
func projection_base_stats()->Dictionary:
 var original: Dictionary=super.projection_base_stats()
 var owner: RefCounted=model.get_ref() if model!=null else null
 if owner==null or not owner.has_method("d06_buff_effect"):return original
 var effect: Dictionary=owner.d06_buff_effect(sim())
 if not effect.active:return original
 # Existing catalog units: movement is a fraction of immutable hero base;
 # tenacity is additive percentage points. The original Common still caps it.
 var derived: Dictionary=original.duplicate(true)
 derived.move_speed=float(original.move_speed)+float(owner.d06_move_addition(sim()))
 derived.tenacity=float(original.tenacity)+float(effect.tenacity_fraction)
 return derived
func refresh_stats(detect_external_changes: bool=true)->void:
 var s=sim()
 var owner: RefCounted=model.get_ref() if model!=null else null
 # Commerce invokes the original stat projection only after a successful atomic
 # commit. No source clears the real effect, so sell-all/undo cannot resurrect it;
 # selling one of multiple sources leaves the same timer untouched.
 if owner==null or not owner.has_method("d06_source_present") or not owner.d06_source_present(s):
  s.hero.cast_state.erase(Counterattack.BUFF_KEY)
 elif not owner.d06_buff_effect(s).active:
  s.hero.cast_state.erase(Counterattack.BUFF_KEY)
 super.refresh_stats(detect_external_changes)
func end_room()->void:
 sim().hero.cast_state.erase(Counterattack.BUFF_KEY)
 super.end_room()
