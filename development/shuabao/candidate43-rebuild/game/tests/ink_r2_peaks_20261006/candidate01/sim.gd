extends "res://tests/ink_e1_reform_pause_20261006/candidate01/sim.gd"
## Independent base-R2 mechanism. No host/chooser/presentation/ordinary promotion.
const PeakTuning = preload("res://tests/ink_r2_peaks_20261006/candidate01/tuning.gd")
const PeakGeometry = preload("res://tests/ink_r2_peaks_20261006/candidate01/peak_geometry.gd")
var ink_peaks: Dictionary = {}
var ink_r2_receipts: Array = []
var ink_r2_finished: Array = []
var _r2_serial: int = 0
var _r2_epoch: int = 0
var _r2_draining: bool = false
var _r2_sources_ok: bool = false
var _r2_packet_frames: Array = []

func _init() -> void:
 super._init()
 _r2_sources_ok = PeakTuning.sources_match()

func _r2_current(state: Dictionary) -> bool:
 return _r2_sources_ok and source_rules_hash == EXPECTED_RULES_HASH and not state.is_empty() and is_same(state,ink_peaks) and not bool(state.retired) and int(state.epoch) == _r2_epoch and effect_is_current(state) and is_same(hero,state.owner) and not hero.dead

func r2_preview(point: Vector3) -> Dictionary:
 if hero.loadout.r != "r2" or int(hero.ranks.r) <= 0: return {"accepted":false,"reason":"r2_unlearned","preview_only":true}
 var values: Dictionary = PeakTuning.values(int(hero.ranks.r))
 if values.is_empty(): return {"accepted":false,"reason":"invalid_r2_source_or_rank","preview_only":true}
 if not point.is_finite(): return {"accepted":false,"reason":"manual_aim_required","preview_only":true}
 var center: Vector3 = Geometry.ground(point)
 if not PeakGeometry.point_in_circle(center,hero.position,float(values.cast_range)): return {"accepted":false,"reason":"outside_placement_range","preview_only":true}
 return {"accepted":true,"reason":"","preview_only":true,"position":center,"radius":values.domain_radius,"duration":values.duration,"peak_count":values.peak_count,"rank":values.rank}

func _hero_action_policy(action: String, aim: Vector3 = Vector3.INF) -> Dictionary:
 if action != "r" or hero.loadout.r != "r2": return super._hero_action_policy(action,aim)
 if not _r2_sources_ok or source_rules_hash != EXPECTED_RULES_HASH: return {"reason":"source_binding_mismatch"}
 if _e1_form_current(): return {"reason":"rain_form_forbids_action"}
 if _ink_action_controlled("r"): return {"reason":"controlled"}
 if not ink_peaks.is_empty(): return {"reason":"peak_domain_already_active"}
 var preview: Dictionary = r2_preview(aim)
 if not preview.accepted: return {"reason":preview.reason}
 return {"stage":"peak_domain"}

func _hero_cast_skill(action: String, context: Dictionary) -> Dictionary:
 if action != "r" or hero.loadout.r != "r2": return super._hero_cast_skill(action,context)
 if not effect_is_current(context): return {"accepted":false,"reason":"stale_cast"}
 var preview: Dictionary = r2_preview(hero.aim_point)
 if not preview.accepted: return {"accepted":false,"reason":preview.reason}
 var values: Dictionary = PeakTuning.values(int(hero.ranks.r))
 _r2_serial += 1
 var state: Dictionary = context.duplicate(true)
 # R2 uses the world's existing clock, including eventual caster presentation.
 # Nominal AP is snapshotted once at the accepted cast, like original Q/E casts.
 state.merge({"owner":hero,"epoch":_r2_epoch,"retired":false,"domain_id":"%d:%s:peaks:%d"%[encounter_generation,room_id,_r2_serial],"position":preview.position,"radius":values.domain_radius,"rank":values.rank,"values":values,"born_at":clock.world_time,"expires_at":clock.world_time+float(values.duration),"ap_at_cast":float(hero.stats.ap),"peak_damage":float(values.peak_flat)+float(hero.stats.ap)*float(values.peak_ap_fraction),"rollup_damage":float(values.rollup_flat)+float(hero.stats.ap)*float(values.rollup_ap_percent)*0.01,"peaks":[],"timeline":[],"cursor":0,"work":{},"cast_finished":false,"warnings":0,"hits":0,"disappeared":0,"rollups":0},true)
 _r2_build_timeline(state)
 ink_peaks = state
 start_skill_cooldown("r",float(values.cooldown))
 emit_event("ink_r2_created",_r2_public(state))
 _r2_drain()
 return {"accepted":true,"phase":"peak_domain","domain_id":state.domain_id,"cancelled_during_callback":not _r2_current(state)}

func _r2_build_timeline(state: Dictionary) -> void:
 var values: Dictionary = state.values
 for ordinal: int in range(int(values.peak_count)):
  var start: float = float(state.born_at)+PeakTuning.warning_offset(values,ordinal)
  var peak: Dictionary = {"ordinal":ordinal,"peak_id":str(state.domain_id)+":peak:"+str(ordinal),"warning_at":start,"rise_at":start+float(values.warning_duration),"hit_at":start+float(values.hit_offset),"fade_at":start+float(values.hold_end_offset),"disappear_at":float(state.expires_at) if ordinal == int(values.peak_count)-1 else start+float(values.disappear_offset),"phase":"pending","position":state.position,"harmless":true,"selection_score":0,"target_ids":[],"hit_ids":{}}
  state.peaks.append(peak)
  var phases: Array = ["warning","rise","hit","fade","disappear"]
  for priority: int in range(phases.size()):
   var kind: String = str(phases[priority])
   state.timeline.append({"kind":kind,"ordinal":ordinal,"at":peak[kind+"_at"],"priority":priority})
 state.timeline.append({"kind":"rollup","ordinal":-1,"at":state.expires_at,"priority":5})
 state.timeline.append({"kind":"finish","ordinal":-1,"at":state.expires_at,"priority":6})
 state.timeline.sort_custom(func(a,b):
  if float(a.at) != float(b.at): return float(a.at) < float(b.at)
  if int(a.priority) != int(b.priority): return int(a.priority) < int(b.priority)
  return int(a.ordinal) < int(b.ordinal))

func _r2_enemy_current(enemy: Dictionary) -> bool:
 return not enemy.is_empty() and not bool(enemy.get("dead",true)) and str(enemy.get("state","")) != "spawn" and float(enemy.get("hp",0.0)) > 0.0 and int(enemy.get("generation",-1)) == encounter_generation and str(enemy.get("room_id","")) == room_id and is_same(enemy,enemy_by_id(str(enemy.get("actor_id","")))) and Vector3(enemy.position).is_finite() and is_finite(float(enemy.radius)) and float(enemy.radius) >= 0.0

func _r2_domain_targets(state: Dictionary) -> Array:
 var targets: Array = []
 var seen: Dictionary = {}
 for enemy: Dictionary in enemies:
  if _r2_enemy_current(enemy) and not seen.has(str(enemy.actor_id)) and PeakGeometry.point_in_circle(enemy.position,state.position,float(state.radius)+float(enemy.radius)):
   seen[str(enemy.actor_id)] = true
   targets.append(enemy)
 targets.sort_custom(func(a,b): return str(a.actor_id)<str(b.actor_id))
 return targets

func _r2_candidate_legal(state: Dictionary, point: Vector3) -> bool:
 return PeakGeometry.point_in_circle(point,state.position,float(state.radius))

func _r2_overlap(state: Dictionary, point: Vector3, enemy: Dictionary) -> bool:
 return PeakGeometry.clipped_body_overlap(state.position,float(state.radius),point,float(state.values.peak_radius),enemy.position,float(enemy.radius))

func _r2_select(state: Dictionary) -> Dictionary:
 var targets: Array = _r2_domain_targets(state)
 var candidates: Array = []
 for i: int in range(targets.size()):
  candidates.append({"position":Geometry.ground(targets[i].position),"identity":str(targets[i].actor_id)})
  for j: int in range(i+1,targets.size()):
   candidates.append({"position":Geometry.ground((Vector3(targets[i].position)+Vector3(targets[j].position))*0.5),"identity":str(targets[i].actor_id)+"|"+str(targets[j].actor_id)})
 candidates.sort_custom(func(a,b):
  if Vector3(a.position).x != Vector3(b.position).x: return Vector3(a.position).x < Vector3(b.position).x
  if Vector3(a.position).z != Vector3(b.position).z: return Vector3(a.position).z < Vector3(b.position).z
  return str(a.identity)<str(b.identity))
 var best: Dictionary = {"position":state.position,"score":0,"target_ids":[],"candidate_count":0,"harmless":true}
 for candidate: Dictionary in candidates:
  if not _r2_candidate_legal(state,candidate.position): continue
  best.candidate_count = int(best.candidate_count)+1
  var ids: Array = []
  for enemy: Dictionary in targets:
   if _r2_overlap(state,candidate.position,enemy): ids.append(str(enemy.actor_id))
  if ids.size() > int(best.score):
   best.position = candidate.position; best.score = ids.size(); best.target_ids = ids; best.harmless = false
 return best

func _r2_peak_public(state: Dictionary, peak: Dictionary) -> Dictionary:
 var out: Dictionary = _r2_public(state)
 for field: String in ["ordinal","peak_id","warning_at","rise_at","hit_at","fade_at","disappear_at","phase","position","harmless","selection_score","target_ids"]: out[field] = peak[field]
 out["domain_position"] = state.position
 out["peak_radius"] = state.values.peak_radius
 return out

func _r2_start_batch(state: Dictionary, entry: Dictionary) -> void:
 var rollup: bool = str(entry.kind) == "rollup"
 var peak: Dictionary = {} if rollup else state.peaks[int(entry.ordinal)]
 var targets: Array = []
 if rollup or not bool(peak.harmless):
  for enemy: Dictionary in _r2_domain_targets(state):
   if rollup or _r2_overlap(state,peak.position,enemy): targets.append(enemy)
 common.refresh_stats()
 var segment: String = "rollup" if rollup else "peak_"+str(entry.ordinal)
 state.work = {"entry":entry,"targets":targets,"cursor":0,"started":false,"segment":segment,"position":state.position if rollup else peak.position,"amount":state.rollup_damage if rollup else state.peak_damage,"impact_penetration":float(hero.stats.penetration),"impact_lifesteal_rate":hero.lifesteal(),"committed":[],"finished":false}

func _r2_drain_batch(state: Dictionary) -> void:
 var work: Dictionary = state.work
 var entry: Dictionary = work.entry
 var rollup: bool = str(entry.kind) == "rollup"
 if not bool(work.started):
  work.started = true
  if rollup: state.rollups = int(state.rollups)+1
  else: state.hits = int(state.hits)+1; state.peaks[int(entry.ordinal)].phase = "hit"
  emit_event("ink_r2_rollup_started" if rollup else "ink_r2_peak_hit_started",_r2_public(state).merged({"source_time":entry.at,"ordinal":entry.ordinal,"position":work.position,"target_ids":work.targets.map(func(enemy): return str(enemy.actor_id))},true))
 while _r2_current(state) and not paused and int(work.cursor) < work.targets.size():
  var enemy: Dictionary = work.targets[int(work.cursor)]
  work.cursor = int(work.cursor)+1
  # Membership and impact stats belong to this admitted hit-time batch. A
  # callback pause keeps this cursor, but dead/replaced actors never resurrect.
  if not _r2_enemy_current(enemy): continue
  if not claim_hit(int(state.cast_id),str(enemy.actor_id),"ink_r2_"+str(work.segment)): continue
  var effect_id: String = str(state.domain_id)+":"+str(work.segment)+":"+str(enemy.actor_id)
  var frame: Dictionary = {"state":state,"work":work,"enemy":enemy,"seen":false,"effect_id":effect_id,"ordinal":entry.ordinal,"source_time":entry.at}
  _r2_packet_frames.append(frame)
  var metadata: Dictionary = {"generation":state.generation,"room_id":state.room_id,"effect_id":effect_id,"position":work.position,"active_skill":true,"basic_attack":false,"area":true,"direct":true,"hex_generated":false,"impact_penetration":work.impact_penetration,"impact_lifesteal_rate":work.impact_lifesteal_rate}
  damage_enemy(enemy,float(work.amount),"r2",int(state.cast_id),false,false,metadata)
  if not _r2_packet_frames.is_empty() and is_same(_r2_packet_frames.back(),frame): _r2_packet_frames.pop_back()
 if not _r2_current(state) or paused: return
 if int(work.cursor) < work.targets.size(): return
 # Advance before notifying: a pause on the last packet or batch terminal
 # cannot replay it, and a new event never replaces a suspended current batch.
 state.work = {}; state.cursor = int(state.cursor)+1
 emit_event("ink_r2_rollup_finished" if rollup else "ink_r2_peak_hit_finished",_r2_public(state).merged({"source_time":entry.at,"ordinal":entry.ordinal,"position":work.position,"hit_target_ids":work.committed.duplicate()},true))

func emit_event(kind: String, data: Dictionary = {}) -> void:
 if kind == "damage" and str(data.get("source","")) == "r2" and not _r2_packet_frames.is_empty():
  var frame: Dictionary = _r2_packet_frames.back()
  if not bool(frame.seen) and int(data.get("cast_id",0)) == int(frame.state.cast_id) and str(data.get("target","")) == str(frame.enemy.actor_id):
   frame.seen = true
   # Capture the actual committed packet before user callbacks or nested hits;
   # no HP-delta inference and no bypass of existing common damage reactions.
   var receipt: Dictionary = {"domain_id":frame.state.domain_id,"cast_id":frame.state.cast_id,"generation":frame.state.generation,"room_id":frame.state.room_id,"ordinal":frame.ordinal,"segment":frame.work.segment,"effect_id":frame.effect_id,"source_time":frame.source_time,"settled_at":clock.world_time,"position":frame.work.position,"target_id":frame.enemy.actor_id,"nominal_damage":frame.work.amount,"actual_damage":data.amount}
   ink_r2_receipts.append(receipt)
   frame.work.committed.append(str(frame.enemy.actor_id))
   if int(frame.ordinal) >= 0: frame.state.peaks[int(frame.ordinal)].hit_ids[str(frame.enemy.actor_id)] = true
   data = data.merged({"r2_receipt":receipt.duplicate(true)},true)
 super.emit_event(kind,data)

func _r2_drain() -> void:
 if _r2_draining or ink_peaks.is_empty(): return
 _r2_draining = true
 var state: Dictionary = ink_peaks
 while _r2_current(state) and not paused:
  if not state.work.is_empty(): _r2_drain_batch(state); continue
  if int(state.cursor) >= state.timeline.size(): break
  var entry: Dictionary = state.timeline[int(state.cursor)]
  if clock.world_time+TIME_EPS < float(entry.at): break
  var kind: String = str(entry.kind)
  if kind in ["hit","rollup"]:
   _r2_start_batch(state,entry)
   continue
  if kind == "finish":
   if not bool(state.cast_finished):
    state.cast_finished = true
    finish_cast(int(state.cast_id))
   if not _r2_current(state) or paused: break
   var receipt: Dictionary = _r2_public(state).merged({"reason":"natural_expiry","finished_at":state.expires_at,"damage_stages_complete":true},true)
   state.retired = true; ink_peaks = {}
   ink_r2_finished.append(receipt)
   if ink_r2_finished.size() > 32: ink_r2_finished.pop_front()
   emit_event("ink_r2_finished",receipt)
   break
  var peak: Dictionary = state.peaks[int(entry.ordinal)]
  if kind == "warning":
   var selected: Dictionary = _r2_select(state)
   peak.position = selected.position; peak.harmless = selected.harmless
   peak.selection_score = selected.score; peak.target_ids = selected.target_ids
   peak["candidate_count"] = selected.candidate_count
   state.warnings = int(state.warnings)+1
  if kind == "disappear": state.disappeared = int(state.disappeared)+1
  peak.phase = kind
  state.cursor = int(state.cursor)+1
  emit_event("ink_r2_peak_"+kind,_r2_peak_public(state,peak).merged({"source_time":entry.at},true))
 _r2_draining = false

func _fixed_step(real_dt: float) -> void:
 if _r2_draining: return
 var scope: Dictionary = _ink_scope()
 var epoch: int = _r2_epoch
 _r2_drain()
 if not _ink_scope_current(scope) or epoch != _r2_epoch or hero.dead: return
 if paused:
  real_accumulator += real_dt
  return
 super._fixed_step(real_dt) # The only inherited world/AI/common/RNG tick.
 if not _ink_scope_current(scope) or epoch != _r2_epoch or hero.dead or paused: return
 _r2_drain()
 _check_victory()

func cancel_cast(id: int) -> void:
 if not ink_peaks.is_empty() and int(ink_peaks.cast_id) == id:
  ink_peaks.retired = true; ink_peaks.work = {}; ink_peaks = {}
 super.cancel_cast(id)

func _hero_clear_transients() -> void:
 _r2_epoch += 1
 if not ink_peaks.is_empty(): ink_peaks.retired = true; ink_peaks.work = {}
 ink_peaks = {}; _r2_packet_frames.clear()
 super._hero_clear_transients()

func _hero_victory_pending() -> bool:
 return not ink_peaks.is_empty() or _r2_draining or super._hero_victory_pending()

func _r2_public(state: Dictionary) -> Dictionary:
 var out: Dictionary = {}
 for field: String in ["domain_id","cast_id","generation","room_id","rank","position","radius","born_at","expires_at","warnings","hits","disappeared","rollups"]: out[field] = state[field]
 out["peak_count"] = state.values.peak_count
 out["remaining"] = maxf(0.0,float(state.expires_at)-clock.world_time)
 out["clock_domain"] = "world"
 return out

func ink_presenter_snapshot() -> Dictionary:
 var out: Dictionary = super.ink_presenter_snapshot()
 out["r2_schema"] = "ink-r2-ground-peaks-1"
 out["peaks_domain"] = _r2_public(ink_peaks) if _r2_current(ink_peaks) else {}
 out["ground_peaks"] = []
 if _r2_current(ink_peaks):
  for peak: Dictionary in ink_peaks.peaks:
   if str(peak.phase) not in ["pending","disappear"]: out.ground_peaks.append(_r2_peak_public(ink_peaks,peak))
 out["r2_finished"] = ink_r2_finished.duplicate(true)
 return out

func _hero_snapshot() -> Dictionary:
 var out: Dictionary = super._hero_snapshot()
 out["r2_core_candidate"] = {"ordinary_entry_ready":false,"runtime_validation":"NOT_RUN","H15_H16_available":false,"native_input":false,"art_audio_accepted":false,"balance_status":"authored_unbalanced"}
 return out
