extends "res://tests/ink_q1_foundation_20261004/revision02/scripts/ink_common_bridge.gd"
## Candidate-only E1 simultaneous-batch snapshot at the existing public runtime
## context boundary. All non-E1 packets and common state/procs stay inherited.
func before_hit(enemy: Dictionary, amount: float, source: String, cast_id: int, is_true: bool, critical: bool, metadata: Dictionary) -> Dictionary:
 if source != "e1" or not metadata.has("ink_e1_impact_stats"): return super.before_hit(enemy, amount, source, cast_id, is_true, critical, metadata)
 ensure_combat(); refresh_stats()
 var event: Dictionary = damage_metadata(source, cast_id, metadata)
 event.target = enemy; event.amount = amount
 event.damage_type = "true" if is_true else "ordinary"; event.critical = critical
 if event.get("basic_attack", false) or critical: event.crit_rolled = true
 var impact_context: Dictionary = context()
 impact_context.hero.stats = metadata.ink_e1_impact_stats.duplicate(true)
 # Keep real enemy identity, original runtime RNG, crit and after-hit processing.
 return runtime.before_damage(event, impact_context)
