extends "res://tests/ink_e1_rain_foundation_20261005/rain_common_bridge.gd"
## E2 burst snapshot only. Retains E1 and all inherited common behavior.
func before_hit(enemy: Dictionary, amount: float, source: String, cast_id: int, is_true: bool, critical: bool, metadata: Dictionary) -> Dictionary:
 if source != "e2" or not metadata.has("ink_e2_impact_stats"): return super.before_hit(enemy,amount,source,cast_id,is_true,critical,metadata)
 ensure_combat(); refresh_stats()
 var event: Dictionary = damage_metadata(source,cast_id,metadata)
 event.target=enemy; event.amount=amount; event.damage_type="true" if is_true else "ordinary"; event.critical=critical
 if event.get("basic_attack",false) or critical: event.crit_rolled=true
 var impact: Dictionary = context()
 impact.hero.stats=metadata.ink_e2_impact_stats.duplicate(true)
 return runtime.before_damage(event,impact)
