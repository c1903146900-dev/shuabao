extends "res://tests/ink_e2_boat_foundation_20261005/candidate04/ink_e2_sim.gd"
## Independent E3/H11/H12 above the exact E2 candidate04 -> E1 -> Q1/Q3 chain.
## No Q2 composition, ordinary-host admission or obstacle-exchange rule.
const ExchangeCommon = preload("res://tests/ink_e3_exchange_foundation_20261005/candidate03/exchange_common_bridge.gd")
const E3_DECISIONS = "res://docs/source_decisions/20261005-ink-six-resolutions.json"
const E3_DECISIONS_HASH = "62cbd6c20607748cb4c426abd42d4656d6de1ab922fda179102bd8b8afdf6634"
var e3_decisions_hash: String = ""
var ink_frames: Dictionary = {}
var ink_e3_receipts: Array = []
var ink_e3_finished: Array = []
var ink_e3_lifecycle: Array = []
var _e3_serial: int = 0
var _e3_expected_frame: String = ""
var _e3_accepted_point: Vector3 = Vector3.INF
var _e3_admission_owner: RefCounted
var _e3_packets: Dictionary = {}

func _init() -> void:
 super._init()
 e3_decisions_hash = FileAccess.get_sha256(E3_DECISIONS)
 var values: Dictionary = common.context_values.duplicate(true)
 common = ExchangeCommon.new(self)
 common.context_values = values

func _e3_context_current(state: Dictionary) -> bool:
 return source_rules_hash == EXPECTED_RULES_HASH and e3_decisions_hash == E3_DECISIONS_HASH and not state.is_empty() and effect_is_current(state) and not hero.dead and is_same(hero,state.owner)
func _e3_live(state: Dictionary) -> bool:
 return _e3_context_current(state) and is_same(ink_frames,state) and not bool(state.retired)
func _e3_enemy_current(enemy: Dictionary, state: Dictionary) -> bool:
 return _e3_context_current(state) and not enemy.is_empty() and not enemy.dead and enemy.state != "spawn" and is_same(enemy,enemy_by_id(str(enemy.actor_id))) and int(enemy.generation)==encounter_generation and str(enemy.room_id)==room_id
func _e3_entry_current(entry: Dictionary, state: Dictionary) -> bool:
 if not _e3_context_current(state): return false
 if entry.team == "enemy":
  var enemy: Dictionary = entry.actor
  return not enemy.is_empty() and not enemy.dead and is_same(enemy,enemy_by_id(str(enemy.actor_id))) and int(enemy.generation)==encounter_generation and str(enemy.room_id)==room_id
 if not is_instance_valid(entry.actor) or entry.actor.dead: return false
 if entry.team == "self": return is_same(entry.actor,hero)
 for ally in allies:
  if is_same(ally,entry.actor): return true
 return false

func request_e3(kind: String, point: Vector3 = Vector3.INF, command_id: String = "", expected_frame_id: String = "", expected_generation: int = -1) -> Dictionary:
 if expected_generation>=0 and expected_generation!=encounter_generation: return {"accepted":false,"reason":"stale_input_generation"}
 if transaction_active: return {"accepted":false,"reason":"transaction_in_progress"}
 _e3_expected_frame=expected_frame_id
 var result: Dictionary = request_action("e3_"+kind,point,command_id)
 _e3_expected_frame=""
 return result

func _request_action(action: String, aim: Vector3) -> Dictionary:
 if hero.loadout.e=="e3":
  if action in ["ink_e_up","e_release"]: return {"accepted":false,"reason":"frame_key_up_has_no_effect","consumed":true}
  if action=="ink_e_down": action="e"
  if action=="e3_preview": return e3_preview(aim)
  if action in ["e3_first","e3_second","e3_return"]:
   var expected: String = "none" if action=="e3_first" else "first" if action=="e3_second" else "return_window"
   var actual: String = "none" if ink_frames.is_empty() else str(ink_frames.phase)
   if expected!=actual: return {"accepted":false,"reason":"wrong_frame_phase"}
   action="e"
  if action=="e" and phase=="combat" and not paused and not hero.dead: _e3_clock()
 # Escape/focus loss only release input latches. A retains its original window;
 # no extra cancellation, early CD, extension or free retry is fabricated.
 return super._request_action(action,aim)

func _e3_reason() -> String:
 if phase!="combat" or paused: return "encounter_frozen"
 if hero.dead: return "not_alive"
 if source_rules_hash!=EXPECTED_RULES_HASH: return "source_binding_mismatch"
 if e3_decisions_hash!=E3_DECISIONS_HASH: return "decision_binding_mismatch"
 if hero.loadout.e!="e3" or int(hero.ranks.e)<=0: return "unlearned"
 if _ink_action_controlled("e"): return "controlled"
 if _e1_form_current() or not ink_boat.is_empty(): return "other_E_active"
 if not ink_frames.is_empty():
  if not _e3_live(ink_frames): return "stale_frame"
  if not _e3_expected_frame.is_empty() and _e3_expected_frame!=str(ink_frames.frame_id): return "stale_frame_identity"
  if ink_frames.phase=="first" and hero_time>=float(ink_frames.expires_at)-TIME_EPS: return "frame_expired"
  if ink_frames.phase=="return_window" and hero_time>=float(ink_frames.return_until)-TIME_EPS: return "return_window_closed"
  if ink_frames.phase not in ["first","return_window"]: return "exchange_settlement_pending"
 elif not _e3_expected_frame.is_empty(): return "stale_frame_identity"
 return ""

func _e3_centers_in_range(a: Vector3, b: Vector3, source_maximum: float) -> bool:
 # Vector3 distance is float32. Normalize ONLY its source B-distance limit to
 # the same nearest representation, with no added EPS or point projection.
 # The immediately next greater observable float32 distance remains illegal.
 return a.distance_to(b)<=float(Vector3(source_maximum,0,0).x)

func e3_preview(point: Vector3) -> Dictionary:
 var reason: String = _e3_reason()
 if not reason.is_empty(): return {"accepted":false,"reason":reason,"preview_only":true}
 if not ink_frames.is_empty() and ink_frames.phase=="return_window":
  var returned: Array = _e3_return_plan(ink_frames)
  var guard: String = _e3_preflight(returned)
  return {"accepted":guard.is_empty(),"reason":guard,"phase":"return_window","preview_only":true,"participant_count":returned.size(),"source_gameplay_outcome":guard.is_empty()}
 if not point.is_finite(): return {"accepted":false,"reason":"manual_aim_required","preview_only":true}
 var at: Vector3 = Geometry.ground(point)
 if ink_frames.is_empty():
  if at.distance_to(Geometry.ground(hero.position))>v("E3-1",int(hero.ranks.e))+Geometry.EPS: return {"accepted":false,"reason":"first_frame_out_of_range","preview_only":true}
  return {"accepted":true,"point":at,"phase":"first","preview_only":true}
 if not _e3_centers_in_range(at,ink_frames.a,float(ink_frames.max_distance)): return {"accepted":false,"reason":"frame_centers_too_far","preview_only":true}
 var plan: Array = _e3_exchange_plan(ink_frames,at)
 var guard: String = _e3_preflight(plan)
 return {"accepted":guard.is_empty(),"reason":guard,"point":at,"phase":"exchange","preview_only":true,"participant_count":plan.size(),"source_gameplay_outcome":guard.is_empty()}

func _hero_action_policy(action: String, aim: Vector3 = Vector3.INF) -> Dictionary:
 if action!="e" or hero.loadout.e!="e3": return super._hero_action_policy(action,aim)
 # This precedes any rank-indexed source lookup, including previews.
 var preview: Dictionary = e3_preview(aim)
 if not preview.accepted: return {"reason":preview.reason}
 _e3_accepted_point=preview.get("point",Vector3.INF)
 _e3_admission_owner=hero
 if not ink_frames.is_empty(): return {"cast_id":ink_frames.cast_id,"context":ink_frames.context,"stage":preview.phase,"bypass_cooldown":true}
 return {"stage":"frame_first_marker"}

func _hero_cast_skill(action: String, context: Dictionary) -> Dictionary:
 if action!="e" or hero.loadout.e!="e3": return super._hero_cast_skill(action,context)
 if not effect_is_current(context) or not is_same(hero,_e3_admission_owner): return {"accepted":false,"reason":"stale_cast"}
 if not ink_frames.is_empty():
  if not _e3_live(ink_frames) or int(context.cast_id)!=int(ink_frames.cast_id): return {"accepted":false,"reason":"stale_frame_identity"}
  return _e3_return(ink_frames) if ink_frames.phase=="return_window" else _e3_exchange(ink_frames,_e3_accepted_point)
 var rank: int = int(hero.ranks.e)
 _e3_serial+=1
 var state: Dictionary = context.duplicate(true)
 state.merge({"owner":hero,"context":context.duplicate(true),"frame_id":"%d:%s:frames:%d" % [encounter_generation,room_id,_e3_serial],"rank":rank,"phase":"first","a":_e3_accepted_point,"radius":v("E3-3",rank),"max_distance":v("E3-4",rank),"near_threshold":v("E3-5",rank),"near_damage":v("E3-6",rank)+float(hero.stats.ap)*T.fraction("E3-7",rank),"far_damage":v("E3-8",rank)+float(hero.stats.ap)*T.fraction("E3-9",rank),"cooldown":v("E3-10",rank),"born_at":hero_time,"expires_at":hero_time+v("E3-2",rank),"h11":hx("yanguizhou_h11"),"h12":hx("yanguizhou_h12"),"return_duration":T.hex_parameter("H12-1"),"members":[],"pending_damage":[],"damage_cursor":0,"hit_targets":{},"damage_stages_complete":false,"release_completed":false,"retired":false,"return_consumed":false},true)
 ink_frames=state
 _e3_event(state,"first_placed",hero_time)
 return {"accepted":true,"phase":"first","frame_id":state.frame_id,"release_completed":false}

func _e3_member(state: Dictionary, b: Vector3, actor, team: String, body_radius: float) -> Dictionary:
 var original: Vector3 = actor.position
 var da: float = Geometry.ground(original-Vector3(state.a)).length()
 var db: float = Geometry.ground(original-b).length()
 var in_a: bool = da<=float(state.radius)+body_radius+Geometry.EPS
 var in_b: bool = db<=float(state.radius)+body_radius+Geometry.EPS
 if not in_a and not in_b: return {}
 # Whole-body contact matches inherited circle targeting. For overlap, select
 # nearest center, exact ties A. Snapshot each real object exactly once.
 var region: String = "a" if in_a and (not in_b or da<=db) else "b"
 var origin_center: Vector3 = state.a if region=="a" else b
 var destination_center: Vector3 = b if region=="a" else state.a
 var destination: Vector3 = original+destination_center-origin_center
 return {"actor":actor,"actor_id":str(actor.actor_id),"team":team,"region":region,"offset":original-origin_center,"original":original,"from":original,"to":destination,"radius":body_radius,"distance":original.distance_to(destination)}

func _e3_exchange_plan(state: Dictionary, b: Vector3) -> Array:
 var plan: Array = []
 for enemy in enemies:
  if not _e3_enemy_current(enemy,state): continue
  if enemy.kind=="boss" or str(enemy.get("rank_category","ordinary")) not in ["ordinary","elite"]: continue
  var entry: Dictionary = _e3_member(state,b,enemy,"enemy",float(enemy.radius))
  if not entry.is_empty(): plan.append(entry)
 if bool(state.h11):
  var self_entry: Dictionary = _e3_member(state,b,hero,"self",hero_radius)
  if not self_entry.is_empty(): plan.append(self_entry)
  for ally in allies:
   if not is_instance_valid(ally) or ally.dead or is_same(ally,hero): continue
   var entry: Dictionary = _e3_member(state,b,ally,"ally",hero_radius)
   if not entry.is_empty(): plan.append(entry)
 plan.sort_custom(func(a,b_entry): return str(a.team)+":"+str(a.actor_id)<str(b_entry.team)+":"+str(b_entry.actor_id))
 return plan

func _e3_point_legal(point: Vector3, radius: float) -> bool:
 if not point.is_finite(): return false
 var bound: float = maxf(0,arena_half_extent-radius)
 if absf(point.x)>bound+Geometry.EPS or absf(point.z)>bound+Geometry.EPS: return false
 for obstacle in obstacles:
  var half: Vector3 = Vector3(obstacle.half)+Vector3(radius,0,radius)
  var offset: Vector3 = point-Vector3(obstacle.position)
  if absf(offset.x)<half.x-Geometry.EPS and absf(offset.z)<half.z-Geometry.EPS: return false
 return true

func _e3_preflight(plan: Array) -> String:
 # This is an explicit independent-fixture boundary, NOT an approved gameplay
 # rule: no projection, partial assignment, invented wall pass or new damage.
 # Landing diagnostics are specific; any obstacle scene then remains outside
 # this clear-space candidate until E3's own obstacle policy is decided.
 for entry in plan:
  if not _e3_point_legal(entry.to,float(entry.radius)): return "e3_illegal_landing_outside_fixture"
  if not _e3_point_legal(entry.from,float(entry.radius)): return "e3_illegal_origin_outside_fixture"
 if not obstacles.is_empty(): return "e3_obstacles_outside_fixture"
 if not ink_mountain.is_empty() and effect_is_current(ink_mountain): return "e3_mountain_outside_fixture"
 return ""

func _e3_nominal_damage(state: Dictionary, actual_distance: float) -> float:
 var t: float = clampf((actual_distance-float(state.near_threshold))/(float(state.max_distance)-float(state.near_threshold)),0,1)
 return lerpf(float(state.near_damage),float(state.far_damage),t)

func _e3_exchange(state: Dictionary, b: Vector3) -> Dictionary:
 if not _e3_live(state) or state.phase!="first" or hero_time>=float(state.expires_at)-TIME_EPS: return {"accepted":false,"reason":"frame_expired"}
 if not b.is_finite() or not _e3_centers_in_range(b,state.a,float(state.max_distance)): return {"accepted":false,"reason":"frame_centers_too_far"}
 var plan: Array = _e3_exchange_plan(state,b)
 var guard: String = _e3_preflight(plan)
 if not guard.is_empty(): return {"accepted":false,"reason":guard,"source_gameplay_outcome":false}
 # Atomic position assignment has no callbacks. All participants and offsets
 # are snapshotted before any write; deaths/replacements later cannot retarget.
 state.phase="settling"; state.b=b; state.exchange_at=hero_time
 state.return_until=hero_time+float(state.return_duration)
 state.release_completed=true; state.members=plan
 for entry in plan:
  entry.actor.position=entry.to
  if entry.team=="enemy" and float(entry.distance)>Geometry.EPS: state.pending_damage.append(entry)
 start_skill_cooldown("e",float(state.cooldown))
 _casts[int(state.cast_id)]["release_completed"]=true
 _casts[int(state.cast_id)]["release_completed_at"]=hero_time
 common.refresh_stats()
 state.impact={"impact_penetration":float(hero.stats.penetration),"impact_lifesteal_rate":hero.lifesteal(),"ink_e3_impact_stats":common.context().hero.stats.duplicate(true)}
 _build_spatial()
 _e3_event(state,"exchanged",hero_time)
 if _e3_live(state): _e3_dispatch_damage(state)
 return {"accepted":true,"phase":"exchanged","frame_id":state.frame_id,"release_completed":true}

func _e3_dispatch_damage(state: Dictionary) -> void:
 if not _e3_live(state) or state.phase!="settling" or bool(state.get("dispatching",false)): return
 state.dispatching=true
 while _e3_live(state) and not paused and int(state.damage_cursor)<state.pending_damage.size():
  var entry: Dictionary = state.pending_damage[int(state.damage_cursor)]
  state.damage_cursor=int(state.damage_cursor)+1
  if not _e3_entry_current(entry,state): continue
  var id: String = str(entry.actor_id)
  if not claim_hit(int(state.cast_id),id,"ink_e3_swap_damage"): continue
  var event_id: String = str(state.frame_id)+":swap_damage:"+id
  var amount: float = _e3_nominal_damage(state,float(entry.distance))
  var metadata: Dictionary = {"effect_id":event_id,"generation":state.generation,"room_id":state.room_id,"position":entry.to,"cast_origin":state.a,"direction":Geometry.ground(Vector3(entry.to)-Vector3(entry.from)).normalized(),"active_skill":true,"basic_attack":false,"direct":true,"area":true,"hex_generated":false,"segment_id":"swap_damage","parent_skill":"e3"}
  metadata.merge(state.impact,false)
  var packet: Dictionary = {"state":state,"enemy":entry.actor,"actual_seen":false,"actual":0.0}
  _e3_packets[event_id]=packet
  damage_enemy(entry.actor,amount,"e3",int(state.cast_id),false,false,metadata)
  if _e3_live(state) and bool(packet.actual_seen):
   state.hit_targets[id]=true
   var receipt: Dictionary = {"source_event_id":event_id,"effect_id":event_id,"frame_id":state.frame_id,"cast_id":state.cast_id,"generation":state.generation,"room_id":state.room_id,"segment_id":"swap_damage","target_id":id,"from":entry.from,"to":entry.to,"actual_distance":entry.distance,"nominal_damage":amount,"actual_damage":packet.actual,"source_time":state.exchange_at,"settled_at":hero_time}
   ink_e3_receipts.append(receipt)
   emit_event("ink_e3_contact",receipt)
  if _e3_packets.has(event_id) and is_same(_e3_packets[event_id],packet): _e3_packets.erase(event_id)
 state.dispatching=false
 if _e3_live(state) and not paused and int(state.damage_cursor)>=state.pending_damage.size(): _e3_finish_damage(state)

func _hero_after_damage(enemy: Dictionary, event: Dictionary, actual: float) -> void:
 super._hero_after_damage(enemy,event,actual)
 var id: String = str(event.get("effect_id",""))
 if not _e3_packets.has(id): return
 var packet: Dictionary = _e3_packets[id]
 if not _e3_live(packet.state) or not is_same(packet.enemy,enemy) or bool(packet.actual_seen): return
 packet.actual=actual; packet.actual_seen=true

func _e3_finish_damage(state: Dictionary) -> void:
 if not _e3_live(state) or bool(state.damage_stages_complete): return
 state.damage_stages_complete=true
 _casts[int(state.cast_id)]["damage_stages_complete"]=true
 _casts[int(state.cast_id)]["damage_completed_at"]=hero_time
 _casts[int(state.cast_id)]["ink_e3_hit_target_ids"]=state.hit_targets.keys()
 state.phase="return_window" if bool(state.h12) and hero_time<float(state.return_until)-TIME_EPS else "complete"
 if state.phase=="complete": state.retired=true; ink_frames={}
 var receipt: Dictionary = _e3_public(state).merged({"finished_at":hero_time,"source_time":state.exchange_at,"hit_target_ids":state.hit_targets.keys(),"damage_stages_complete":true,"release_completed":true},true)
 # H12 is movement only: complete the common root NOW, retain only return state.
 finish_cast(int(state.cast_id))
 if not _e3_context_current(state): return
 ink_e3_finished.append(receipt)
 emit_event("ink_e3_damage_finished",receipt)

func _e3_return_plan(state: Dictionary) -> Array:
 var plan: Array = []
 for original in state.members:
  if float(original.distance)<=Geometry.EPS or not _e3_entry_current(original,state): continue
  var entry: Dictionary = original.duplicate(false)
  entry.from=Vector3(original.actor.position); entry.to=Vector3(original.original)
  entry.distance=Vector3(entry.from).distance_to(entry.to)
  plan.append(entry)
 return plan

func _e3_return(state: Dictionary) -> Dictionary:
 if not _e3_live(state) or state.phase!="return_window" or bool(state.return_consumed) or not bool(state.damage_stages_complete) or hero_time>=float(state.return_until)-TIME_EPS: return {"accepted":false,"reason":"return_window_closed"}
 var plan: Array = _e3_return_plan(state)
 var guard: String = _e3_preflight(plan)
 if not guard.is_empty(): return {"accepted":false,"reason":guard,"source_gameplay_outcome":false}
 state.return_consumed=true; state.phase="returned"; state.retired=true; ink_frames={}
 for entry in plan: entry.actor.position=entry.to
 _build_spatial()
 var payload: Dictionary = _e3_public(state).merged({"source_time":hero_time,"returned_target_ids":plan.map(func(e): return e.actor_id),"new_damage_packets":0,"source_gameplay_outcome":true},true)
 ink_e3_lifecycle.append(payload.merged({"event":"returned"},true)); emit_event("ink_e3_returned",payload)
 return {"accepted":true,"phase":"returned","frame_id":state.frame_id,"returned_count":plan.size(),"new_damage_packets":0}

func _e3_clock() -> void:
 if ink_frames.is_empty(): return
 var state: Dictionary = ink_frames
 if not _e3_live(state): _e3_abort_local(); return
 if paused: return
 if state.phase=="settling": _e3_dispatch_damage(state)
 if not _e3_live(state): return
 if state.phase=="first" and hero_time>=float(state.expires_at)-TIME_EPS:
  # Explicit 03:13 decision: remove A first, then start CD at its source deadline.
  state.phase="expired"; state.retired=true; ink_frames={}
  start_skill_cooldown("e",float(state.cooldown))
  hero.cooldowns.e=maxf(0,float(hero.cooldowns.e)-maxf(0,hero_time-float(state.expires_at)))
  _casts[int(state.cast_id)]["release_completed"]=false
  _casts[int(state.cast_id)]["damage_stages_complete"]=true
  finish_cast(int(state.cast_id))
  if _e3_context_current(state): _e3_event(state,"placement_expired",float(state.expires_at))
 elif state.phase=="return_window" and hero_time>=float(state.return_until)-TIME_EPS:
  state.phase="return_expired"; state.retired=true; ink_frames={}
  _e3_event(state,"return_expired",float(state.return_until))

func _fixed_step(real_dt: float) -> void:
 # Resume an admitted paused packet batch before any new shared time advances.
 var scope: Dictionary = _ink_scope()
 _e3_clock()
 # A resumed packet may replace hero/room. Its old tick budget cannot advance
 # the newly entered encounter, even when the new room is already in combat.
 if not _ink_scope_current(scope) or paused or hero.dead: return
 super._fixed_step(real_dt) # Exactly one inherited clock/AI/common step.
 # E3 expiry callbacks run only after the complete inherited step unwinds.
 # Emitting inside core _hero_step would let a newly opened room receive the
 # old step's remaining enemy/common budget. Never modify the frozen core.
 if _ink_scope_current(scope) and not paused and not hero.dead:
  _e3_clock()
  if _ink_scope_current(scope): _check_victory()
func _hero_hex_status(id: String) -> Dictionary:
 if id in ["yanguizhou_h11","yanguizhou_h12"]:
  var active: bool = hero.loadout.e=="e3" and int(hero.ranks.e)>0
  return {"active":active,"reason":"" if active else "requires_E3"}
 return super._hero_hex_status(id)
func common_damage_metadata(source: String) -> Dictionary:
 if source=="e3": return {"active_skill":true,"basic_attack":false,"direct":true,"area":true,"hex_generated":false}
 return super.common_damage_metadata(source)
func _e3_abort_local() -> void:
 if not ink_frames.is_empty(): ink_frames.retired=true
 ink_frames={}; _e3_packets={}
func cancel_cast(id: int) -> void:
 if not ink_frames.is_empty() and int(ink_frames.cast_id)==id: _e3_abort_local()
 super.cancel_cast(id)
func _hero_clear_transients() -> void:
 _e3_abort_local(); ink_e3_receipts.clear(); ink_e3_finished.clear(); ink_e3_lifecycle.clear()
 super._hero_clear_transients()
func _hero_victory_pending() -> bool: return super._hero_victory_pending() or not ink_frames.is_empty()
func _e3_public(state: Dictionary) -> Dictionary:
 var out: Dictionary = {}
 for key in ["frame_id","cast_id","generation","room_id","rank","phase","a","radius","max_distance","born_at","expires_at","h11","h12","damage_stages_complete","release_completed","retired","return_consumed"]: out[key]=state[key]
 for key in ["b","exchange_at","return_until"]:
  if state.has(key): out[key]=state[key]
 out["member_ids"]=state.members.map(func(e): return str(e.team)+":"+str(e.actor_id))
 return out
func _e3_event(state: Dictionary, kind: String, at: float) -> void:
 var payload: Dictionary = _e3_public(state).merged({"event":kind,"source_time":at,"settled_at":hero_time},true)
 ink_e3_lifecycle.append(payload); emit_event("ink_e3_"+kind,payload)
func ink_presenter_snapshot() -> Dictionary:
 var out: Dictionary = super.ink_presenter_snapshot()
 out.e3_schema="ink-e3-clear-space-foundation-1"; out.frames={} if ink_frames.is_empty() else _e3_public(ink_frames)
 out.e3_receipts=ink_e3_receipts.duplicate(true); out.e3_finished=ink_e3_finished.duplicate(true); out.e3_lifecycle=ink_e3_lifecycle.duplicate(true)
 return out
