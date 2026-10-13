extends SceneTree
## Explicit source/API fixture and synchronous callbacks. No ordinary learning,
## native input, presentation, visual acceptance or full legacy matrix claim.
const Sim = preload("res://tests/ink_r2_peaks_20261006/candidate01/sim.gd")
const ParentSim = preload("res://tests/ink_e1_reform_pause_20261006/candidate01/sim.gd")
const PeakTuning = preload("res://tests/ink_r2_peaks_20261006/candidate01/tuning.gd")
const PeakGeometry = preload("res://tests/ink_r2_peaks_20261006/candidate01/peak_geometry.gd")
const Design = preload("res://data/final_design/catalog.gd")
const REQUIRED_GROUPS: Array = ["r2_source_admission_schedule","r2_density_locked_footprint","r2_pause_and_retirement","r2_world_clock_and_passives"]
const BINDING := "res://tests/ink_r2_peaks_20261006/candidate01/source_binding.json"
const COUNTS := [7,9,13,20]
const DURATIONS := [5.0,5.5,6.5,8.0]
const RADII := [10.0,10.54,11.5,13.0]
const COOLDOWNS := [145.0,136.0,121.0,101.0]
const PEAK_DAMAGE := [65.0,85.0,120.0,170.0]
const ROLLUP_DAMAGE := [520.0,680.0,1060.0,1620.0]
var checks: int = 0
var failures: Array[String] = []
var groups: Array[String] = []
var observations: Dictionary = {}
var serial: int = 0
var output_path: String = ""

func _initialize() -> void:
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--r2-result="): output_path = arg.trim_prefix("--r2-result=")
 run.call_deferred()

func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok: failures.append(label); push_error(label)

func near(actual: float, expected: float, label: String, tolerance: float = 0.0001) -> void:
 check(is_finite(actual) and absf(actual-expected) <= tolerance,label+" actual="+str(actual)+" expected="+str(expected))

func fixture(rank: int = 1, passive: String = "p1", parent: bool = false):
 serial += 1
 var sim = ParentSim.new() if parent else Sim.new()
 root.add_child(sim)
 sim.auto_finish = false; sim.ai_enabled = false; sim.arena_half_extent = 30.0; sim.obstacles = []
 sim.hero.loadout.r = "r2"; sim.hero.ranks.r = rank
 sim.hero.loadout.q = "q1"; sim.hero.ranks.q = 1
 sim.hero.loadout.e = "e1"; sim.hero.ranks.e = 1
 sim.hero.loadout.passive = passive; sim.hero.ranks.passive = 1
 sim.set_projected_stats({"AP":100.0,"move_speed":10.0,"crit_chance":0.0,"regen":0.0,"lifesteal":0.0,"cdr":0.0})
 check(sim.begin_encounter("r2-source-fixture-%d"%serial,[]).accepted,"explicit fixture encounter starts")
 sim.hero.position = Vector3.ZERO
 return sim

func target(sim, point: Vector3, hp: float = 100000.0, radius: float = 0.25) -> Dictionary:
 var enemy: Dictionary = sim.spawn_enemy("minion",point,hp)
 enemy.position = point; enemy.state = "chase"; enemy.defence = 0.0; enemy.radius = radius
 return enemy

func cast(sim, point: Vector3 = Vector3.ZERO, command: String = "") -> Dictionary:
 var result: Dictionary = sim.request_action("r",point,command)
 check(result.accepted,"public source R2 cast accepted: "+str(result.get("reason","")))
 return result

func trace_for(sim) -> Array:
 var trace: Array = []
 sim.combat_event.connect(func(event: Dictionary): trace.append(event.duplicate(true)))
 return trace

func events(trace: Array, kind: String) -> Array:
 return trace.filter(func(event): return event.kind == kind)

func r2_packets(trace: Array) -> Array:
 return trace.filter(func(event): return event.kind == "damage" and event.get("source","") == "r2")

func admission_bytes(sim) -> PackedByteArray:
 return var_to_bytes([sim.cast_serial,sim.hero.cooldowns,sim.hero.position,sim.hero.aim_point,sim.hero.facing,sim.clock.world_time,sim.hero_time,sim.real_time,sim.ink_peaks,sim.ink_r2_receipts])

func rejected(sim, point: Vector3, label: String) -> Dictionary:
 var before: PackedByteArray = admission_bytes(sim)
 var result: Dictionary = sim.request_action("r",point)
 check(not result.accepted,label+" rejected")
 check(before == admission_bytes(sim),label+" no cast/CD/aim/time mutation")
 return result

func group_done(name: String) -> void:
 groups.append(name)
 print("INK_R2_PEAKS_GROUP ",name)

func r2_source_admission_schedule() -> void:
 var sim = fixture()
 rejected(sim,Vector3.INF,"missing manual aim")
 rejected(sim,Vector3(12.01,0,0),"outside original 12m")
 sim.hero.stun_left = 1.0
 check(rejected(sim,Vector3.ZERO,"controlled R").reason == "controlled","control uses original gate")
 sim.hero.stun_left = 0.0; sim.paused = true
 rejected(sim,Vector3.ZERO,"paused R")
 sim.paused = false; sim.hero.ranks.r = 0
 rejected(sim,Vector3.ZERO,"unlearned R")
 sim.hero.ranks.r = 5
 rejected(sim,Vector3.ZERO,"invalid rank")
 sim.hero.ranks.r = 1; sim.hero.lock_time = 1.0
 rejected(sim,Vector3.ZERO,"locked R")
 sim.hero.lock_time = 0.0
 check(sim.request_action("ink_e_down").accepted,"real E1 form starts")
 check(rejected(sim,Vector3.ZERO,"E1 form R").reason == "rain_form_forbids_action","rain policy retained")
 sim.request_action("ink_e_up")
 sim.obstacles = [{"position":Vector3(4,0,0),"half":Vector3(1,0,1)}]
 check(sim.r2_preview(Vector3(4,0,0)).accepted,"R2 does not inherit E3 wall landing restrictions")
 sim.obstacles = []; sim.arena_half_extent = 8.0
 check(sim.r2_preview(Vector3(9,0,0)).accepted,"original area placement does not inherit actor room landing rules")
 sim.arena_half_extent = 30.0
 var accepted: Dictionary = cast(sim,Vector3(12,0,0),"one-root")
 var cd: float = sim.hero.cooldowns.r
 var duplicate: Dictionary = sim.request_action("r",Vector3.ZERO,"one-root")
 check(duplicate == accepted,"command replay returns original result")
 check(sim.cast_serial == int(accepted.cast_id),"command replay allocates no root")
 near(sim.hero.cooldowns.r,cd,"command replay does not restart CD")
 rejected(sim,Vector3.ZERO,"active domain second R")
 sim.cancel_cast(int(accepted.cast_id))
 rejected(sim,Vector3.ZERO,"cancelled R retains spent CD")
 sim.free()
 observations.ranks = []
 for rank: int in range(1,5):
  sim = fixture(rank)
  var enemy: Dictionary = target(sim,Vector3.ZERO)
  var trace: Array = trace_for(sim)
  var result: Dictionary = cast(sim)
  var state: Dictionary = sim.ink_peaks
  var start: float = sim.clock.world_time
  near(float(state.radius),float(RADII[rank-1]),"source domain radius")
  near(float(state.expires_at)-start,float(DURATIONS[rank-1]),"source duration")
  near(sim.hero.cooldowns.r,float(COOLDOWNS[rank-1]),"source CD once")
  near(float(state.ap_at_cast),100.0,"cast AP snapshot")
  check(state.warnings == 1 and state.hits == 0,"first beat is warning, never immediate damage")
  near(enemy.hp,100000.0,"warning causes no damage")
  sim.step(float(DURATIONS[rank-1])+0.02)
  var warnings: Array = events(trace,"ink_r2_peak_warning")
  var rises: Array = events(trace,"ink_r2_peak_rise")
  var hit_starts: Array = events(trace,"ink_r2_peak_hit_started")
  var fades: Array = events(trace,"ink_r2_peak_fade")
  var disappeared: Array = events(trace,"ink_r2_peak_disappear")
  check(warnings.size() == int(COUNTS[rank-1]) and rises.size() == warnings.size() and hit_starts.size() == warnings.size() and fades.size() == warnings.size() and disappeared.size() == warnings.size(),"strict N complete peak phases rank "+str(rank))
  for i: int in range(warnings.size()):
   var expected: float = float(i)*(float(DURATIONS[rank-1])-0.48)/float(int(COUNTS[rank-1])-1)
   near(float(warnings[i].source_time)-start,expected,"absolute formula, not rounded interval accumulation")
   near(float(rises[i].source_time)-float(warnings[i].source_time),0.18,"0.18 warning")
   near(float(hit_starts[i].source_time)-float(warnings[i].source_time),0.24,"single 0.24 hit")
   near(float(disappeared[i].source_time)-float(rises[i].source_time),0.30,"original 0.3 peak body")
   check(int(warnings[i].ordinal) == i,"one stable ordinal")
   check(warnings[i].position == Vector3.ZERO,"dense single body has no angle rotation")
  check(events(trace,"ink_r2_rollup_started").size() == 1 and events(trace,"ink_r2_rollup_finished").size() == 1 and events(trace,"ink_r2_finished").size() == 1,"single original rollup and completion")
  check(disappeared.back().sequence < events(trace,"ink_r2_rollup_started")[0].sequence and events(trace,"ink_r2_rollup_finished")[0].sequence < events(trace,"ink_r2_finished")[0].sequence,"last disappearance precedes rollup then completion")
  near(float(disappeared.back().source_time),start+float(DURATIONS[rank-1]),"last peak ends at source D")
  check(sim.ink_r2_receipts.size() == int(COUNTS[rank-1])+1,"one target one damage per peak plus rollup")
  for receipt: Dictionary in sim.ink_r2_receipts:
   near(float(receipt.actual_damage),float(ROLLUP_DAMAGE[rank-1]) if receipt.segment == "rollup" else float(PEAK_DAMAGE[rank-1]),"separate authored peak and original rollup damage")
  near(100000.0-float(enemy.hp),float(COUNTS[rank-1])*float(PEAK_DAMAGE[rank-1])+float(ROLLUP_DAMAGE[rank-1]),"actual HP matches strict source total")
  check(sim.ink_peaks.is_empty() and sim._casts[int(result.cast_id)].finished,"natural cast clears and finishes once")
  near(sim.hero.cooldowns.r,float(COOLDOWNS[rank-1])-(sim.hero_time-start),"no cooldown restart/refund at rollup")
  check(sim.ink_core_steps == int(round((float(DURATIONS[rank-1])+0.02)/0.02)),"one inherited core tick per admitted fixed step")
  var receipt_count: int = sim.ink_r2_receipts.size()
  sim.step(0.1)
  check(sim.ink_r2_receipts.size() == receipt_count and sim.ink_r2_finished.size() == 1,"completed R never replays")
  observations.ranks.append({"rank":rank,"peaks":warnings.size(),"damage_packets":receipt_count,"finish":sim.ink_r2_finished[0]})
  sim.free()
 group_done(REQUIRED_GROUPS[0])

func r2_density_locked_footprint() -> void:
 var sim = fixture()
 var a: Dictionary = target(sim,Vector3(-4,0,0))
 var b: Dictionary = target(sim,Vector3(2,0,0))
 var c: Dictionary = target(sim,Vector3(5.8,0,0))
 var trace: Array = trace_for(sim)
 cast(sim)
 var state: Dictionary = sim.ink_peaks
 var peak: Dictionary = state.peaks[0]
 check(peak.position.is_equal_approx(Vector3(3.9,0,0)) and peak.selection_score == 2,"pair midpoint beats each isolated center and no boss weight")
 var locked: Vector3 = peak.position
 b.position = Vector3(7,0,7); c.position = Vector3(7,0,-7)
 a.position = locked
 sim.hero.position = Vector3(-8,0,0); sim.hero.facing = Vector3.BACK
 sim.step(0.24)
 check(peak.position == locked and state.position == Vector3.ZERO,"locked warning and domain never follow hero or targets")
 check(sim.ink_r2_receipts.size() == 1 and sim.ink_r2_receipts[0].target_id == a.actor_id,"leavers dodge; current entrant is hit")
 near(float(b.hp),100000.0,"selected leaver B unharmed")
 near(float(c.hp),100000.0,"selected leaver C unharmed")
 b.position = Vector3(-5,0,0); c.position = Vector3(-4,0,0); a.position = Vector3(8,0,0)
 sim.step(0.52)
 check(state.peaks[1].selection_score == 2 and Vector3(state.peaks[1].position).x < 0.0,"next ordinal independently selects newly dense group")
 sim.enemies.reverse()
 var first: Dictionary = sim._r2_select(state)
 sim.enemies.reverse()
 check(sim._r2_select(state) == first,"enemy array order does not change stable tie-break")
 sim.free()
 sim = fixture()
 a = target(sim,Vector3(0,0,0)); b = target(sim,Vector3(10.1,0,0),100000.0,0.2)
 var outside: Dictionary = target(sim,Vector3(12.0,0,0),100000.0,0.2)
 cast(sim,Vector3.ZERO)
 state = sim.ink_peaks
 check(not sim._r2_candidate_legal(state,Vector3(10.1,0,0)),"outside enemy center cannot become an outside peak center")
 check(sim._r2_overlap(state,Vector3(10,0,0),b),"edge body overlaps clipped peak inside original domain")
 check(not sim._r2_overlap(state,Vector3(10,0,0),outside),"peak extent cannot damage a body wholly outside original domain")
 check(PeakGeometry.point_in_circle(Vector3(10,0,0),Vector3.ZERO,10.0),"original exactly represented boundary is included")
 check(not PeakGeometry.point_in_circle(Vector3(10.000000953674316,0,0),Vector3.ZERO,10.0),"next representable float32 exterior point cannot use epsilon to enter domain")
 check(not PeakGeometry.clipped_body_overlap(Vector3.ZERO,10.0,Vector3(10,0,0),2.0,Vector3(10.000000953674316,0,0),0.0),"next representable body point outside domain fails before intersection residue")
 check(not PeakGeometry.clipped_body_overlap(Vector3.ZERO,1.0,Vector3(1.8,0,0),1.0,Vector3(0.9,0,1.5588457),1.0),"three pairwise overlaps without common area are rejected")
 check(PeakGeometry.clipped_body_overlap(Vector3.ZERO,10.0,Vector3(8,0,0),2.0,Vector3(10.2,0,0),0.2),"closed tangent contact at fixed boundary is eligible")
 sim.step(5.0)
 check(sim.ink_r2_receipts.any(func(receipt): return receipt.segment == "rollup" and receipt.target_id == b.actor_id),"original rollup includes intersecting boundary body")
 check(not sim.ink_r2_receipts.any(func(receipt): return receipt.target_id == outside.actor_id),"outside body never gets peak or rollup")
 sim.free()
 sim = fixture()
 trace = trace_for(sim)
 cast(sim)
 state = sim.ink_peaks
 check(state.peaks[0].harmless,"empty warning consumes harmless ordinal")
 a = target(sim,Vector3.ZERO)
 sim.step(0.24)
 check(sim.ink_r2_receipts.is_empty() and state.hits == 1,"empty-selected ordinal stays harmless after enemy arrives")
 sim.step(4.76)
 check(events(trace,"ink_r2_peak_warning").size() == 7 and sim.ink_r2_receipts.size() == 7,"empty ordinal not banked: six damaging peaks plus one rollup")
 sim.free()
 sim = fixture()
 a = target(sim,Vector3(-5,0,0)); b = target(sim,Vector3(5,0,0))
 b.rank_category = "boss"
 cast(sim)
 check(sim.ink_peaks.peaks[0].position == Vector3(-5,0,0),"equal scores choose ground coordinate, not boss category or facing")
 sim.free()
 group_done(REQUIRED_GROUPS[1])

func pause_case(segment: String, after_count: int) -> void:
 var sim = fixture()
 var a: Dictionary = target(sim,Vector3.ZERO)
 var b: Dictionary = target(sim,Vector3(1,0,0))
 var trace: Array = trace_for(sim)
 var result: Dictionary = cast(sim)
 var state: Dictionary = sim.ink_peaks
 var hook: Dictionary = {"count":0,"fired":false}
 sim.combat_event.connect(func(event: Dictionary):
  if event.kind != "damage" or not event.has("r2_receipt") or event.r2_receipt.segment != segment: return
  hook.count = int(hook.count)+1
  if int(hook.count) == after_count and not hook.fired: hook.fired = true; sim.paused = true)
 sim.step(0.24 if segment == "peak_0" else 5.0)
 check(sim.paused and hook.fired and not state.work.is_empty(),"callback pause retains admitted "+segment+" batch")
 check(int(state.work.cursor) == after_count,"cursor advances through only committed packets")
 check(not sim._casts[int(result.cast_id)].finished and sim.ink_r2_finished.is_empty(),"even last-packet pause retains terminal")
 var before: PackedByteArray = var_to_bytes([a.hp,b.hp,sim.clock.world_time,sim.hero_time,sim.real_time,sim.hero.cooldowns,sim.ink_core_steps,state.cursor,state.work.cursor,sim.ink_r2_receipts])
 sim.step(0.5)
 check(before == var_to_bytes([a.hp,b.hp,sim.clock.world_time,sim.hero_time,sim.real_time,sim.hero.cooldowns,sim.ink_core_steps,state.cursor,state.work.cursor,sim.ink_r2_receipts]),"held pause freezes clocks/CD/core/cursor/HP")
 if after_count == 1:
  check(not sim._hit_claims.has("%d:%d:ink_r2_%s:%s"%[sim.encounter_generation,int(result.cast_id),segment,b.actor_id]),"paused next target has no early hit claim")
  b.position = Vector3(20,0,20)
 var world_before: float = sim.clock.world_time
 var steps_before: int = sim.ink_core_steps
 sim.paused = false; sim.step(0.02)
 var segment_receipts: Array = sim.ink_r2_receipts.filter(func(receipt): return receipt.segment == segment)
 check(segment_receipts.size() == 2,"resume retains hit-time membership without repeating prior target")
 check(segment_receipts.map(func(receipt): return receipt.target_id) == [a.actor_id,b.actor_id],"resume uses deterministic original target order")
 near(float(segment_receipts[1].settled_at),world_before,"already admitted remainder drains before new clock tick")
 near(sim.clock.world_time,world_before+0.02,"resume runs one world tick")
 check(sim.ink_core_steps == steps_before+1,"resume has exactly one inherited core step")
 check(sim._r2_packet_frames.is_empty() and not sim._r2_draining,"packet and drain guards unwind")
 if segment == "rollup":
  check(sim.ink_peaks.is_empty() and sim.ink_r2_finished.size() == 1 and events(trace,"ink_r2_rollup_started").size() == 1,"rollup pause resumes once and completes")
 else:
  check(state.work.is_empty() and state.hits == 1,"peak pause drains original only")
 sim.free()

func retirement_case(kind: String, segment: String) -> void:
 var sim = fixture()
 target(sim,Vector3.ZERO); target(sim,Vector3(1,0,0))
 var trace: Array = trace_for(sim)
 var result: Dictionary = cast(sim)
 var state: Dictionary = sim.ink_peaks
 var hook: Dictionary = {"fired":false}
 sim.combat_event.connect(func(event: Dictionary):
  if hook.fired or event.kind != "damage" or not event.has("r2_receipt") or event.r2_receipt.segment != segment: return
  hook.fired = true
  match kind:
   "cancel": sim.cancel_cast(int(result.cast_id))
   "death": sim.damage_hero(100000.0,Vector3.ZERO,0.0,true,true)
   "room": sim.end_encounter("cleared"); sim.begin_encounter("replacement-r2-room",[]))
 sim.step(0.24 if segment == "peak_0" else 5.0)
 check(hook.fired and state.retired and sim.ink_peaks.is_empty() and state.work.is_empty(),kind+" retires source, pending batch and all future ordinals")
 check(events(trace,"ink_r2_finished").is_empty(),kind+" produces no synthetic terminal")
 var matches: Array = r2_packets(trace).filter(func(event): return event.r2_receipt.segment == segment)
 check(matches.size() == 1,kind+" callback stops before second admitted target")
 var count: int = r2_packets(trace).size()
 sim.step(10.0)
 check(r2_packets(trace).size() == count,kind+" never repays cancelled events or rollup")
 sim.free()

func r2_pause_and_retirement() -> void:
 for segment: String in ["peak_0","rollup"]:
  for after_count: int in [1,2]: pause_case(segment,after_count)
  for kind: String in ["cancel","death","room"]: retirement_case(kind,segment)
 var sim = fixture()
 var a: Dictionary = target(sim,Vector3.ZERO)
 var old: Dictionary = target(sim,Vector3(1,0,0))
 var result: Dictionary = cast(sim)
 var hook: Dictionary = {"fired":false}
 sim.combat_event.connect(func(event: Dictionary):
  if event.kind == "damage" and event.get("source","") == "r2" and not hook.fired: hook.fired = true; sim.paused = true)
 sim.step(0.24)
 sim.enemies.erase(old)
 var replacement: Dictionary = target(sim,Vector3(1,0,0))
 replacement.actor_id = old.actor_id
 var newcomer: Dictionary = target(sim,Vector3(0.5,0,0))
 sim.paused = false; sim.step(0.02)
 check(sim.ink_r2_receipts.size() == 1 and sim.ink_r2_receipts[0].target_id == a.actor_id,"resume skips replaced exact identity and never adds newcomer")
 near(float(old.hp),100000.0,"old retired body untouched")
 near(float(replacement.hp),100000.0,"same ID replacement not admitted")
 near(float(newcomer.hp),100000.0,"post-snapshot newcomer not admitted")
 sim.cancel_cast(int(result.cast_id)); sim.free()
 sim = fixture()
 target(sim,Vector3.ZERO,1.0)
 sim.auto_finish = true
 var trace: Array = trace_for(sim)
 cast(sim)
 sim.step(0.24)
 check(sim.phase == "combat" and not sim.ink_peaks.is_empty(),"victory waits for remaining strict-N harmless peaks")
 sim.step(4.76)
 check(sim.phase == "victory" and events(trace,"ink_r2_peak_warning").size() == 7 and events(trace,"ink_r2_rollup_started").size() == 1 and events(trace,"ink_r2_finished").size() == 1,"victory occurs after single real R2 terminal")
 sim.free()
 group_done(REQUIRED_GROUPS[2])

func fill_p2(sim) -> void:
 for index: int in range(4):
  sim.hero.cooldowns.q = 0.0
  var result: Dictionary
  if index%2 == 0:
   sim.hero.loadout.q = "q1"
   check(sim.request_ink_input("q_down").accepted,"P2 setup Q1 arm")
   check(sim.request_ink_input("left_down",Vector3.ZERO).accepted,"P2 setup Q1 begin")
   check(sim.request_ink_input("motion",Vector3(0.26,0,0)).accepted,"P2 setup Q1 motion")
   result = sim.request_ink_input("left_up",Vector3(0.26,0,0))
  else:
   sim.hero.loadout.q = "q2"
   check(sim.request_q2("first",Vector3(0,0,-3)).accepted,"P2 setup Q2 first")
   result = sim.request_q2("second",Vector3(0,0,3))
  check(result.accepted,"real successful P2 use milestone")
  sim.cancel_cast(int(result.cast_id))
 check(sim.p2.stacks == 3 and sim.p2.ready_epoch > 0,"four real alternating uses make P2 ready")

func r2_world_clock_and_passives() -> void:
 var sim = fixture()
 target(sim,Vector3.ZERO)
 var trace: Array = trace_for(sim)
 cast(sim)
 var state: Dictionary = sim.ink_peaks
 var cd: float = sim.hero.cooldowns.r
 sim.move_during_hitstop(0.2,Vector3.RIGHT)
 near(sim.clock.world_time,0.0,"hitstop locomotion never advances R2 world")
 check(state.hits == 0,"hitstop cannot trigger peak")
 near(sim.hero.cooldowns.r,cd,"hitstop leaves CD unchanged")
 sim.clock.enter("unrelated-presenter",2.0)
 var world_rate: float = sim.clock.scale_factor()
 sim.step(0.2)
 near(sim.clock.world_time,0.2*world_rate,"R2 shares existing slowed world")
 check(state.hits == 0 and sim.ink_core_steps == 10,"world slow does not add private world ticks")
 near(sim.hero.cooldowns.r,cd-0.2*world_rate,"original actor cooldown follows inherited slow policy")
 sim.clock.leave("unrelated-presenter")
 sim.hero.stun_left = 3.0
 sim.step(0.24)
 check(state.hits == 1,"existing R2 continues under later control")
 check(sim._presentation.is_empty() and not sim.r1_active and not sim.hero_damage_immune(),"mechanism creates no short presentation or new immunity")
 sim.free()
 sim = fixture(1,"p2")
 fill_p2(sim)
 var uses_before: int = sim.ink_p2_uses.size()
 var stack_before: int = sim.p2.stacks
 var ready_before: int = sim.p2.ready_epoch
 target(sim,Vector3.ZERO)
 cast(sim)
 sim.step(0.24)
 check(sim.ink_p2_uses.size() == uses_before and sim.p2.stacks == stack_before and sim.p2.ready_epoch == ready_before,"R2 neither counts as Q/E use nor consumes ready P2")
 check(sim.ink_p2_claims.is_empty() and sim.ink_p2_splashes.is_empty() and sim.ink_p1_receipts.is_empty(),"R2 damage creates no passive settlement")
 sim.free()
 sim = fixture()
 target(sim,Vector3.ZERO)
 cast(sim); sim.step(5.0)
 check(sim.p1.roots.is_empty() and sim.ink_p1_receipts.is_empty(),"single-target R2 never creates P1 root, supplement or refund")
 near(sim.hero.cooldowns.r,140.0,"P1 R2 CD remains original spent CD minus world time")
 sim.set_hexes(["yanguizhou_h15","yanguizhou_h16"])
 check(not sim.hx("yanguizhou_h15") and not sim.hx("yanguizhou_h16"),"both original R2 Hex definitions remain unadmitted")
 near(Design.hex_parameter("yanguizhou_h15","H15-1"),25.0,"original H15 interval reduction retained")
 near(Design.hex_parameter("yanguizhou_h15","H15-2"),30.0,"original H15 final damage retained")
 near(Design.hex_parameter("yanguizhou_h16","H16-1"),4.0,"original H16 displacement definition retained")
 sim.free()
 # Compare the inherited E1 two-channel observable result on this new leaf.
 var outcomes: Array = []
 for parent: bool in [true,false]:
  sim = fixture(1,"p1",parent)
  var enemy: Dictionary = target(sim,Vector3(0.3,0,0))
  check(sim.request_action("ink_e_down").accepted,"inherited E1 entry")
  sim.move_during_hitstop(0.02,Vector3.RIGHT)
  check(sim.request_action("ink_e_up").accepted,"inherited E1 release")
  outcomes.append({"hp":enemy.hp,"cd":sim.hero.cooldowns.e,"receipts":sim.ink_e1_receipts.map(func(receipt): return [receipt.segment_id,receipt.actual_damage]),"p1":sim.ink_p1_receipts.map(func(receipt): return [receipt.ordinary_packet_count,receipt.actual_supplement,receipt.cooldown_refund]),"world":sim.clock.world_time,"core":sim.ink_core_steps})
  sim.free()
 check(outcomes[0] == outcomes[1],"new R2 leaf preserves affected E1 remainder/P1 observable path")
 observations.inherited_e1 = outcomes
 group_done(REQUIRED_GROUPS[3])

func run() -> void:
 r2_source_admission_schedule()
 r2_density_locked_footprint()
 r2_pause_and_retirement()
 r2_world_clock_and_passives()
 for group: String in REQUIRED_GROUPS: check(groups.count(group) == 1,"required group reached exactly once")
 var report: Dictionary = {"schema":"ink-r2-peaks-finite-1","passed":failures.is_empty() and groups == REQUIRED_GROUPS,"checks":checks,"failures":failures,"completed":groups,"source_binding_sha256":FileAccess.get_sha256(BINDING),"observations":observations,"mode":"SOURCE_API_AND_SYNCHRONOUS_CALLBACK_FIXTURE","native_input":false,"ordinary_admission":false,"production_entry_changed":false,"old_full_matrices_rerun":false,"visual_acceptance":false,"balance_accepted":false}
 if not output_path.is_empty():
  var output := FileAccess.open(output_path,FileAccess.WRITE)
  if output == null: push_error("cannot write R2 finite report"); quit(2); return
  output.store_string(JSON.stringify(report,"  ")+"\n")
 print("INK_R2_PEAKS_REPORT ",JSON.stringify(report))
 quit(0 if report.passed else 1)
