extends SceneTree
## Affected boundary cases only. No inherited old full matrix is rerun here.
const Candidate = preload("res://tests/ink_e2_boundary_20261006/candidate01/sim.gd")
const Boundary = preload("res://tests/ink_e2_boundary_20261006/candidate01/boat_boundary.gd")
var checks: int = 0
var failures: Array[String] = []
var observations: Dictionary = {}
var groups: Array[String] = []
const REQUIRED_GROUPS := ["edges_and_corner","initial_front_and_exact_landing","parked_clock_damage_and_expiry","boundary_contact_pause_and_queued_input","paused_terminal_and_scope"]
var output_path: String = ""

func _initialize() -> void:
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--boundary-result="): output_path = arg.trim_prefix("--boundary-result=")
 run.call_deferred()

func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok: failures.append(label); push_error(label)

func near(actual: float, expected: float, label: String) -> void:
 check(is_finite(actual) and absf(actual-expected) <= 0.00001,label)

func point_near(actual: Vector3, expected: Vector3, label: String) -> void:
 check(actual.is_finite() and actual.distance_to(expected) <= 0.00001,label)

func fresh(extent: float = 2.0):
 var sim = Candidate.new(); root.add_child(sim)
 sim.auto_finish = false; sim.ai_enabled = false; sim.arena_half_extent = extent
 sim.hero.position = Vector3.ZERO; sim.hero.loadout.e = "e2"; sim.hero.ranks.e = 1
 sim.hero.loadout.q = "q1"; sim.hero.ranks.q = 1
 sim.hero.stats.ap = 100.0; sim.hero.stats.crit_chance = 0.0; sim.hero.stats.regen = 0.0
 sim.begin_encounter("ink-e2-boundary-only",[]); sim.set_hexes([])
 return sim

func target(sim, point: Vector3, radius: float = 0.25) -> Dictionary:
 var enemy: Dictionary = sim.spawn_enemy("minion",point,10000.0)
 enemy.state = "chase"; enemy.defence = 0.0; enemy.radius = radius
 # Explicit finite fixture position after spawn's standard radius clamp.
 enemy.position = point
 return enemy

func edges_and_corner() -> void:
 var edge_records: Array = []
 for direction: Vector3 in [Vector3.RIGHT,Vector3.LEFT,Vector3.BACK,Vector3.FORWARD]:
  var sim = fresh()
  check(sim.request_action("e",direction*20.0).get("accepted",false),"projected outside route now launches: "+str(direction))
  if sim.ink_boat.is_empty(): sim.free(); continue
  var state: Dictionary = sim.ink_boat
  sim.step(1.0)
  point_near(state.position,direction*2.0,"physical room edge, no hero-radius inset: "+str(direction))
  check(state.boundary_parked and state.phase == "outward" and sim.ink_e2_finished.is_empty(),"edge parks without early retirement: "+str(direction))
  near(state.voyage_until,3.0,"parking preserves original lifetime")
  near(sim.hero.cooldowns.e,15.0,"parking preserves original running cooldown")
  var rejected: Dictionary = sim.request_action("e",Vector3.INF)
  check(not rejected.get("accepted",false) and rejected.get("reason","") == "illegal_current_boat_landing","edge boarding rejects real hero footprint")
  check(is_same(state,sim.ink_boat) and sim.hero.position == Vector3.ZERO,"illegal edge boarding preserves original boat and hero")
  sim.step(0.4)
  point_near(state.position,direction*2.0,"parked point does not drift")
  edge_records.append(sim._e2_public(state)); sim.free()
 var diagonal: Vector3 = Vector3(1,0,1).normalized()
 var sim = fresh()
 check(sim.request_action("e",diagonal*20.0).get("accepted",false),"corner route launches")
 if not sim.ink_boat.is_empty():
  sim.step(1.0)
  var point: Vector3 = sim.ink_boat.position
  var coordinate: float = 2.0-0.55/sqrt(2.0)
  point_near(point,Vector3(coordinate,0,coordinate),"diagonal full front first contacts both physical edges")
  var side: Vector3 = Vector3(-diagonal.z,0,diagonal.x)*0.55
  for tip: Vector3 in [point+side,point-side]:
   check(absf(tip.x) <= 2.0+0.0000001 and absf(tip.z) <= 2.0+0.0000001,"both actual front endpoints stay in room")
  observations["corner"] = sim._e2_public(sim.ink_boat)
 sim.free()
 sim = fresh()
 var oblique: Vector3 = Vector3(4,0,1).normalized()
 check(sim.request_action("e",oblique*20.0).get("accepted",false),"oblique route launches")
 if not sim.ink_boat.is_empty():
  sim.step(1.0)
  var expected_x: float = 2.0-0.55*absf(oblique.z)
  var expected: Vector3 = Vector3(expected_x,0,expected_x/4.0)
  point_near(sim.ink_boat.position,expected,"oblique route stops at first edge")
  sim.step(0.5)
  point_near(sim.ink_boat.position,expected,"remaining time never slides along edge")
 sim.free()
 observations["four_edges"] = edge_records

 groups.append("edges_and_corner")

func initial_front_and_exact_landing() -> void:
 var sim = fresh()
 sim.hero_radius = 0.1
 sim.hero.position = Vector3(1.9,0,1.9)
 var origin: Vector3 = sim.hero.position
 var rejected: Dictionary = sim.request_action("e",Vector3(5,0,5))
 check(not rejected.get("accepted",false) and rejected.get("reason","") == "initial_boat_front_outside_room","corner initial front outside physical room is explicitly rejected")
 check(sim.cast_serial == 0 and sim.ink_boat.is_empty() and sim.hero.position == origin,"initial front rejection creates no root and does not project")
 near(sim.hero.cooldowns.e,0.0,"invalid initial front starts no cooldown")
 sim.free()
 sim = fresh(4.0)
 var legal: Vector3 = Vector3(4.0-sim.hero_radius,0,0)
 check(sim._e2_landing_legal(legal),"exact hero room tangent remains legal")
 check(not sim._e2_landing_legal(legal+Vector3(0.00001,0,0)),"hero landing bound is not relaxed to boat room bound")
 sim.obstacles = [{"position":Vector3(0.9,0,0),"half":Vector3(0.1,0,1)}]
 check(sim.request_action("e",Vector3(20,0,0)).get("accepted",false),"solid wall never rejects launch")
 if sim.ink_boat.is_empty(): sim.free(); return
 var state: Dictionary = sim.ink_boat
 sim.step(0.3)
 point_near(state.position,Vector3(0.9,0,0),"boat traverses into solid wall")
 rejected = sim.request_action("e",Vector3.INF)
 check(not rejected.get("accepted",false) and rejected.get("reason","") == "illegal_current_boat_landing","wall-interior exact landing rejected")
 check(is_same(state,sim.ink_boat) and sim.hero.position == Vector3.ZERO,"wall rejection preserves boat without projecting hero")
 sim.step(0.3)
 var boarded_at: Vector3 = state.position
 var accepted: Dictionary = sim.request_action("e",Vector3.INF)
 check(accepted.get("accepted",false),"same boat remains boardable after clearing wall")
 point_near(sim.hero.position,boarded_at,"successful board uses exact current position")
 check(sim.ink_e2_finished.size() == 1 and sim.cast_serial == 1,"boarding completes original root exactly once")
 near(sim.hero.cooldowns.e,15.4,"wall rejection and boarding never restart cooldown")
 observations["wall_boarding"] = {"rejected":rejected,"boarded_at":boarded_at,"finished":sim.ink_e2_finished.duplicate(true)}
 sim.free()

 groups.append("initial_front_and_exact_landing")

func parked_clock_damage_and_expiry() -> void:
 var sim = fresh()
 var blast_target: Dictionary = target(sim,Vector3(1.5,0,1.0))
 check(sim.request_action("e",Vector3(20,0,0)).get("accepted",false),"expiry fixture launches")
 if sim.ink_boat.is_empty(): sim.free(); return
 var state: Dictionary = sim.ink_boat
 sim.step(1.0)
 near(blast_target.hp,10000.0,"parking never triggers early natural burst")
 var entering: Dictionary = target(sim,Vector3(1.75,0,1.5))
 var before: Vector3 = entering.position
 entering.position = Vector3(1.75,0,0)
 sim._e2_enemy_motion(state,entering,before)
 near(entering.hp,9950.0,"original dynamic enemy-front contact survives parking")
 sim._e2_enemy_motion(state,entering,before)
 sim.step(0.2)
 near(entering.hp,9950.0,"parked sweeps cannot repeat outward damage on same target")
 var source_at: float = sim.hero_time
 var cooldown: float = sim.hero.cooldowns.e
 sim.paused = true; sim.step(5.0)
 near(sim.hero_time,source_at,"global pause freezes source clock while parked")
 near(sim.hero.cooldowns.e,cooldown,"global pause freezes running cooldown")
 check(not state.natural_burst_done and state.position == Vector3(2,0,0),"pause neither expires nor moves parked boat")
 sim.paused = false; sim.step(1.78)
 check(not sim.ink_boat.is_empty() and sim.ink_e2_finished.is_empty(),"original deadline remains open before three seconds")
 near(blast_target.hp,10000.0,"no parked periodic natural damage")
 sim.step(0.02)
 check(sim.ink_boat.is_empty() and sim.ink_e2_finished.size() == 1,"natural expiry settles once at original deadline")
 near(blast_target.hp,9925.0,"original 35+40%AP natural damage at parked point")
 near(entering.hp,9875.0,"original outward and natural ledger amounts are retained")
 near(sim.ink_e2_finished[0].finished_at,3.0,"original three-second deadline is authoritative")
 point_near(sim.ink_e2_finished[0].position,Vector3(2,0,0),"expiry uses actual parked endpoint")
 near(sim.hero.cooldowns.e,13.0,"natural expiry retains original launch cooldown")
 sim.step(0.2)
 check(sim.ink_e2_finished.size() == 1,"later steps cannot duplicate terminal settlement")
 observations["parked_expiry"] = {"finished":sim.ink_e2_finished.duplicate(true),"receipts":sim.ink_e2_receipts.duplicate(true)}
 sim.free()

 groups.append("parked_clock_damage_and_expiry")

func boundary_contact_pause_and_queued_input() -> void:
 # These tiny finite-fixture bodies stay completely inside the 2.015m room.
 # Their contacts fall inside the final partial motion interval (.66,.671667).
 var sim = fresh(2.015)
 var first: Dictionary = target(sim,Vector3(2.000,0,0.1),0.005)
 var second: Dictionary = target(sim,Vector3(2.010,0,-0.1),0.005)
 var trigger: Dictionary = {"count":0}
 sim.combat_event.connect(func(event: Dictionary):
  if event.kind == "damage" and event.get("source","") == "e2":
   trigger.count = int(trigger.count)+1
   if int(trigger.count) <= 2: sim.paused = true
 )
 var cast: Dictionary = sim.request_action("e",Vector3(20,0,0))
 check(cast.get("accepted",false),"partial-boundary pause fixture launches")
 if sim.ink_boat.is_empty(): sim.free(); return
 var state: Dictionary = sim.ink_boat
 sim.step(0.68)
 check(sim.paused and trigger.count == 1 and not sim._e2_pending_sweep.is_empty(),"first actual contact pauses final clipped sweep")
 if sim._e2_pending_sweep.is_empty(): sim.free(); return
 near(sim._e2_pending_sweep.end,2.015/3.0,"paused sweep stores true boundary arrival time")
 near(float(state.boundary_clock_target),0.68,"source interval target survives separately from spatial arrival")
 near(sim.ink_e2_receipts[0].source_time,1.995/3.0,"first contact time is not stretched to full tick")
 var frozen: Dictionary = {"time":sim.hero_time,"core":sim.ink_core_steps,"position":state.position,"cooldown":sim.hero.cooldowns.e}
 sim.step(1.0)
 check(sim.hero_time == frozen.time and sim.ink_core_steps == frozen.core and state.position == frozen.position and sim.hero.cooldowns.e == frozen.cooldown,"paused final sweep changes no admitted state")
 sim.paused = false
 var queued: Dictionary = sim.request_action("e",Vector3.INF,"boundary-owned-E")
 check(queued.get("accepted",false) and queued.get("queued",false),"same-frame E queues behind old boundary contacts")
 check(sim.request_action("e",Vector3.INF,"boundary-owned-E") == queued,"duplicate command keeps same queued receipt")
 check(not sim.request_action("e",Vector3.INF,"competing-boundary-E").get("accepted",false),"new E cannot replace original queued boat owner")
 sim.step(0.02)
 check(sim.paused and trigger.count == 2 and not sim.e2_board_input_report().pending.is_empty(),"second pause retains original queued E")
 near(sim.hero_time,frozen.time,"draining admitted second contact adds no source tick")
 check(sim.ink_core_steps == frozen.core,"draining admitted second contact adds no core tick")
 near(sim.ink_e2_receipts[1].source_time,2.005/3.0,"resumed contact retains actual arrival interpolation")
 sim.paused = false; sim.step(0.02)
 var report: Dictionary = sim.e2_board_input_report()
 check(report.pending.is_empty() and report.receipts.size() == 2,"queued E resolves exactly once after both old contacts")
 check(report.receipts.back().status == "rejected" and report.receipts.back().result.reason == "illegal_current_boat_landing","queued E validates true parked point without inward projection")
 check(int(report.receipts.back().cast_id) == int(cast.cast_id) and sim.cast_serial == 1 and is_same(state,sim.ink_boat),"queued rejection remains bound only to original boat")
 near(report.receipts.back().resolved_at,0.68,"queued E resolves after admitted clock interval before new step")
 point_near(state.position,Vector3(2.015,0,0),"resumed sweep reaches and stays at true edge")
 near(first.hp,9950.0,"first paused contact settles once")
 near(second.hp,9950.0,"second paused contact settles once")
 near(sim.hero.cooldowns.e,16.0-sim.hero_time,"pause-resume keeps original cooldown clock")
 observations["boundary_pause_queue"] = {"queue":report,"receipts":sim.ink_e2_receipts.duplicate(true),"boat":sim._e2_public(state)}
 sim.free()

 groups.append("boundary_contact_pause_and_queued_input")

func paused_terminal_and_scope() -> void:
 var sim = fresh()
 var first: Dictionary = target(sim,Vector3(1.5,0,1.0))
 var second: Dictionary = target(sim,Vector3(1.5,0,-1.0))
 var trigger: Dictionary = {"count":0}
 sim.combat_event.connect(func(event: Dictionary):
  if event.kind == "damage" and event.get("source","") == "e2":
   trigger.count = int(trigger.count)+1
   if trigger.count == 1: sim.paused = true
 )
 check(sim.request_action("e",Vector3(20,0,0)).get("accepted",false),"terminal pause fixture launches")
 sim.step(3.0)
 check(sim.paused and trigger.count == 1 and sim.ink_e2_finished.is_empty(),"parked natural expiry defers completion through callback pause")
 sim.paused = false; sim.step(0.02)
 near(first.hp,9925.0,"parked natural first packet settles once")
 near(second.hp,9925.0,"parked natural second packet resumes once")
 check(sim.ink_e2_finished.size() == 1 and trigger.count == 2,"parked natural terminal finishes only after final packet")
 observations["terminal_pause"] = sim.ink_e2_finished.duplicate(true)
 sim.free()
 for hex_id: String in ["yanguizhou_h09","yanguizhou_h10"]:
  sim = fresh(); sim.set_hexes([hex_id])
  var refused: Dictionary = sim.request_action("e",Vector3(20,0,0))
  check(not refused.get("accepted",false) and refused.get("reason","") == "base_E2_candidate_has_no_H09_H10","personal Hex remains explicitly locked: "+hex_id)
  check(sim.ink_boat.is_empty() and sim.cast_serial == 0,"unsupported Hex creates no root: "+hex_id)
  sim.free()

 groups.append("paused_terminal_and_scope")

func run() -> void:
 edges_and_corner()
 initial_front_and_exact_landing()
 parked_clock_damage_and_expiry()
 boundary_contact_pause_and_queued_input()
 paused_terminal_and_scope()
 for group: String in REQUIRED_GROUPS:
  check(groups.count(group) == 1,"required finite group completed once: "+group)
 if output_path.is_empty(): failures.append("explicit fresh --boundary-result= path required")
 elif FileAccess.file_exists(output_path): failures.append("refuse existing finite result")
 var output: FileAccess = null
 if not output_path.is_empty() and not FileAccess.file_exists(output_path):
  output = FileAccess.open(output_path,FileAccess.WRITE)
  if output == null: failures.append("cannot create finite output")
 var report: Dictionary = {"schema":"ink-e2-boundary-candidate01-finite-1","passed":failures.is_empty(),"checks":checks,"failures":failures,"groups":groups,"required_groups":REQUIRED_GROUPS,"observations":observations,"source_binding_sha256":FileAccess.get_sha256("res://tests/ink_e2_boundary_20261006/candidate01/source_binding.json"),"ordinary_E2_enabled":false,"H09_H10_enabled":false,"runtime_scope":"independent affected base E2 cases only","not_accepted":["current_P1_R1_E1_composition","ordinary_host","native_input","art_audio","full_regression"]}
 if output != null:
  output.store_string(JSON.stringify(report,"  ")); output.close()
 print("INK_E2_BOUNDARY_FINITE ",JSON.stringify(report))
 quit(0 if failures.is_empty() else 1)
