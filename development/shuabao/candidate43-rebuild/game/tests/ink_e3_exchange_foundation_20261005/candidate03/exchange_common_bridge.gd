extends "res://tests/ink_e2_boat_foundation_20261005/candidate04/boat_common_bridge.gd"
## E3-only simultaneous impact stats. Existing E2/E1/common runtime untouched.
func before_hit(enemy: Dictionary, amount: float, source: String, cast_id: int, is_true: bool, critical: bool, metadata: Dictionary) -> Dictionary:
 if source!="e3" or not metadata.has("ink_e3_impact_stats"): return super.before_hit(enemy,amount,source,cast_id,is_true,critical,metadata)
 ensure_combat(); refresh_stats()
 var event: Dictionary = damage_metadata(source,cast_id,metadata)
 event.target=enemy; event.amount=amount; event.damage_type="true" if is_true else "ordinary"; event.critical=critical
 if event.get("basic_attack",false) or critical: event.crit_rolled=true
 var impact: Dictionary = context()
 impact.hero.stats=metadata.ink_e3_impact_stats.duplicate(true)
 return runtime.before_damage(event,impact)
