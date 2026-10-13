extends "res://tests/ink_first_floor_flow_20261004/floor_coordinator.gd"
## UI/room adapter over the same run ledger. Reuses actual reward, terminal,
## growth, input-suspension and close contracts. Never supplies money or gear.
const Bridge = preload("res://tests/ink_shop_runtime_stats_20261004/hp_undo_fix01/ink_health_bridge.gd")
const Consumers = preload("res://tests/ink_shop_runtime_stats_20261004/ink_stat_consumer.gd")
const SHOP = "res://tests/ink_first_floor_flow_20261004/fixtures/provisional_shop.json"
const FIXTURE = "res://tests/equipment_shop_transactions_20261004/fixtures/source_prices.json"
const NUMERIC = "res://tests/equipment_editable_tables_20261004/outputs/equipment_tables/converted/equipment_numeric_config.json"
const TESTED_BINDING = "res://tests/ink_shop_runtime_stats_20261004/source_binding.json"
const EARN_ROOM_ENEMIES = 23
var diagnostic_run: bool = false
var panel_open: bool = false
var serial: int = 0
var spawned_in_room: int = 0
var required_in_room: int = 0
var terminal_pending: Dictionary = {}
var last_receipt: Dictionary = {}
var session_events: Array = []
var consumers = Consumers.new()
var _transitioning: bool = false
var _panel_previous_pause: bool = false

static func capabilities() -> Dictionary:
 var hooks: Array = ["stats.v1", "equipment.task_completion.v1", "hex.final_design.yanguizhou_h01.v1"]
 for stat in ["AD","AP","attack_speed","max_hp","defense","move_speed","crit_chance","cooldown_reduction","lifesteal","tenacity","penetration","hp_regen"]: hooks.append("stat."+stat+".v1")
 return {"schema_version":1,"hero_id":"yanguizhou","source_binding_id":FileAccess.get_sha256(TESTED_BINDING),"runtime_candidates":["Q1"],"supported_hooks":hooks}
func initialize_session(source_sim: Node, new_run_id: String, diagnostic: bool = false) -> Dictionary:
 if status != "unbound" or not is_instance_valid(source_sim) or new_run_id.is_empty(): return _deny("fresh_session_required")
 var candidate = Bridge.new()
 var initialized: Dictionary = candidate.initialize_runtime_fixture(source_sim,capabilities(),SHOP,FIXTURE,NUMERIC,self,new_run_id,true)
 if not initialized.accepted: return initialized
 var s: Dictionary = candidate.model.snapshot()
 if s.level != 1 or s.gold != 0 or s.xp != 0 or s.points != 1 or not s.inventory.is_empty() or not s.selected_hex.is_empty(): return _deny("fresh_zero_gold_authority_required")
 var bound: Dictionary = candidate.model.bind_floor(self,source_sim,new_run_id)
 if not bound.accepted: return bound
 sim=source_sim;ledger=candidate;run_id=new_run_id;diagnostic_run=diagnostic
 sim.set_progression(ledger)
 sim.auto_finish=false
 route={"floor_id":"shop_runtime_diagnostic" if diagnostic else "ordinary_first_floor_pending","version":"shop-ui-source-01","content_status":"explicit_diagnostic_not_first_floor" if diagnostic else "pending_authoring","nodes":[{"id":"earn","kind":"ordinary","training_after":false},{"id":"verify","kind":"ordinary","training_after":false}]}
 status="preparation";growth_dirty=true
 var entered: Dictionary = _authority("enter_room",{"next_room":run_id+"/initial-safe"})
 if not entered.accepted:return entered
 if diagnostic:
  # Explicit approved diagnostic learning spends the real sole Lv1 SP.
  var learned: Dictionary=sim.learn_ability("Q","Q1")
  if not learned.get("ok",false):return _deny("diagnostic_Q1_learning_failed")
 session_events.append({"type":"initialized","diagnostic":diagnostic,"gold":ledger.model.state.gold,"level":ledger.model.state.level,"points":ledger.model.state.points,"source":"fresh real ledger, no fixture funding"})
 return {"accepted":true,"reason":"","diagnostic":diagnostic}
func _authority(action: String, extra: Dictionary = {}) -> Dictionary:
 serial+=1
 var args: Dictionary=ledger.model.commerce_token();args.merge(extra,true)
 return ledger.shop_authority(self,"shop-session-authority:%d"%serial,action,args)
func _ui_command(action: String, extra: Dictionary = {}) -> Dictionary:
 serial+=1
 var args: Dictionary=ledger.model.commerce_token();args.merge(extra,true)
 return ledger.shop_command("shop-session-ui:%d"%serial,action,args)
func safe_shop_reason() -> String:
 if ledger==null or not is_instance_valid(sim):return "session_unavailable"
 if sim.transaction_active or _transitioning:return "defer_to_outer_boundary"
 if sim.hero.dead or status in ["defeated","aborted"]:return "not_alive"
 if status not in ["preparation","between_rooms","diagnostic_complete"] or sim.phase not in ["preparation","victory"] or ledger.model.state.phase!="safe":return "shop_after_real_battle_only"
 return ""
func open_panel() -> Dictionary:
 var reason: String=safe_shop_reason()
 if not reason.is_empty():return _record(_deny(reason))
 if panel_open:return {"accepted":true,"reason":"already_open"}
 # A panel close is not an area exit. Reopening retains the same visit journal.
 if not ledger.model.state.shop_visit.shop_active:
  var visit: Dictionary=_authority("begin_visit",{"area":str(ledger.model.state.shop_visit.room_id)+"/safe-shop"})
  if not visit.accepted:return _record(visit)
 var opened: Dictionary=_ui_command("open_ui")
 if not opened.accepted:return _record(opened)
 _panel_previous_pause=sim.paused
 if _input_suspender.is_valid():_input_suspender.call("shop_open")
 sim.hero.move_intent=Vector3.ZERO;sim.paused=true;panel_open=true
 return _record(opened)
func close_panel() -> Dictionary:
 if not panel_open:return {"accepted":true,"reason":"already_closed"}
 if sim.transaction_active or _transitioning:return _record(_deny("defer_to_outer_boundary"))
 var closed: Dictionary=_ui_command("close_ui")
 if not closed.accepted:return _record(closed)
 if _input_suspender.is_valid():_input_suspender.call("shop_close_release_required")
 panel_open=false;sim.paused=_panel_previous_pause
 return _record(closed)
func focus_lost() -> void:
 if is_instance_valid(sim):sim.paused=true
 if panel_open:_panel_previous_pause=true
func submit(id: String, action: String, args: Dictionary) -> Dictionary:
 if not panel_open:return _record(_deny("shop_panel_not_open"))
 var reason: String=safe_shop_reason()
 if not reason.is_empty():return _record(_deny(reason))
 if action not in ["buy","sell","undo"]:return _record(_deny("ui_operation_not_supported"))
 var result: Dictionary=ledger.shop_command(id,action,args)
 if result.accepted:growth_dirty=true
 return _record(result)
func learn_q1() -> Dictionary:
 if not safe_shop_reason().is_empty() or sim.transaction_active:return _record(_deny("learning_not_safe"))
 var result: Dictionary=sim.learn_ability("Q","Q1")
 growth_dirty=growth_dirty or bool(result.get("ok",false))
 return _record({"accepted":result.get("ok",false),"reason":result.get("reason","")})
func next_room_preflight() -> Dictionary:
 if not safe_shop_reason().is_empty():return _deny(safe_shop_reason())
 if panel_open:return _deny("close_shop_before_room_transition")
 if sim.paused:return _deny("resume_before_room_transition")
 if not terminal_pending.is_empty():return _deny("terminal_settlement_pending")
 var s: Dictionary=ledger.model.snapshot()
 if not s.body_pending.is_empty():return _deny("body_choice_pending")
 if not diagnostic_run:
  if not s.pending_milestones.is_empty():return _deny("mandatory_hex_pool_not_ready")
  return _deny("ordinary_12_row_content_unconfigured")
 if node_index>=2 or status=="diagnostic_complete":return _deny("diagnostic_segment_complete")
 if not _input_suspender.is_valid():return _deny("input_suspender_missing")
 var next_room: String=run_id+"/diagnostic-room-%d"%(node_index+1)
 if next_room in ledger.model.state.visited_levels or next_room==str(ledger.model.state.shop_visit.room_id):return _deny("fresh_room_required")
 return {"accepted":true,"reason":"","next_room":next_room,"source_phase":sim.phase,"ledger_revision":s.revision,"diagnostic_only":true}
func start_next_room() -> Dictionary:
 var ready: Dictionary=next_room_preflight()
 if not ready.accepted:return _record(ready)
 # All fallible source/ledger preconditions precede the irreversible room commit.
 # No callback or await is interleaved between these synchronous accepted steps.
 _transitioning=true
 var committed: Dictionary=_authority("enter_room",{"next_room":ready.next_room})
 if not committed.accepted:_transitioning=false;return _record(committed)
 var entered: Dictionary=ledger.command("enter_level",{"combat_level_id":ready.next_room})
 if not entered.ok:
  status="faulted";_transitioning=false
  return _record(_deny("unexpected_post_commit_enter_level_failure:"+str(entered.reason)))
 _input_suspender.call("next_room_release_required")
 current_room_id=ready.next_room;current_generation=sim.encounter_generation+1
 required_in_room=EARN_ROOM_ENEMIES if node_index==0 else 1;spawned_in_room=1
 kill_receipts.clear();expected_enemies.clear();boss_id=""
 sim.auto_finish=required_in_room==1
 status="combat"
 var started: Dictionary=sim.begin_encounter(current_room_id,[{"kind":"minion","position":Vector3(0,0,-5)}])
 if not started.accepted:
  status="faulted";_transitioning=false
  return _record(_deny("unexpected_post_commit_sim_start_failure:"+str(started.reason)))
 current_generation=sim.encounter_generation
 for enemy in sim.enemies:expected_enemies.append(str(enemy.actor_id))
 growth_dirty=true;_transitioning=false
 session_events.append({"type":"room_committed","room":current_room_id,"generation":current_generation,"required_actual_minions":required_in_room,"gold":ledger.model.state.gold,"inventory":ledger.model.state.inventory.duplicate(true)})
 return _record({"accepted":true,"reason":"actual_diagnostic_combat_started"})
func queue_terminal(source_sim: Node, actual_snapshot: Dictionary) -> void:
 if is_same(source_sim,sim):terminal_pending=actual_snapshot.duplicate(true)
func update_after_source_step() -> void:
 if not is_instance_valid(sim) or sim.transaction_active or _transitioning:return
 if not terminal_pending.is_empty():
  var actual: Dictionary=terminal_pending;terminal_pending={}
  var result: Dictionary=super.finish(sim,actual)
  if result.accepted and status=="between_rooms" and node_index>=2:status="diagnostic_complete"
  _record(result)
 if status=="combat" and sim.phase=="combat" and not sim.hero.dead and sim.living().is_empty():
  if spawned_in_room<required_in_room:
   # Real sequential source spawns; no time, HP, reward or death alteration.
   var enemy: Dictionary=sim.spawn_enemy("minion",Vector3(0,0,-5))
   expected_enemies.append(str(enemy.actor_id));spawned_in_room+=1
  if spawned_in_room>=required_in_room:sim.auto_finish=true
 if growth_dirty:flush_growth(consumers)
func ui_state() -> Dictionary:
 if ledger==null:return {"ready":false,"reason":"session_unavailable"}
 var state: Dictionary=ledger.model.snapshot()
 return {"ready":true,"run":snapshot(),"diagnostic":diagnostic_run,"panel_open":panel_open,"state":state,"catalog":ledger.model.shop_catalog(),"stats":sim.hero.stats.duplicate(true),"hp":sim.hero.hp,"next_room":next_room_preflight(),"spawned":spawned_in_room,"required":required_in_room,"kills":kill_receipts.size(),"last_receipt":last_receipt.duplicate(true)}
func _record(result: Dictionary) -> Dictionary:
 last_receipt=result.duplicate(true)
 return result
func close_run() -> Dictionary:
 panel_open=false
 return super.close_run()
