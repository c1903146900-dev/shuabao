extends RefCounted
## A single Session's already-entered rest settlement. No wallet or floor owner.
const RULE_PATH := "res://docs/source_decisions/20261006-ink-five-resolutions.json"
const RULE_SHA := "861528d850389b2b4be2ce7a9ad4461531bbbfbd33de113870f9955b721f3e39"
var _owner: WeakRef
var _settlements: Dictionary = {}

func _init(owner: RefCounted) -> void:
 _owner = weakref(owner)

func settle(owner: RefCounted, entered: Dictionary) -> Dictionary:
 if not is_instance_valid(owner) or _owner == null or not is_same(_owner.get_ref(),owner): return _deny("wrong_rest_owner")
 if not is_instance_valid(owner.sim) or not owner._owner_intact(): return _deny("rest_owner_unbound")
 if owner.sim.transaction_active or owner._transitioning: return _deny("defer_to_outer_boundary")
 if owner.sim.hero.dead: return _deny("rest_owner_not_alive")
 if not owner._entered_service("rest") or owner._active_entry != entered: return _deny("committed_rest_entry_required")
 if not owner.row_state._bindings_intact(): return _deny("immutable_binding_changed")
 if FileAccess.get_sha256(RULE_PATH) != RULE_SHA: return _deny("rest_rule_binding_changed")
 var boundary: String = owner._safe_boundary_reason()
 if not boundary.is_empty(): return _deny(boundary)
 var payload: Dictionary = entered.get("payload",{})
 var entry_id: String = str(entered.get("receipt_id",""))
 if entry_id.is_empty() or str(payload.get("entry_id","")) != entry_id or str(payload.get("service_type","")) != "rest" or str(payload.get("room_id","")) != owner.active_node_room or str(entered.get("identity",{}).get("run_id","")) != owner.run_id: return _deny("rest_entry_identity_mismatch")
 var key: String = JSON.stringify([owner.run_id,owner.active_node_room,entry_id])
 if _settlements.has(key):
  var replay: Dictionary = _settlements[key].duplicate(true)
  replay["replayed"] = true
  return replay
 var sim: Node = owner.sim
 var before_hp: float = sim.hero.hp
 var before_revision: int = sim.equipment_health_revision
 var before_flasks: int = owner.ledger.model.state.shop_visit.flask_charges
 # Reserve before callbacks. Public Session and Sim actions cannot re-enter.
 _settlements[key] = {"accepted":false,"reason":"rest_settlement_in_progress"}
 owner._transitioning = true
 sim.transaction_active = true
 sim.observe_pending_health()
 _clear_live_state(sim)
 var healed: float = sim.heal(float(sim.hero.stats.max_hp),false,{"source":"rest_service","run_id":owner.run_id,"room_id":owner.active_node_room,"entry_id":entry_id,"no_rescue_charge":true})
 # Healing observers may grant states. The final cleanup occurs AFTER healing,
 # and has no outward notification after its final scalar/dictionary writes.
 _clear_live_state(sim)
 if sim.has_method("p3_rest_settled"): sim.p3_rest_settled(owner)
 sim.observe_pending_health()
 sim.transaction_active = false
 owner._transitioning = false
 var result: Dictionary = {"accepted":true,"reason":"rest_settled","replayed":false,"run_id":owner.run_id,"room_id":owner.active_node_room,"entry_id":entry_id,"before_hp":before_hp,"after_hp":sim.hero.hp,"max_hp":sim.hero.stats.max_hp,"actual_heal":healed,"health_revision_before":before_revision,"health_revision_after":sim.equipment_health_revision,"flasks_before":before_flasks,"flasks_after":owner.ledger.model.state.shop_visit.flask_charges}
 _settlements[key] = result.duplicate(true)
 return result

func _clear_live_state(sim: Node) -> void:
 # Reuse the admitted P1 -> R1 -> E1 -> Q2 -> Q3 -> H02 -> Q1 chain.
 # This invalidates casts and deferred damage; it never begins an encounter.
 sim._clear_wave_transients()
 var h: RefCounted = sim.hero
 h.cast_state.clear(); h.shields.clear(); h.cooldowns.clear()
 h.cooldowns = {"attack":0.0,"shift":0.0,"q":0.0,"e":0.0,"r":0.0,"passive":0.0}
 h.lock_time = 0.0; h.movement_lock_left = 0.0; h.dash_left = 0.0
 h.invulnerable_left = 0.0; h.untargetable = false
 h.stun_left = 0.0; h.slow_left = 0.0; h.slow_amount = 0.0
 h.knockback = Vector3.ZERO; h.move_intent = Vector3.ZERO; h.standing_time = 0.0
 var bridge: RefCounted = sim.common
 var live: RefCounted = bridge.runtime
 bridge.end_room()
 bridge._pending_finishes.clear(); bridge._spatial_recorded.clear(); bridge._action_origins.clear()
 bridge._inside_hit = 0; bridge._shift_cast = 0
 # Timed common buffs, proc cooldowns, queued entities and delayed HP debt.
 # Preserve permanent G04 growth/G05 kill growth and selected-Hex ownership.
 live.form = ""; live.dash_stacks = 0; live.dash_until = 0.0
 live.final_until = 0.0; live.soul_speed_until = 0.0; live.boss_until = 0.0
 live.next_soul = 0.0; live.next_bombardment = 0.0; live.next_rescue = 0.0; live.next_turret = 0.0
 live.soul_kills = 0; live.replay_kills = 0; live.replay_charges = 0
 live.long_range_hits = 0; live.rescue_energy = 0.0
 live.debt.clear(); live.shrink.clear(); live.shield_break_cooldowns.clear()
 live.completed_actions.clear(); live.chain_counts.clear(); live._events.clear()
 # Never bake a previously buffed stat into the permanent projected base.
 bridge.refresh_stats(false)

func snapshot() -> Array:
 return _settlements.values().duplicate(true)

func _deny(reason: String) -> Dictionary:
 return {"accepted":false,"reason":reason}
