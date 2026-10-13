extends "res://equipment_training_20261009/model.gd"
## One real-owner buff; no independent timer, kill source, task or reward.
const PursuitPrepared = preload("passive28.gd")
const PursuitRuntime = preload("runtime28.gd")
var _b02_hero: WeakRef
var _b02_common: WeakRef
var _b02_clock: WeakRef
var _b02_trusted: Dictionary = {}
var _b02_original_event: Dictionary = {}

func bind_floor(owner: RefCounted, sim: Node, run_id: String) -> Dictionary:
 if not is_instance_valid(sim) or not sim.has_method("b02_model_is_bound") or not sim.b02_model_is_bound(self): return _deny("b02_original_death_and_stats_bridge_required")
 var result: Dictionary = super.bind_floor(owner,sim,run_id)
 if result.get("accepted",false):
  _b02_hero = weakref(sim.hero)
  _b02_common = weakref(sim.common)
  _b02_clock = weakref(sim.common.runtime)
 return result

func _b02_bound(sim: Node) -> bool:
 if not _g02_bound(sim,_run_id) or _b02_hero == null or _b02_common == null or _b02_clock == null: return false
 if not is_same(_b02_hero.get_ref(),sim.hero) or not is_same(_b02_common.get_ref(),sim.common) or not is_same(_b02_clock.get_ref(),sim.common.runtime): return false
 return sim.b02_model_is_bound(self)

func equipment_runtime_status(id: String) -> Dictionary:
 var out: Dictionary = super.equipment_runtime_status(id)
 if id != PursuitPrepared.ITEM_ID or not out.get("supported",false): return out
 var sim: Node = _health_sim.get_ref() if _health_sim != null else null
 if not _b02_bound(sim): return {"supported":false,"reason":"b02_original_owner_clock_stats_not_bound"}
 out.runtime_complete = true;out.shop_admitted = true
 out.runtime_status = "source_solo_death_owner_clock_buff_bound"
 return out

func _b02_context(sim: Node) -> Dictionary:
 if not _b02_bound(sim): return {}
 return {"scope":_g02_scope(sim),"owner_token":str(sim.hero.get_instance_id()),"clock_token":str(sim.common.runtime.get_instance_id()),"clock":"original_common_actor_time","now":float(sim.common.runtime.actor_time),"owner_alive":not sim.hero.dead}

func b02_buff_effect(sim: Node) -> Dictionary:
 if not _b02_bound(sim): return {"eligible":false,"active":false,"move_fraction":0.0,"attack_speed_fraction":0.0,"remaining":0.0}
 var saved: Variant = sim.hero.cast_state.get(PursuitRuntime.BUFF_KEY,{})
 if not saved is Dictionary: return {"eligible":false,"active":false,"move_fraction":0.0,"attack_speed_fraction":0.0,"remaining":0.0}
 return PursuitRuntime.inspect(saved,_b02_context(sim))

func record_battle_event(sim: Node, event: Dictionary, run_id: String) -> Dictionary:
 # All original progression, B01, G06, B04 and G02 processing stays first.
 var prior: Dictionary = super.record_battle_event(sim,event,run_id)
 if not prior.get("accepted",false) or event.get("kind") != "kill" or run_id != _run_id or not _b02_bound(sim) or not _b02_trusted.is_empty(): return prior
 var selected: Dictionary = PursuitPrepared.select_unique(state.inventory,runtime_stat_definitions)
 if not selected.equipped: return prior
 var evidence: Dictionary = sim.verify_g02_kill_attribution(self,event,run_id)
 if evidence.is_empty(): return prior
 var context: Dictionary = _b02_context(sim)
 var previous: Variant = sim.hero.cast_state.get(PursuitRuntime.BUFF_KEY,{})
 if not previous is Dictionary: return prior
 var proposal: Dictionary = PursuitRuntime.propose(selected,previous,_b02_claims(context.scope),context,evidence)
 if not proposal.get("eligible",false): return prior
 var request: Dictionary = {"run_id":run_id,"context":context,"evidence":evidence,"proposal":proposal}
 var command_id: String = "equipment-b02:" + JSON.stringify([run_id,state.actor_id,context.scope.generation,context.scope.room_id,proposal.claim_to_add.target_id])
 _b02_trusted = request.duplicate(true)
 _b02_original_event = event
 var result: Dictionary = command(command_id,"b02_verified_death_buff",request)
 # Original non-commerce command path has no outward callbacks. Claim/receipt
 # commit and real buff publication happen synchronously before any observer.
 if result.get("accepted",false) and not result.get("replayed",false):
  assert(_b02_bound(sim) and _b02_context(sim) == context)
  assert(sim.hero.cast_state.get(PursuitRuntime.BUFF_KEY,{}) == proposal.prior_buff)
  sim.hero.cast_state[PursuitRuntime.BUFF_KEY] = proposal.buff.duplicate(true)
  # Valid also inside the original synchronous birth transaction. This bridge
  # only projects stats; do not call the transaction-guarded stat consumer.
  sim.common.refresh_stats()
  result["b02_buff"] = proposal.buff.duplicate(true)
  if receipts.has(command_id): receipts[command_id].result = result.duplicate(true)
 _b02_original_event = {};_b02_trusted = {}
 if not result.get("accepted",false): return result
 var out: Dictionary = prior.duplicate(true)
 out.merge(result,true)
 out.events = prior.get("events",[]).duplicate(true) + result.get("events",[]).duplicate(true)
 out["b02_pursuit"] = pursuit_buff_status()
 return out

func _apply(action: String, args: Dictionary) -> String:
 if action != "b02_verified_death_buff": return super._apply(action,args)
 if _b02_trusted.is_empty() or args != _b02_trusted or _b02_original_event.is_empty(): return "b02_original_death_required"
 var sim: Node = _health_sim.get_ref() if _health_sim != null else null
 if not _b02_bound(sim) or args.run_id != _run_id or state.phase != "combat" or state.get("actor_dead",false) or state.get("test_mode",false): return "b02_live_original_owner_required"
 if sim.phase != "combat" or sim.hero.dead or state.combat_level_id != sim.combat_level_id or args.context != _b02_context(sim): return "b02_original_scope_clock_changed"
 var verified: Dictionary = BattleEvents.verify(sim,self,_b02_original_event,_run_id)
 if verified.has("error"): return str(verified.error)
 var evidence: Dictionary = sim.verify_g02_kill_attribution(self,_b02_original_event,_run_id)
 if evidence.is_empty() or evidence != args.evidence: return "b02_original_death_witness_changed"
 var previous: Variant = sim.hero.cast_state.get(PursuitRuntime.BUFF_KEY,{})
 if not previous is Dictionary: return "b02_invalid_actual_buff"
 var selected: Dictionary = PursuitPrepared.select_unique(state.inventory,runtime_stat_definitions)
 var claims: Dictionary = _b02_claims(args.context.scope)
 var proposal: Dictionary = PursuitRuntime.propose(selected,previous,claims,args.context,evidence)
 if not proposal.get("eligible",false) or proposal != args.proposal: return "b02_buff_proposal_changed"
 claims.by_target[proposal.claim_to_add.target_id] = proposal.claim_to_add.death_commit_id
 state["b02_death_claims"] = claims
 return ""

func _b02_claims(scope: Dictionary) -> Dictionary:
 var saved: Dictionary = state.get("b02_death_claims",{})
 if saved.get("scope") == scope and saved.get("by_target") is Dictionary: return saved.duplicate(true)
 return {"scope":scope.duplicate(true),"by_target":{}}

func pursuit_buff_status() -> Dictionary:
 var sim: Node = _health_sim.get_ref() if _health_sim != null else null
 var view: Dictionary = b02_buff_effect(sim)
 var selected: Dictionary = PursuitPrepared.select_unique(state.inventory,runtime_stat_definitions)
 return {"passive_id":PursuitPrepared.PASSIVE_ID,"equipped":selected.equipped,"owned_copies":selected.owned_copies,"active":view.get("active",false),"active_copies":1 if view.get("active",false) else 0,"remaining":view.get("remaining",0.0),"move_fraction":view.get("move_fraction",0.0),"attack_speed_fraction":view.get("attack_speed_fraction",0.0),"clock":"original_common_actor_time","retained_when_sold":true,"rebuy_refreshes":false,"retained_across_rooms":true,"safe_clock_paused":true,"rest_clears":true,"multiplayer_supported":false}

func equipment_effects() -> Dictionary:
 var out: Dictionary = super.equipment_effects()
 var selected: Dictionary = PursuitPrepared.select_unique(state.inventory,runtime_stat_definitions)
 if selected.equipped and equipment_runtime_status(PursuitPrepared.ITEM_ID).get("supported",false) and PursuitPrepared.PASSIVE_ID not in out.passives: out.passives.append(PursuitPrepared.PASSIVE_ID)
 return out

func snapshot() -> Dictionary:
 var out: Dictionary = super.snapshot()
 out.content_profile = "ordinary_equipment40_potions3"
 out.content_warnings = [{"reason":"other32_finals_flasks_elixirs_held"}]
 out["b02_pursuit"] = pursuit_buff_status()
 return out
