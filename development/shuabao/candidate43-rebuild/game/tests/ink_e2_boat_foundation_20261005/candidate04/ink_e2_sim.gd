extends "res://tests/ink_e1_rain_foundation_20261005/fix01/ink_e1_sim.gd"
## Isolated E2/H09/H10 above exact E1 fix01. No ordinary-host admission.
const BoatDirector = preload("res://tests/ink_e2_boat_foundation_20261005/candidate04/boat_director.gd")
const BoatCommon = preload("res://tests/ink_e2_boat_foundation_20261005/candidate04/boat_common_bridge.gd")
var ink_boat: Dictionary = {}
var ink_e2_receipts: Array = []
var ink_e2_finished: Array = []
var ink_e2_lifecycle: Array = []
var _boat_serial: int = 0
var _boat_pull_capture: Dictionary = {}
var _e2_accepted_direction: Vector3 = Vector3.ZERO
var _e2_packets: Dictionary = {}

func _init() -> void:
 super._init()
 enemy_director = BoatDirector.new()
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
 # User Sentinel_58891f6c400481918ae8be5a3771f473: E2 boat may cross walls.
 # Wall presence never clips the boat, rejects launch, or consumes its root.
 # Retain only the existing independent arena-contained fixture boundary.
 return _e2_point_in_arena(origin) and _e2_point_in_arena(endpoint)

func _hero_action_policy(action: String, aim: Vector3 = Vector3.INF) -> Dictionary:
 if action != "e" or hero.loadout.e != "e2": return super._hero_action_policy(action, aim)
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
 state.merge({"owner":hero,"context":context.duplicate(true),"boat_id":"%d:%s:boat:%d" % [encounter_generation,room_id,_boat_serial],"rank":rank,"born_at":hero_time,"position":Vector3(context.origin),"launch_position":Vector3(context.origin),"phase":"outward","phase_started_at":hero_time,"voyage_until":hero_time + v("E2-2",rank),"last_advanced_at":hero_time,"speed":v("E2-1",rank),"width":v("E2-3",rank),"outward_damage":v("E2-4",rank)+ap*T.fraction("E2-5",rank),"outward_cap":int(v("E2-6",rank)),"boarding_radius":v("E2-7",rank),"boarding_damage":v("E2-8",rank)+ap*T.fraction("E2-9",rank),"natural_radius":v("E2-10",rank),"natural_damage":v("E2-11",rank)+ap*T.fraction("E2-12",rank),"h09":hx("yanguizhou_h09"),"h10":hx("yanguizhou_h10"),"return_speed":T.hex_parameter("H09-1"),"return_width":T.hex_parameter("H09-2"),"return_damage":T.hex_parameter("H09-3")+ap*T.hex_parameter("H09-4")*.01,"return_cap":int(T.hex_parameter("H09-5")),"decoy_duration":T.hex_parameter("H10-1"),"taunt_radius":T.hex_parameter("H10-2"),"outward_hits":{},"return_hits":{},"hit_targets":{},"traveled_route":[Vector3(context.origin)],"retired":false,"boarded":false,"natural_burst_done":false,"damage_stages_complete":false,"inflight_packets":0,"completion_pending":{},"launch_arena_half_extent":arena_half_extent},true)
 ink_boat = state
 # Accepted real damaging effect launch, unlike uncommitted Q2/E3 placement.
 start_skill_cooldown("e", v("E2-13",rank))
 _e2_event(state,"launched",hero_time)
 return {"accepted":true,"phase":"outward","boat_id":state.boat_id}

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
  _e2_sweep_boat(state,destination,start,finish,"outward_voyage")
  if not _e2_live(state) or state.phase != "outward": return
  state.last_advanced_at = finish
  if finish >= float(state.voyage_until)-TIME_EPS:
   if bool(state.h10):
    state.phase = "decoy"; state.phase_started_at = float(state.voyage_until)
    state.decoy_until = float(state.voyage_until)+float(state.decoy_duration)
    state.decoy_actor_id = str(state.boat_id)+":decoy"
    _e2_event(state,"decoy_started",float(state.voyage_until))
   else:
    _e2_natural_end(state,float(state.voyage_until)); return
 if not _e2_guard_arena(state): return
 if state.phase == "return":
  var finish: float = minf(until,float(state.return_until))
  var traveled: float = float(state.return_speed)*(finish-float(state.phase_started_at))
  var frame: Dictionary = Geometry.frame_at(state.return_route,traveled)
  _e2_sweep_boat(state,frame.position,float(state.last_advanced_at),finish,"return_voyage")
  if not _e2_live(state): return
  state.last_advanced_at = finish
  if finish >= float(state.return_until)-TIME_EPS: _e2_complete(state,"returned",float(state.return_until)); return
 if _e2_live(state) and state.phase == "decoy":
  state.last_advanced_at = minf(until,float(state.decoy_until))
  if until >= float(state.decoy_until)-TIME_EPS: _e2_natural_end(state,float(state.decoy_until))

func _e2_sweep_boat(state: Dictionary, destination: Vector3, from_time: float, to_time: float, segment: String) -> void:
 if not _e2_guard_arena(state): return
 var expected_phase: String = str(state.phase)
 var origin: Vector3 = state.position
 var width: float = float(state.width) if segment == "outward_voyage" else float(state.return_width)
 var direction: Vector3 = state.direction if segment == "outward_voyage" else -Vector3(state.direction)
 var ledger: Dictionary = state.outward_hits if segment == "outward_voyage" else state.return_hits
 var contacts: Array = []
 for enemy in enemies:
  if not _e2_target_current(enemy,state) or ledger.has(str(enemy.actor_id)): continue
  var fraction: float = Geometry.moving_front_contact(origin,destination,direction,width,enemy.position,enemy.position,float(enemy.radius))
  if is_finite(fraction): contacts.append({"enemy":enemy,"fraction":fraction})
 contacts.sort_custom(func(a,b): return str(a.enemy.actor_id)<str(b.enemy.actor_id) if a.fraction==b.fraction else float(a.fraction)<float(b.fraction))
 for contact in contacts:
  if not _e2_guard_arena(state) or state.phase != expected_phase: return
  state.position = origin.lerp(destination,float(contact.fraction))
  if segment == "outward_voyage" and Vector3(state.traveled_route.back()).distance_squared_to(state.position)>Geometry.EPS*Geometry.EPS: state.traveled_route.append(Vector3(state.position))
  _e2_contact(state,contact.enemy,segment,state.position,lerpf(from_time,to_time,float(contact.fraction)),{})
 if not _e2_guard_arena(state) or state.phase != expected_phase: return
 state.position = destination
 if segment == "outward_voyage" and Vector3(state.traveled_route.back()).distance_squared_to(destination)>Geometry.EPS*Geometry.EPS:
  state.traveled_route.append(destination)

func _e2_board(state: Dictionary, context: Dictionary) -> Dictionary:
 if not _e2_live(state) or int(context.cast_id)!=int(state.cast_id) or state.phase!="outward" or hero_time>=float(state.voyage_until)-TIME_EPS: return {"accepted":false,"reason":"boat_boarding_window_closed"}
 if not _e2_landing_legal(state.position): return {"accepted":false,"reason":"illegal_current_boat_landing"}
 if not _e2_arena_ready(state): return {"accepted":false,"reason":"arena_reconfiguration_outside_fixture"}
 # Choose the exclusive branch BEFORE callbacks. Boarding never reopens.
 state.boarded = true; state.boarding_position = Vector3(state.position)
 state.phase = "return" if bool(state.h09) else "boarding_settlement"
 state.phase_started_at = hero_time; state.last_advanced_at = hero_time
 if bool(state.h09):
  state.return_route = state.traveled_route.duplicate(); state.return_route.reverse()
  if state.return_route.size()==1: state.return_route.append(state.launch_position)
  state.return_until = hero_time+Geometry.path_length(state.return_route)/float(state.return_speed)
 hero.position = state.boarding_position
 _e2_event(state,"boarded",hero_time)
 if not _e2_live(state): return {"accepted":true,"cancelled_during_callback":true}
 _e2_burst(state,"teleport_burst",float(state.boarding_radius),float(state.boarding_damage),hero_time)
 if not _e2_live(state): return {"accepted":true,"cancelled_during_callback":true}
 if not bool(state.h09): _e2_complete(state,"boarded",hero_time)
 elif float(state.return_until)<=hero_time+TIME_EPS:
  _e2_sweep_boat(state,state.launch_position,hero_time,hero_time,"return_voyage")
  if _e2_live(state): _e2_complete(state,"returned",hero_time)
 else: _e2_event(state,"return_started",hero_time)
 return {"accepted":true,"phase":"return" if bool(state.h09) else "boarded","boat_id":state.boat_id}

func _e2_burst(state: Dictionary, segment: String, radius: float, amount: float, at: float) -> void:
 if not _e2_guard_arena(state): return
 var targets: Array = circle_targets(state.position,radius)
 common.refresh_stats()
 var impact: Dictionary = {"impact_penetration":float(hero.stats.penetration),"impact_lifesteal_rate":hero.lifesteal(),"ink_e2_impact_stats":common.context().hero.stats.duplicate(true)}
 for enemy in targets:
  if not _e2_guard_arena(state): return
  _e2_contact(state,enemy,segment,state.position,at,impact,amount)

func _e2_contact(state: Dictionary, enemy: Dictionary, segment: String, at_position: Vector3, at: float, impact: Dictionary, explicit_amount: float = -1.0) -> void:
 if not _e2_guard_arena(state) or not _e2_target_current(enemy,state): return
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
 damage_enemy(enemy,amount,"yanguizhou_h09" if returned else "e2",int(state.cast_id),false,false,metadata)
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
 enemy_director._update_taunts(self)
 if not _e2_guard_arena(state): return
 _e2_event(state,"natural_burst",at)
 if not _e2_guard_arena(state): return
 _e2_burst(state,"unboarded_end_burst",float(state.natural_radius),float(state.natural_damage),at)
 if _e2_live(state): _e2_complete(state,"unboarded",at)

func _e2_complete(state: Dictionary, reason: String, at: float) -> void:
 if not _e2_guard_arena(state): return
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
 if not _e2_live(state) or state.phase not in ["outward","return"] or not _e2_target_current(enemy,state): return
 if before.distance_squared_to(enemy.position)<=Geometry.EPS*Geometry.EPS: return
 var returned: bool = state.phase=="return"
 var direction: Vector3 = -Vector3(state.direction) if returned else state.direction
 var fraction: float = Geometry.moving_front_contact(state.position,state.position,direction,float(state.return_width if returned else state.width),before,enemy.position,float(enemy.radius))
 if is_finite(fraction): _e2_contact(state,enemy,"return_voyage" if returned else "outward_voyage",state.position,hero_time,{})
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

func e2_decoy_target(enemy: Dictionary) -> Dictionary:
 var state: Dictionary = ink_boat
 if not _e2_live(state) or state.phase!="decoy" or hero_time>=float(state.decoy_until)-TIME_EPS: return {}
 # Explicit capability, never an invented ordinary-only/Boss class rule.
 if not _e2_target_current(enemy,state) or not bool(enemy.get("tauntable",true)) or bool(enemy.get("taunt_immune",false)): return {}
 if Geometry.ground(Vector3(enemy.position)-Vector3(state.position)).length()>float(state.taunt_radius)+Geometry.EPS: return {}
 return {"actor_id":state.decoy_actor_id,"position":state.position,"cast_id":state.cast_id,"boat_id":state.boat_id,"generation":state.generation,"room_id":state.room_id,"expires_at":state.decoy_until,"radius":state.taunt_radius}

func _hero_hex_status(id: String) -> Dictionary:
 if id in ["yanguizhou_h09","yanguizhou_h10"]:
  var active: bool = hero.loadout.e=="e2" and int(hero.ranks.e)>0
  return {"active":active,"reason":"" if active else "requires_E2"}
 return super._hero_hex_status(id)
func common_damage_metadata(source: String) -> Dictionary:
 if source in ["e2","yanguizhou_h09"]: return {"active_skill":true,"basic_attack":false,"direct":true,"area":true,"hex_generated":source=="yanguizhou_h09"}
 return super.common_damage_metadata(source)
func _e2_abort_local() -> void:
 if not ink_boat.is_empty(): ink_boat.retired=true
 ink_boat={}; _boat_pull_capture={}; _e2_packets={}
 for enemy in enemies:
  if str(enemy.get("taunt_source","")).ends_with(":decoy"):
   enemy.taunted=false; enemy.taunt_source=""; enemy.target_actor_id=hero.actor_id
   enemy.erase("ink_e2_decoy_position")
func cancel_cast(id: int) -> void:
 if not ink_boat.is_empty() and int(ink_boat.cast_id)==id: _e2_abort_local()
 super.cancel_cast(id)
func _hero_clear_transients() -> void:
 _e2_abort_local(); ink_e2_receipts.clear(); ink_e2_finished.clear(); ink_e2_lifecycle.clear()
 super._hero_clear_transients()
func _hero_victory_pending() -> bool: return super._hero_victory_pending() or not ink_boat.is_empty()
func _e2_public(state: Dictionary) -> Dictionary:
 var out: Dictionary = {}
 for key in ["boat_id","cast_id","generation","room_id","rank","born_at","position","launch_position","direction","phase","phase_started_at","voyage_until","speed","width","boarding_radius","natural_radius","h09","h10","boarded","natural_burst_done","damage_stages_complete","retired"]: out[key]=state[key]
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
 out["e2_schema"]="ink-e2-source-foundation-1"; out["boat"]={} if ink_boat.is_empty() else _e2_public(ink_boat)
 out["e2_receipts"]=ink_e2_receipts.duplicate(true); out["e2_finished"]=ink_e2_finished.duplicate(true); out["e2_lifecycle"]=ink_e2_lifecycle.duplicate(true)
 return out
