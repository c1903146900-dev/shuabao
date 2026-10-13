extends "res://equipment_elite_damage_20261009/model.gd"
## One player/passive counter in the original run ledger. B04 has no task,
## reward, per-copy counter, independent clock, or separate wallet.
const BasicCycle = preload("passive08.gd")
var _b04_trusted: Dictionary = {}
var _b04_original_event: Dictionary = {}

func equipment_runtime_status(id: String) -> Dictionary:
 var out: Dictionary = super.equipment_runtime_status(id)
 if id != BasicCycle.ITEM_ID or not out.get("supported",false): return out
 var sim: Node = _health_sim.get_ref() if _health_sim != null else null
 if not is_instance_valid(sim) or not sim.has_method("b04_model_is_bound") or not sim.has_method("verify_b04_basic_completion") or not sim.b04_model_is_bound(self):
  return {"supported":false,"reason":"b04_real_basic_completion_bridge_not_bound"}
 out.runtime_complete = true
 out.runtime_status = "source_basic_completion_cycle_bound"
 out.shop_admitted = true
 return out

func _b04_bound(sim: Node) -> bool:
 if not is_instance_valid(sim) or _health_sim == null or _live_sim == null or _floor_owner == null: return false
 if _floor_owner.get_ref() == null or not is_same(_health_sim.get_ref(),sim) or not is_same(_live_sim.get_ref(),sim): return false
 if _run_id.is_empty() or not state.has("shop_visit") or str(state.shop_visit.run_id) != _run_id: return false
 return sim.has_method("b04_model_is_bound") and sim.b04_model_is_bound(self) and str(sim.hero.actor_id) == str(state.hero_id)

func record_verified_basic_completion(sim: Node, original_event: Dictionary) -> Dictionary:
 if not _b04_bound(sim) or not _b04_trusted.is_empty(): return _deny("b04_bound_original_terminal_required")
 if not equipment_runtime_status(BasicCycle.ITEM_ID).get("supported",false): return _deny("b04_runtime_unbound")
 var evidence: Dictionary = sim.verify_b04_basic_completion(self,original_event,_run_id)
 if evidence.is_empty(): return _deny("b04_original_terminal_witness_required")
 var scope: Dictionary = {"run_id":_run_id,"generation":sim.encounter_generation,"room_id":sim.room_id}
 var progress: Dictionary = _b04_progress()
 var selected: Dictionary = BasicCycle.select_unique(state.inventory,runtime_stat_definitions)
 var cooldowns: Dictionary = {"q":sim.hero.cooldowns.get("q"),"e":sim.hero.cooldowns.get("e")}
 var proposal: Dictionary = BasicCycle.evaluate_verified_completion(selected,progress.remainder,_b04_claims(progress,scope),scope,cooldowns,evidence)
 if not proposal.get("eligible",false): return _deny(str(proposal.reason))
 var request: Dictionary = {"run_id":_run_id,"actor_id":state.actor_id,"passive_id":BasicCycle.PASSIVE_ID,"scope":scope,"evidence":evidence,"proposal":proposal}
 var command_id: String = "equipment-b04:" + JSON.stringify([_run_id,state.actor_id,scope.generation,scope.room_id,proposal.claim_to_add.cast_id,proposal.claim_to_add.wave_id])
 _b04_trusted = request.duplicate(true)
 _b04_original_event = original_event
 var result: Dictionary = command(command_id,"b04_verified_basic_completion",request)
 # The inherited non-commerce command path has no outward callbacks. Its
 # rollback/receipt commits count + claim first, then both real CDs are written
 # in this same synchronous stack before ANY event or diagnostic observer.
 if result.get("accepted",false) and not result.get("replayed",false):
  assert(_b04_bound(sim) and sim.room_id == scope.room_id and sim.encounter_generation == scope.generation)
  assert(float(sim.hero.cooldowns.q) == float(proposal.cooldowns_before.q) and float(sim.hero.cooldowns.e) == float(proposal.cooldowns_before.e))
  sim.hero.cooldowns.q = float(proposal.cooldowns_after.q)
  sim.hero.cooldowns.e = float(proposal.cooldowns_after.e)
  result["b04_completion"] = proposal.duplicate(true)
  result["b04_run_id"] = _run_id
  if receipts.has(command_id): receipts[command_id].result = result.duplicate(true)
 _b04_original_event = {}
 _b04_trusted = {}
 # The leaf emits the ORIGINAL completion next. Diagnostics are emitted only
 # after those observers, and only if that exact run/scope is still current.
 return result

func _apply(action: String, args: Dictionary) -> String:
 if action != "b04_verified_basic_completion": return super._apply(action,args)
 if _b04_trusted.is_empty() or args != _b04_trusted or _b04_original_event.is_empty(): return "b04_verified_terminal_required"
 var sim: Node = _health_sim.get_ref() if _health_sim != null else null
 if not _b04_bound(sim) or state.phase != "combat" or state.get("actor_dead",false) or sim.phase != "combat" or sim.paused or sim.hero.dead: return "b04_live_scope_required"
 if str(args.run_id) != _run_id or str(args.actor_id) != str(state.actor_id) or args.passive_id != BasicCycle.PASSIVE_ID: return "b04_player_run_passive_mismatch"
 var scope: Dictionary = {"run_id":_run_id,"generation":sim.encounter_generation,"room_id":sim.room_id}
 if args.scope != scope or str(state.combat_level_id) != str(sim.combat_level_id): return "b04_scope_changed"
 var evidence: Dictionary = sim.verify_b04_basic_completion(self,_b04_original_event,_run_id)
 if evidence.is_empty() or evidence != args.evidence: return "b04_terminal_witness_changed"
 var progress: Dictionary = _b04_progress()
 var claims: Dictionary = _b04_claims(progress,scope)
 var selected: Dictionary = BasicCycle.select_unique(state.inventory,runtime_stat_definitions)
 var cooldowns: Dictionary = {"q":sim.hero.cooldowns.get("q"),"e":sim.hero.cooldowns.get("e")}
 var proposal: Dictionary = BasicCycle.evaluate_verified_completion(selected,progress.remainder,claims,scope,cooldowns,evidence)
 if not proposal.get("eligible",false) or proposal != args.proposal: return "b04_proposal_changed"
 claims.by_cast[proposal.claim_to_add.cast_id] = proposal.claim_to_add.wave_id
 progress.remainder = int(proposal.remainder_after)
 progress.claims = claims
 state["b04_basic_cycle"] = progress
 return ""

func _b04_progress() -> Dictionary:
 # Fresh run construction has no old counter. A different saved run identity
 # cannot carry partial progress into this bound run. Commerce/room changes do
 # not erase this state: selling the last copy merely prevents further counts.
 var saved: Dictionary = state.get("b04_basic_cycle",{})
 if saved.get("run_id") == _run_id and saved.get("actor_id") == state.actor_id and saved.get("passive_id") == BasicCycle.PASSIVE_ID:
  return saved.duplicate(true)
 return {"run_id":_run_id,"actor_id":state.actor_id,"passive_id":BasicCycle.PASSIVE_ID,"remainder":0,"claims":{"scope":{},"by_cast":{}}}

func _b04_claims(progress: Dictionary, scope: Dictionary) -> Dictionary:
 var claims: Dictionary = progress.claims
 if claims.scope == scope: return claims.duplicate(true)
 # Technical stale-cast cleanup is separate from the approved run remainder.
 return {"scope":scope.duplicate(true),"by_cast":{}}

func basic_cycle_status() -> Dictionary:
 var progress: Dictionary = _b04_progress()
 var selected: Dictionary = BasicCycle.select_unique(state.inventory,runtime_stat_definitions)
 var active: bool = selected.equipped and equipment_runtime_status(BasicCycle.ITEM_ID).get("supported",false)
 return {"passive_id":BasicCycle.PASSIVE_ID,"remainder":progress.remainder,"equipped":selected.equipped,"owned_copies":selected.owned_copies,"active_copies":1 if active else 0,"tuning":selected.tuning,"retained_across_rooms":true,"retained_when_sold":true,"accumulates_unequipped":false,"reset_on_new_run":true}

func equipment_effects() -> Dictionary:
 var out: Dictionary = super.equipment_effects()
 var selected: Dictionary = BasicCycle.select_unique(state.inventory,runtime_stat_definitions)
 if selected.equipped and equipment_runtime_status(BasicCycle.ITEM_ID).get("supported",false) and BasicCycle.PASSIVE_ID not in out.passives: out.passives.append(BasicCycle.PASSIVE_ID)
 return out

func snapshot() -> Dictionary:
 var out: Dictionary = super.snapshot()
 out.content_profile = "ordinary_equipment38_potions3"
 out.content_warnings = [{"reason":"other34_finals_flasks_elixirs_held"}]
 out["b04_basic_cycle"] = basic_cycle_status()
 return out
