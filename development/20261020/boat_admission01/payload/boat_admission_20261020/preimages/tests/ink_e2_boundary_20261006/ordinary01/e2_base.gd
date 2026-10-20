extends "res://tests/ink_p1_ordinary_20261006/candidate01/lifesteal01/sim.gd"
## Base E2-only source candidate above frozen ordinary E1/Q2. NO host admission.
## Arena-contained testing only; boundary-exiting gameplay remains undecided.
const BoatCommon = preload("res://tests/ink_e2_boat_foundation_20261005/candidate04/boat_common_bridge.gd")
var ink_boat: Dictionary = {}
var ink_e2_receipts: Array = []
var ink_e2_finished: Array = []
var ink_e2_lifecycle: Array = []
var _boat_serial: int = 0
var _boat_pull_capture: Dictionary = {}
var _e2_accepted_direction: Vector3 = Vector3.ZERO
var _e2_packets: Dictionary = {}
var _e2_pending_sweep: Dictionary = {}
var _e2_pending_burst: Dictionary = {}
var _e2_pending_motion: Array = []
var _e2_pending_terminal: Dictionary = {}
var _e2_resume_trace: Array = []

func _init() -> void:
 super._init()
 # Keep the existing Q3 director for the unchanged explicit navigation installer.
 var values: Dictionary = common.context_values.duplicate(true)
 common = BoatCommon.new(self)
 common.context_values = values

func _e2_current(state: Dictionary) -> bool:
 return source_rules_hash == EXPECTED_RULES_HASH and not state.is_empty() and effect_is_current(state) and not hero.dead and is_same(hero, state.owner) and not bool(state.retired)
func _e2_live(state: Dictionary) -> bool:
 return _e2_current(state) and is_same(ink_boat, state)
func _e2_target_current(enemy: Dictionary, state: Dictionary) -> bool:
 return _e2_current(state) and not enemy.is_empty() and not enemy.dead and enemy.state != "spawn" and is_same(enemy, enemy_by_id(str(enemy.actor_id))) and int(enemy.generation) == encounter_generation and str(enemy.room_id) == room_id

func _request_action(action: String, aim: Vector3) -> Dictionary:
 if hero.loadout.e == "e2":
  if action == "ink_e_down": action = "e"
  elif action in ["ink_e_up", "e_release"]: return {"accepted":false, "reason":"boat_key_up_has_no_effect", "consumed":true}
 return super._request_action(action, aim)

func _e2_point_in_arena(point: Vector3) -> bool:
 if not point.is_finite(): return false
 var bound: float = maxf(0.0, arena_half_extent - hero_radius)
 return absf(point.x) <= bound + Geometry.EPS and absf(point.z) <= bound + Geometry.EPS

func _e2_landing_legal(point: Vector3) -> bool:
 # Teleport validates its destination only, never sweeps hero's old-to-new path
 # or projects the promised current boat point to a different location.
 if not _e2_point_in_arena(point): return false
 for obstacle in obstacles:
  var half: Vector3 = Vector3(obstacle.half) + Vector3(hero_radius, 0, hero_radius)
  var offset: Vector3 = point - Vector3(obstacle.position)
  if absf(offset.x) < half.x - Geometry.EPS and absf(offset.z) < half.z - Geometry.EPS: return false
 return true

func _e2_launch_admission(origin: Vector3, endpoint: Vector3) -> bool:
 # Approved rule: E2 boat may cross walls.
 # Wall presence never clips the boat, rejects launch, or consumes its root.
 # Retain only the existing independent arena-contained fixture boundary.
 return _e2_point_in_arena(origin) and _e2_point_in_arena(endpoint)

func _hero_action_policy(action: String, aim: Vector3 = Vector3.INF) -> Dictionary:
 if action != "e" or hero.loadout.e != "e2": return super._hero_action_policy(action, aim)
 if hero.has_hex("yanguizhou_h09") or hero.has_hex("yanguizhou_h10"): return {"reason":"base_E2_candidate_has_no_H09_H10"}
 if source_rules_hash != EXPECTED_RULES_HASH: return {"reason":"source_binding_mismatch"}
 if _e1_form_current(): return {"reason":"other_E_form_active"}
 if _ink_action_controlled(action): return {"reason":"controlled"}
 # Core asks the policy before its generic rank gate. Never query source
 # values for an unlearned E2 or manufacture a fallback rank.
 if int(hero.ranks.e) <= 0: return {"reason":"unlearned"}
 if not ink_boat.is_empty():
  if not _e2_live(ink_boat): return {"reason":"stale_boat"}
  if ink_boat.phase != "outward" or hero_time >= float(ink_boat.voyage_until) - TIME_EPS: return {"reason":"boat_boarding_window_closed"}
  if not _e2_landing_legal(ink_boat.position): return {"reason":"illegal_current_boat_landing"}
  if not _e2_arena_ready(ink_boat): return {"reason":"arena_reconfiguration_outside_fixture"}
  return {"cast_id":ink_boat.cast_id, "context":ink_boat.context, "stage":"boarding", "bypass_cooldown":true}
 if not aim.is_finite(): return {"reason":"manual_aim_required"}
 var delta: Vector3 = Geometry.ground(aim - hero.position)
 if delta.length_squared() <= Geometry.EPS * Geometry.EPS: return {"reason":"zero_manual_aim"}
 var rank: int = int(hero.ranks.e)
 var endpoint: Vector3 = hero.position + delta.normalized() * v("E2-1",rank) * v("E2-2",rank)
 if not _e2_launch_admission(hero.position, endpoint): return {"reason":"arena_route_outside_fixture"}
 _e2_accepted_direction = delta.normalized()
 return {"stage":"boat_launch"}

func _hero_cast_skill(action: String, context: Dictionary) -> Dictionary:
 if action != "e" or hero.loadout.e != "e2": return super._hero_cast_skill(action, context)
 if not effect_is_current(context): return {"accepted":false,"reason":"stale_cast"}
 if not ink_boat.is_empty(): return _e2_board(ink_boat, context)
 # Accepted E2 direction is independent of the shared facing display threshold.
 context.direction = _e2_accepted_direction
 var rank: int = int(hero.ranks.e)
 var ap: float = float(hero.stats.ap)
 _boat_serial += 1
 var state: Dictionary = context.duplicate(true)
 state.merge({"owner":hero,"context":context.duplicate(true),"boat_id":"%d:%s:boat:%d" % [encounter_generation,room_id,_boat_serial],"rank":rank,"born_at":hero_time,"position":Vector3(context.origin),"launch_position":Vector3(context.origin),"phase":"outward","phase_started_at":hero_time,"voyage_until":hero_time + v("E2-2",rank),"last_advanced_at":hero_time,"speed":v("E2-1",rank),"width":v("E2-3",rank),"outward_damage":v("E2-4",rank)+ap*T.fraction("E2-5",rank),"outward_cap":int(v("E2-6",rank)),"boarding_radius":v("E2-7",rank),"boarding_damage":v("E2-8",rank)+ap*T.fraction("E2-9",rank),"natural_radius":v("E2-10",rank),"natural_damage":v("E2-11",rank)+ap*T.fraction("E2-12",rank),"h09":false,"h10":false,"outward_hits":{},"return_hits":{},"hit_targets":{},"traveled_route":[Vector3(context.origin)],"retired":false,"boarded":false,"natural_burst_done":false,"damage_stages_complete":false,"inflight_packets":0,"completion_pending":{},"launch_arena_half_extent":arena_half_extent},true)
 ink_boat = state
 # Accepted real damaging effect launch, unlike uncommitted Q2/E3 placement.
 start_skill_cooldown("e", v("E2-13",rank))
 _equipment_release_committed("e2",state)
 _e2_event(state,"launched",hero_time)
 return {"accepted":true,"phase":"outward","boat_id":state.boat_id}

func _fixed_step(real_dt: float) -> void:
 # Resume only this skill's previously admitted local work. The inherited Q2
 # remainder then resumes in super before its one new world/core step.
 if paused: return
 var scope: Dictionary = _ink_scope()
 _e2_resume_local()
 if not _ink_scope_current(scope) or hero.dead: return
 if paused:
  real_accumulator += real_dt
  return
 super._fixed_step(real_dt)

func _e2_resume_local() -> void:
 var had_pending: bool = not _e2_pending_sweep.is_empty() or not _e2_pending_burst.is_empty() or not _e2_pending_motion.is_empty() or not _e2_pending_terminal.is_empty()
 if not had_pending: return
 _e2_trace({"event":"local_resume_begin","source_time":hero_time,"core_steps":ink_core_steps,"q2_remainder_present":not _q2_motion_resume.is_empty()})
 if not _e2_pending_sweep.is_empty():
  var sweep: Dictionary = _e2_pending_sweep; _e2_pending_sweep = {}
  if _e2_drain_sweep(sweep): _e2_outward_finished(sweep.state,float(sweep.end))
  if paused: return
 if not _e2_pending_burst.is_empty():
  var burst: Dictionary = _e2_pending_burst; _e2_pending_burst = {}
  _e2_drain_burst(burst)
  if paused: return
 while not _e2_pending_motion.is_empty():
  if paused: return
  var motion: Dictionary = _e2_pending_motion.pop_front()
  if _e2_live(motion.state) and motion.state.phase == "outward": _e2_contact(motion.state,motion.enemy,"outward_voyage",motion.position,float(motion.at),{})
 if not _e2_pending_terminal.is_empty() and not paused:
  var terminal: Dictionary = _e2_pending_terminal; _e2_pending_terminal = {}
  _e2_complete(terminal.state,terminal.reason,float(terminal.at))
 _e2_trace({"event":"local_resume_end","source_time":hero_time,"core_steps":ink_core_steps,"q2_remainder_present":not _q2_motion_resume.is_empty()})

func _e2_trace(event: Dictionary) -> void:
 _e2_resume_trace.append(event)
 while _e2_resume_trace.size()>32: _e2_resume_trace.pop_front()

func _hero_step(actor_dt: float, real_dt: float) -> void:
 super._hero_step(actor_dt,real_dt)
 if ink_boat.is_empty(): return
 if not _e2_live(ink_boat): _e2_abort_local(); return
 if not _e2_guard_arena(ink_boat): return
 _e2_advance(ink_boat,hero_time)

func _e2_arena_ready(state: Dictionary) -> bool:
 return is_equal_approx(arena_half_extent,float(state.launch_arena_half_extent))
func _e2_guard_arena(state: Dictionary) -> bool:
 if not _e2_live(state): return false
 if _e2_arena_ready(state): return true
 _e2_reject_changed_arena(state)
 return false

func _e2_reject_changed_arena(state: Dictionary) -> void:
 if not _e2_live(state): return
 var payload: Dictionary = _e2_public(state).merged({"reason":"arena_reconfiguration_outside_fixture","isolation_failure":true,"source_gameplay_outcome":false,"source_time":hero_time},true)
 # Only arena reconfiguration remains outside this fixture. Walls are approved
 # for boat traversal and never enter this diagnostic or end the boat.
 cancel_cast(int(state.cast_id))
 if effect_is_current(state): return
 if phase=="combat" and int(state.generation)==encounter_generation and str(state.room_id)==room_id and is_same(hero,state.owner): emit_event("ink_e2_isolation_blocked",payload)

func _e2_advance(state: Dictionary, until: float) -> void:
 if not _e2_guard_arena(state): return
 var start: float = float(state.last_advanced_at)
 if until <= start + TIME_EPS: return
 if state.phase == "outward":
  var finish: float = minf(until,float(state.voyage_until))
  var destination: Vector3 = Vector3(state.launch_position)+Vector3(state.direction)*float(state.speed)*(finish-float(state.born_at))
  var completed: bool = _e2_sweep_boat(state,destination,start,finish,"outward_voyage")
  if not completed or not _e2_live(state) or state.phase != "outward": return
  _e2_outward_finished(state,finish)

func _e2_sweep_boat(state: Dictionary, destination: Vector3, from_time: float, to_time: float, segment: String) -> bool:
 if not _e2_guard_arena(state): return false
 var origin: Vector3 = state.position
 var contacts: Array = []
 for enemy in enemies:
  if not _e2_target_current(enemy,state) or state.outward_hits.has(str(enemy.actor_id)): continue
  var fraction: float = Geometry.moving_front_contact(origin,destination,state.direction,float(state.width),enemy.position,enemy.position,float(enemy.radius))
  if is_finite(fraction): contacts.append({"enemy":enemy,"fraction":fraction})
 contacts.sort_custom(func(a,b): return str(a.enemy.actor_id)<str(b.enemy.actor_id) if a.fraction==b.fraction else float(a.fraction)<float(b.fraction))
 var work: Dictionary = {"state":state,"phase":state.phase,"origin":origin,"destination":destination,"start":from_time,"end":to_time,"segment":segment,"contacts":contacts,"cursor":0}
 return _e2_drain_sweep(work)

func _e2_drain_sweep(work: Dictionary) -> bool:
 var state: Dictionary = work.state
 while int(work.cursor) < work.contacts.size():
  if not _e2_guard_arena(state) or state.phase != work.phase: return false
  if paused:
   _e2_pending_sweep = work
   return false
  var contact: Dictionary = work.contacts[int(work.cursor)]
  work.cursor = int(work.cursor)+1
  state.position = Vector3(work.origin).lerp(work.destination,float(contact.fraction))
  if Vector3(state.traveled_route.back()).distance_squared_to(state.position)>Geometry.EPS*Geometry.EPS: state.traveled_route.append(Vector3(state.position))
  _e2_contact(state,contact.enemy,work.segment,state.position,lerpf(float(work.start),float(work.end),float(contact.fraction)),{})
 if not _e2_guard_arena(state) or state.phase != work.phase: return false
 if paused:
  _e2_pending_sweep = work
  return false
 state.position = work.destination
 if Vector3(state.traveled_route.back()).distance_squared_to(state.position)>Geometry.EPS*Geometry.EPS: state.traveled_route.append(Vector3(state.position))
 return true

func _e2_outward_finished(state: Dictionary, at: float) -> void:
 if not _e2_live(state) or state.phase != "outward": return
 state.last_advanced_at = at
 if at >= float(state.voyage_until)-TIME_EPS:
  _e2_natural_end(state,float(state.voyage_until))

func _e2_board(state: Dictionary, context: Dictionary) -> Dictionary:
 if not _e2_live(state) or int(context.cast_id)!=int(state.cast_id) or state.phase!="outward" or hero_time>=float(state.voyage_until)-TIME_EPS: return {"accepted":false,"reason":"boat_boarding_window_closed"}
 if not _e2_landing_legal(state.position): return {"accepted":false,"reason":"illegal_current_boat_landing"}
 if not _e2_arena_ready(state): return {"accepted":false,"reason":"arena_reconfiguration_outside_fixture"}
 var g01_board_from: Vector3 = hero.position
 state.boarded = true; state.boarding_position = Vector3(state.position)
 state.phase = "boarding_settlement"; state.phase_started_at = hero_time; state.last_advanced_at = hero_time
 hero.position = state.boarding_position
 _e2_pending_sweep = {}; _e2_pending_motion.clear()
 _equipment_effect_committed("e2",state,"e2_boarded",{"owner":hero,"from":g01_board_from,"to":Vector3(hero.position),"boarding_position":Vector3(state.boarding_position),"context":context,"source_time":hero_time})
 _e2_event(state,"boarded",hero_time)
 if not _e2_live(state): return {"accepted":true,"cancelled_during_callback":true}
 _e2_burst(state,"teleport_burst",float(state.boarding_radius),float(state.boarding_damage),hero_time,"boarded")
 return {"accepted":true,"phase":"boarded","boat_id":state.boat_id}

func _e2_burst(state: Dictionary, segment: String, radius: float, amount: float, at: float, completion: String) -> void:
 if not _e2_guard_arena(state): return
 var targets: Array = circle_targets(state.position,radius)
 common.refresh_stats()
 var impact: Dictionary = {"impact_penetration":float(hero.stats.penetration),"impact_lifesteal_rate":hero.lifesteal(),"ink_e2_impact_stats":common.context().hero.stats.duplicate(true)}
 var work: Dictionary = {"state":state,"phase":state.phase,"targets":targets,"cursor":0,"segment":segment,"amount":amount,"at":at,"impact":impact,"completion":completion}
 _e2_drain_burst(work)

func _e2_drain_burst(work: Dictionary) -> void:
 var state: Dictionary = work.state
 while int(work.cursor) < work.targets.size():
  if not _e2_guard_arena(state) or state.phase != work.phase: return
  if paused:
   _e2_pending_burst = work
   return
  var enemy: Dictionary = work.targets[int(work.cursor)]
  work.cursor = int(work.cursor)+1
  _e2_contact(state,enemy,work.segment,state.position,float(work.at),work.impact,float(work.amount))
 if not _e2_live(state): return
 if paused:
  _e2_pending_burst = work
  return
 _e2_complete(state,work.completion,float(work.at))

func _e2_contact(state: Dictionary, enemy: Dictionary, segment: String, at_position: Vector3, at: float, impact: Dictionary, explicit_amount: float = -1.0) -> void:
 if paused or not _e2_guard_arena(state) or not _e2_target_current(enemy,state): return
 var id: String = str(enemy.actor_id)
 var returned: bool = segment=="return_voyage"
 var ledger: Dictionary = state.return_hits if returned else state.outward_hits
 var amount: float = explicit_amount if explicit_amount>=0 else float(state.return_damage if returned else state.outward_damage)
 if segment in ["outward_voyage","return_voyage"] and ledger.has(id): return
 if not claim_hit(int(state.cast_id),id,"ink_e2_"+segment): return
 if segment in ["outward_voyage","return_voyage"]: ledger[id] = enemy
 state.hit_targets[id] = true
 var event_id: String = str(state.boat_id)+":"+segment+":"+id
 var metadata: Dictionary = {"effect_id":event_id,"generation":state.generation,"room_id":state.room_id,"position":at_position,"cast_origin":state.launch_position,"direction":-Vector3(state.direction) if returned else state.direction,"saved_aim":state.direction,"active_skill":true,"area":true,"direct":true,"basic_attack":false,"hex_generated":returned,"segment_id":segment,"parent_skill":"e2"}
 metadata.merge(impact,false)
 # Scoped packet ownership survives nested same-root boarding, including all
 # inherited damage callbacks, after_hit and drain. No callback is prohibited.
 var packet: Dictionary = {"state":state,"enemy":enemy,"actual_seen":false,"actual":0.0,"event_id":event_id}
 _e2_packets[event_id] = packet
 state.inflight_packets = int(state.inflight_packets)+1
 _equipment_skill_damage("e2",state,enemy,amount,"yanguizhou_h09" if returned else "e2",int(state.cast_id),false,false,metadata)
 if _e2_live(state) and bool(packet.actual_seen):
  var receipt: Dictionary = {"source_event_id":event_id,"effect_id":event_id,"boat_id":state.boat_id,"cast_id":state.cast_id,"generation":state.generation,"room_id":state.room_id,"segment_id":segment,"target_id":id,"position":at_position,"source_time":at,"settled_at":hero_time,"nominal_damage":amount,"actual_damage":float(packet.actual),"hex_generated":returned}
  ink_e2_receipts.append(receipt)
  emit_event("ink_e2_contact",receipt)
 if _e2_packets.has(event_id) and is_same(_e2_packets[event_id],packet): _e2_packets.erase(event_id)
 state.inflight_packets = maxi(0,int(state.inflight_packets)-1)
 if _e2_live(state) and int(state.inflight_packets)==0 and not state.completion_pending.is_empty():
  var pending_end: Dictionary = state.completion_pending
  state.completion_pending={}
  _e2_complete(state,str(pending_end.reason),float(pending_end.at))

func _hero_after_damage(enemy: Dictionary, event: Dictionary, actual: float) -> void:
 super._hero_after_damage(enemy,event,actual)
 var event_id: String = str(event.get("effect_id",""))
 if not _e2_packets.has(event_id): return
 var packet: Dictionary = _e2_packets[event_id]
 if not _e2_live(packet.state) or not is_same(packet.enemy,enemy) or bool(packet.actual_seen): return
 # The guarded pipeline computed this packet's actual before any nested damage.
 # Do not reconstruct attribution from final HP after reentrant callbacks.
 packet.actual=actual; packet.actual_seen=true

func _e2_natural_end(state: Dictionary, at: float) -> void:
 if not _e2_guard_arena(state) or bool(state.boarded) or bool(state.natural_burst_done): return
 state.natural_burst_done = true; state.phase = "natural_settlement"
 _e2_event(state,"natural_burst",at)
 if not _e2_guard_arena(state): return
 _e2_burst(state,"unboarded_end_burst",float(state.natural_radius),float(state.natural_damage),at,"unboarded")

func _e2_complete(state: Dictionary, reason: String, at: float) -> void:
 if not _e2_guard_arena(state): return
 if paused:
  _e2_pending_terminal = {"state":state,"reason":reason,"at":at}
  return
 if int(state.inflight_packets)>0:
  state.completion_pending={"reason":reason,"at":at}
  state.phase="completion_pending"
  return
 state.damage_stages_complete = true
 # Keep whole-phase metadata available before common.complete_action; P1 itself
 # is deliberately unimplemented and never receives supplemental damage here.
 _casts[int(state.cast_id)]["damage_stages_complete"] = true
 _casts[int(state.cast_id)]["ink_e2_hit_target_ids"] = state.hit_targets.keys()
 _casts[int(state.cast_id)]["damage_completed_at"] = at
 state.retired = true; ink_boat = {}
 var receipt: Dictionary = _e2_public(state).merged({"reason":reason,"finished_at":at,"settled_at":hero_time,"damage_stages_complete":true,"hit_target_ids":state.hit_targets.keys()},true)
 finish_cast(int(state.cast_id))
 if not effect_is_current(state) or hero.dead or not is_same(hero,state.owner): return
 ink_e2_finished.append(receipt)
 emit_event("ink_e2_finished",receipt)

func _e2_enemy_motion(state: Dictionary, enemy: Dictionary, before: Vector3) -> void:
 if not _e2_live(state) or state.phase != "outward" or not _e2_target_current(enemy,state): return
 if before.distance_squared_to(enemy.position)<=Geometry.EPS*Geometry.EPS: return
 var point: Vector3 = state.position
 # The inherited world/AI step is already admitted. Observe its committed legs
 # against the admitted end-front without moving the displayed source cursor.
 if not _e2_pending_sweep.is_empty() and is_same(_e2_pending_sweep.state,state): point = _e2_pending_sweep.destination
 var fraction: float = Geometry.moving_front_contact(point,point,state.direction,float(state.width),before,enemy.position,float(enemy.radius))
 if not is_finite(fraction): return
 if paused or not _e2_pending_sweep.is_empty():
  _e2_pending_motion.append({"state":state,"enemy":enemy,"position":point,"at":hero_time})
 else: _e2_contact(state,enemy,"outward_voyage",point,hero_time,{})

func _step_pull(enemy: Dictionary, dt: float) -> void:
 var prior: Dictionary = _boat_pull_capture
 var capture: Dictionary = {"state":ink_boat,"enemy":enemy,"origin":Vector3(enemy.position),"core_flushed":false}
 _boat_pull_capture = capture
 super._step_pull(enemy,dt)
 if not bool(capture.core_flushed):
  capture.core_flushed=true; _e2_enemy_motion(capture.state,enemy,capture.origin)
 if is_same(_boat_pull_capture,capture): _boat_pull_capture=prior
func _h02_move_target(vortex: Dictionary, enemy: Dictionary, from_time: float, to_time: float, hold_for_ai: bool) -> void:
 var state: Dictionary = ink_boat
 if not _boat_pull_capture.is_empty() and is_same(_boat_pull_capture.enemy,enemy) and not bool(_boat_pull_capture.core_flushed):
  _boat_pull_capture.core_flushed=true; _e2_enemy_motion(_boat_pull_capture.state,enemy,_boat_pull_capture.origin)
 var before: Vector3 = enemy.position
 super._h02_move_target(vortex,enemy,from_time,to_time,hold_for_ai)
 _e2_enemy_motion(state,enemy,before)
func _step_push(enemy: Dictionary, dt: float) -> void:
 var state: Dictionary = ink_boat; var before: Vector3 = enemy.position
 super._step_push(enemy,dt); _e2_enemy_motion(state,enemy,before)
func _step_enemy(enemy: Dictionary, dt: float) -> void:
 var state: Dictionary = ink_boat; var before: Vector3 = enemy.position
 super._step_enemy(enemy,dt); _e2_enemy_motion(state,enemy,before)

func _hero_hex_status(id: String) -> Dictionary:
 if id in ["yanguizhou_h09","yanguizhou_h10"]: return {"active":false,"reason":"E2_personal_Hexes_not_in_this_candidate"}
 return super._hero_hex_status(id)

func common_damage_metadata(source: String) -> Dictionary:
 if source in ["e2","yanguizhou_h09"]: return {"active_skill":true,"basic_attack":false,"direct":true,"area":true,"hex_generated":source=="yanguizhou_h09"}
 return super.common_damage_metadata(source)
func _e2_abort_local() -> void:
 if not ink_boat.is_empty(): ink_boat.retired=true
 ink_boat={}; _boat_pull_capture={}; _e2_packets={}
 _e2_pending_sweep={}; _e2_pending_burst={}; _e2_pending_motion.clear(); _e2_pending_terminal={}
 for enemy in enemies:
  if str(enemy.get("taunt_source","")).ends_with(":decoy"):
   enemy.taunted=false; enemy.taunt_source=""; enemy.target_actor_id=hero.actor_id
   enemy.erase("ink_e2_decoy_position")
func cancel_cast(id: int) -> void:
 if not ink_boat.is_empty() and int(ink_boat.cast_id)==id: _e2_abort_local()
 super.cancel_cast(id)
func _hero_clear_transients() -> void:
 _e2_abort_local(); ink_e2_receipts.clear(); ink_e2_finished.clear(); ink_e2_lifecycle.clear(); _e2_resume_trace.clear()
 super._hero_clear_transients()
func _hero_victory_pending() -> bool: return super._hero_victory_pending() or not ink_boat.is_empty()
func _e2_public(state: Dictionary) -> Dictionary:
 var out: Dictionary = {}
 for key in ["boat_id","cast_id","generation","room_id","rank","born_at","position","launch_position","direction","phase","phase_started_at","last_advanced_at","voyage_until","speed","width","boarding_radius","natural_radius","h09","h10","boarded","natural_burst_done","damage_stages_complete","retired"]: out[key]=state[key]
 for key in ["return_until","decoy_until","decoy_actor_id","boarding_position"]:
  if state.has(key): out[key]=state[key]
 out["outward_hit_target_ids"]=state.outward_hits.keys(); out["return_hit_target_ids"]=state.return_hits.keys()
 out["traveled_route"]=state.traveled_route.duplicate()
 return out
func _e2_event(state: Dictionary, kind: String, at: float) -> void:
 var event: Dictionary = _e2_public(state).merged({"event":kind,"source_time":at,"settled_at":hero_time},true)
 ink_e2_lifecycle.append(event); emit_event("ink_e2_"+kind,event)
func ink_presenter_snapshot() -> Dictionary:
 var out: Dictionary = super.ink_presenter_snapshot()
 out["e2_schema"]="ink-e2-ordinary-source-candidate-1"; out["boat"]={} if ink_boat.is_empty() else _e2_public(ink_boat)
 out["e2_pending_local"]={"sweep":not _e2_pending_sweep.is_empty(),"burst":not _e2_pending_burst.is_empty(),"motion":_e2_pending_motion.size(),"terminal":not _e2_pending_terminal.is_empty()}
 out["e2_receipts"]=ink_e2_receipts.duplicate(true); out["e2_finished"]=ink_e2_finished.duplicate(true); out["e2_lifecycle"]=ink_e2_lifecycle.duplicate(true)
 return out
