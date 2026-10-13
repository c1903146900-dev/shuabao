extends "res://equipment_pursuit_20261009/model.gd"
## Per-run, per-actual-room quota. Original shield storage/tick/absorption owns
## the granted shield; no shield copy is persisted or restored by this Model.
const Lifeline = preload("passive20.gd")
var _d04_trusted: Dictionary = {}
var _d04_original_metadata: Dictionary = {}

func _d04_bound(sim: Node) -> bool:
 return _b02_bound(sim) and sim.has_method("verify_d04_hp_commit") and sim.has_method("d04_model_is_bound") and sim.d04_model_is_bound(self)

func equipment_runtime_status(id: String) -> Dictionary:
 var out: Dictionary = super.equipment_runtime_status(id)
 if id != Lifeline.ITEM_ID or not out.get("supported",false): return out
 var sim: Node = _health_sim.get_ref() if _health_sim != null else null
 if not _d04_bound(sim): return {"supported":false,"reason":"d04_original_hp_commit_not_bound"}
 out.runtime_complete = true;out.shop_admitted = true
 out.runtime_status = "original_damage_room_quota_and_shield_bound"
 return out

func record_verified_lifeline_damage(sim: Node, metadata: Dictionary) -> Dictionary:
 if not _d04_bound(sim) or not _d04_trusted.is_empty(): return _deny("d04_original_hp_commit_required")
 var evidence: Dictionary = sim.verify_d04_hp_commit(self,metadata,_run_id)
 if evidence.is_empty(): return _deny("d04_original_hp_commit_required")
 var scope: Dictionary = _g02_scope(sim)
 var selected: Dictionary = Lifeline.select_unique(state.inventory,runtime_stat_definitions)
 var proposal: Dictionary = Lifeline.propose(selected,_d04_quota(),scope,evidence)
 if not proposal.get("eligible",false): return _deny(str(proposal.reason))
 var request: Dictionary = {"run_id":_run_id,"scope":scope,"evidence":evidence,"proposal":proposal}
 var command_id: String = "equipment-d04:" + JSON.stringify([_run_id,state.actor_id,scope.room_id])
 _d04_trusted = request.duplicate(true)
 _d04_original_metadata = metadata
 var result: Dictionary = command(command_id,"d04_verified_room_shield",request)
 # No outward callback has occurred during the non-commerce command. Clear
 # private command admission before add_shield emits: nested actual damage may
 # arrive then, and the original room quota is already irrevocably consumed.
 _d04_original_metadata = {};_d04_trusted = {}
 if result.get("accepted",false) and not result.get("replayed",false):
  assert(_d04_bound(sim) and _g02_scope(sim) == scope)
  assert(sim.hero.hp == float(evidence.commit.hp_after) and sim.hero.hp > 0.0 and not sim.hero.dead)
  assert(float(sim.hero.stats.max_hp) == float(proposal.trigger_max_hp))
  # Existing add_shield writes the real shield before its original shield
  # observer. It owns metadata, absorption, lifetime and outward notification.
  sim.add_shield(proposal.shield_id,proposal.shield_amount,proposal.duration,{"equipment_id":Lifeline.ITEM_ID,"passive_id":Lifeline.PASSIVE_ID,"trigger_room_id":scope.room_id,"trigger_generation":scope.generation,"trigger_max_hp":proposal.trigger_max_hp})
  result["d04_shield"] = proposal.duplicate(true)
  if receipts.has(command_id): receipts[command_id].result = result.duplicate(true)
 return result

func _apply(action: String, args: Dictionary) -> String:
 if action != "d04_verified_room_shield": return super._apply(action,args)
 if _d04_trusted.is_empty() or args != _d04_trusted: return "d04_original_hp_commit_required"
 var sim: Node = _health_sim.get_ref() if _health_sim != null else null
 if not _d04_bound(sim) or args.run_id != _run_id or state.phase != "combat" or state.get("actor_dead",false) or state.get("test_mode",false): return "d04_live_original_owner_required"
 if sim.phase != "combat" or sim.paused or sim.hero.dead or sim.hero.hp <= 0.0 or state.combat_level_id != sim.combat_level_id or args.scope != _g02_scope(sim): return "d04_current_original_room_required"
 var evidence: Dictionary = sim.verify_d04_hp_commit(self,_d04_original_metadata,_run_id)
 if evidence.is_empty() or evidence != args.evidence: return "d04_original_hp_witness_changed"
 var quota: Dictionary = _d04_quota()
 var selected: Dictionary = Lifeline.select_unique(state.inventory,runtime_stat_definitions)
 var proposal: Dictionary = Lifeline.propose(selected,quota,args.scope,evidence)
 if not proposal.get("eligible",false) or proposal != args.proposal: return "d04_shield_proposal_changed"
 quota.rooms[proposal.claim_room] = true
 state["d04_lifeline_quota"] = quota
 return ""

func _d04_quota() -> Dictionary:
 var saved: Dictionary = state.get("d04_lifeline_quota",{})
 if saved.get("run_id") == _run_id and saved.get("actor_id") == state.actor_id and saved.get("passive_id") == Lifeline.PASSIVE_ID: return saved.duplicate(true)
 return {"run_id":_run_id,"actor_id":state.actor_id,"passive_id":Lifeline.PASSIVE_ID,"rooms":{}}

func lifeline_status() -> Dictionary:
 var sim: Node = _health_sim.get_ref() if _health_sim != null else null
 var room: String = str(sim.room_id) if _d04_bound(sim) else ""
 var quota: Dictionary = _d04_quota()
 var selected: Dictionary = Lifeline.select_unique(state.inventory,runtime_stat_definitions)
 var shield: Dictionary = sim.hero.shields.get(Lifeline.SHIELD_ID,{}) if _d04_bound(sim) else {}
 return {"passive_id":Lifeline.PASSIVE_ID,"equipped":selected.equipped,"owned_copies":selected.owned_copies,"room_id":room,"used_in_room":quota.rooms.has(room),"shield_amount":float(shield.get("amount",0.0)),"shield_remaining":float(shield.get("left",0.0)),"quota_scope":"run_and_actual_room_id","low_hp_entry_first_wound":true,"sold_existing_shield_retained":true,"generation_resets_quota":false,"rest_clears_shield":true}

func equipment_effects() -> Dictionary:
 var out: Dictionary = super.equipment_effects()
 var selected: Dictionary = Lifeline.select_unique(state.inventory,runtime_stat_definitions)
 if selected.equipped and equipment_runtime_status(Lifeline.ITEM_ID).get("supported",false) and Lifeline.PASSIVE_ID not in out.passives: out.passives.append(Lifeline.PASSIVE_ID)
 return out

func snapshot() -> Dictionary:
 var out: Dictionary = super.snapshot()
 out.content_profile = "ordinary_equipment41_potions3"
 out.content_warnings = [{"reason":"other31_finals_flasks_elixirs_held"}]
 out["d04_lifeline"] = lifeline_status()
 return out
