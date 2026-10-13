extends "res://tests/ink_first_floor_user_route_20261005/runtime01/reward_model.gd"
## Keep the real reward, transaction, health observer and inverse ledger chain.
## Regen-only equipment has a dependency even when maxHP does not change.
func command(id: String, action: String, args: Dictionary = {}) -> Dictionary:
 var before_regen: float = float(equipment_effects().get("stats",{}).get("hp_regen",0.0))
 var replay: bool = receipts.has(id)
 var result: Dictionary = super.command(id,action,args)
 if action != "commerce" or not result.accepted or replay or not result.get("changed",false): return result
 var operation: String = str(args.get("operation", ""))
 var after_regen: float = float(equipment_effects().get("stats",{}).get("hp_regen",0.0))
 if operation in ["buy","sell","craft"] and before_regen != after_regen and not state.shop_visit.undo.is_empty():
  var record: Dictionary = state.shop_visit.undo.back()
  record["regen_sensitive"] = true
  record["regen_change"] = {"before":before_regen,"after":after_regen,"unit":"health_points_per_actor_combat_second"}
 return result
func record_health_dependency(sim: Node, kind: String, health_revision: int, before: float, after: float) -> void:
 super.record_health_dependency(sim,kind,health_revision,before,after)
 if _health_sim == null or not is_same(_health_sim.get_ref(),sim) or before == after: return
 var changed: bool = false
 for record in state.shop_visit.undo:
  if record.get("regen_sensitive",false) and not record.sealed:
   record.sealed = true
   record.seal_reason = "regen_dependency_changed"
   record["regen_dependency_seal"] = {"source":kind,"health_revision":health_revision,"before_hp":before,"after_hp":after}
   changed = true
 if changed: state.revision += 1
func equipment_effects() -> Dictionary:
 var out: Dictionary = super.equipment_effects()
 if not runtime_stat_definitions.is_empty(): out.status = "base12_intermediate18_regen_per5"
 return out
func snapshot() -> Dictionary:
 var out: Dictionary = super.snapshot()
 out.content_profile = "base12_intermediate18_regen_per5"
 out.content_warnings = [{"reason":"final_equipment_and_consumables_require_independent_admission"}]
 return out
