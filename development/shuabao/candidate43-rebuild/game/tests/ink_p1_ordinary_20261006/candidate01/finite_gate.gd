extends SceneTree
## Explicit mechanism fixtures. Direct ranks, targets, HP and overlap-CD setup
## below are TEST ONLY, never ordinary progression, native or art acceptance.
const Sim = preload("res://tests/ink_p1_ordinary_20261006/candidate01/sim.gd")
const Previous = preload("res://tests/ink_r1_ordinary_20261005/candidate01/sim.gd")
const Collector = preload("res://tests/ink_p1_settlement_20261005/candidate03/p1_collector.gd")
const Geometry = preload("res://tests/ink_q1_foundation_20261004/revision02/scripts/ink_geometry.gd")
const REQUIRED: Array = ["current_chain_and_ranks","q1_endpoint_and_h02","q2_marker_and_lifetime","q2_distinct_targets_and_roots","q2_pause_and_resume","q2_scope_and_callbacks","actual_identity_and_once","q3_e1_r1_composition","ordinary_baseline_and_common"]
var sim_script: GDScript = Sim
var previous_script: GDScript = Previous
var checks: int = 0
var failures: Array[String] = []
var completed: Array[String] = []
var observations: Dictionary = {}
var serial: int = 0
var output_path: String = "user://ink_p1_current_core_finite.json"

func _initialize() -> void:
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--p1-result="): output_path = arg.trim_prefix("--p1-result=")
 run.call_deferred()
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok: failures.append(label); push_error(label)
func near(a: float, b: float, label: String) -> void:
 check(is_finite(a) and is_finite(b) and absf(a-b) < .0001, "%s %.8f expected %.8f" % [label,a,b])
func fresh(family: String = "q2", rank: int = 1, baseline: bool = false, hexes: Array = []):
 serial += 1
 var sim = Previous.new() if baseline else Sim.new()
 root.add_child(sim); sim.auto_finish = false; sim.ai_enabled = false; sim.arena_half_extent = 100.0; sim.obstacles = []
 sim.hero.position = Vector3.ZERO; sim.hero.loadout.q = family if family.begins_with("q") else "q3"
 sim.hero.loadout.e = "e1"; sim.hero.loadout.r = "r1"; sim.hero.ranks.q = 1; sim.hero.ranks.e = 1; sim.hero.ranks.r = 1
 sim.hero.loadout.passive = "p1"; sim.hero.ranks.passive = rank
 sim.hero.stats.ap = 100.0; sim.hero.stats.crit_chance = 0.0; sim.hero.stats.regen = 0.0; sim.hero.stats.lifesteal = 0.0; sim.hero.stats.cdr = 0.0
 check(sim.begin_encounter("p1-explicit-current-fixture-%d" % serial, []).accepted,"explicit fixture encounter accepted")
 sim.set_hexes(hexes)
 return sim
func target(sim, at: Vector3, hp: float = 10000.0) -> Dictionary:
 var enemy: Dictionary = sim.spawn_enemy("minion",at,hp)
 enemy.state = "chase"; enemy.defence = 0.0; enemy.radius = .25
 return enemy
func events(sim, kind: String) -> Array: return sim.event_log.filter(func(e): return e.kind == kind)
func damage(sim, source: String) -> Array: return events(sim,"damage").filter(func(e): return e.get("source","") == source)
func supplements(sim) -> Array: return events(sim,"damage").filter(func(e): return bool(e.get("p1_supplement",false)))
func receipt(sim, id: int = -1) -> Dictionary:
 var found: Array = sim.ink_p1_receipts.filter(func(item): return id < 0 or int(item.cast_id) == id)
 check(found.size() == 1,"one exact root P1 receipt before field assertions")
 return found[0] if found.size() == 1 else {"cast_id":-1,"final_basis":-1.0,"actual_supplement":-1.0,"cooldown_before":-1.0,"cooldown_after":-1.0,"cooldown_refund":-1.0,"distinct_targets":-1,"qualified":false,"ordinary_packet_count":-1,"target_status":"missing","settled_at":-1.0,"passive_rank":-1,"supplement_killed":false}
func river(sim, x: float = 2.0) -> Dictionary:
 var first: Dictionary = sim.request_q2("first",Vector3(x,0,-3))
 check(first.accepted,"real Q2 first point accepted")
 var second: Dictionary = sim.request_q2("second",Vector3(x,0,3))
 check(second.accepted,"real Q2 second point accepted")
 var states: Array = sim.ink_rivers.filter(func(state): return str(state.river_id) == str(second.get("river_id","")))
 check(states.size() == 1,"one exact input-created river")
 return states[0] if states.size() == 1 else {}
func expire(sim, state: Dictionary) -> void:
 if state.is_empty(): check(false,"river fixture missing before expiry"); return
 sim.step(maxf(.02,float(state.expires_at)-sim.hero_time+.025))
func q1(sim, points: Array) -> Dictionary:
 check(sim.request_ink_input("q_down").accepted,"Q1 real arm")
 check(sim.request_ink_input("left_down",points[0]).accepted,"Q1 mouse down")
 for point in points.slice(1): check(sim.request_ink_input("motion",point).accepted,"Q1 held motion")
 var out: Dictionary = sim.request_ink_input("left_up",points.back())
 check(out.accepted,"Q1 real mouse up accepted"); return out
func q3(sim) -> void:
 check(sim.request_action("q",Vector3(2,0,0)).accepted,"Q3 raise accepted")
 check(sim.request_action("q",Vector3(10,0,0)).accepted,"Q3 collapse accepted")
func rain(sim) -> void:
 check(sim.request_action("e").accepted,"E1 entry accepted")
 sim.hero.move_intent = Vector3.RIGHT; sim.step(.1); sim.hero.move_intent = Vector3.ZERO
 check(sim.request_action("e_release").accepted,"E1 reform accepted")
func run() -> void:
 current_chain_and_ranks(); q1_endpoint_and_h02(); q2_marker_and_lifetime(); q2_distinct_targets_and_roots(); q2_pause_and_resume(); q2_scope_and_callbacks(); actual_identity_and_once(); q3_e1_r1_composition(); ordinary_baseline_and_common()
 for group in REQUIRED: check(group in completed,"required group " + group)
 var report: Dictionary = {"suite":"ink_p1_current_core_candidate01","passed":failures.is_empty(),"checks":checks,"completed":completed,"failures":failures,"observations":observations,"source_binding_sha256":FileAccess.get_sha256("res://tests/ink_p1_ordinary_20261006/candidate01/source_binding.json"),"scope":"explicit four-family mechanics fixtures on frozen current R1/E1/Q2/Q3 chain","production_promotion":false,"unpassed":["ordinary_P1_learning_UI_session","natural_progression","native_input","art_audio","full_floor_Boss","H03_H04_P1","E2_E3_R2","supplement_lifesteal","enemy_shields"]}
 var file = FileAccess.open(output_path,FileAccess.WRITE)
 if file == null: push_error("Cannot write P1 finite result"); quit(2); return
 file.store_string(JSON.stringify(report,"  ")); file.close()
 print("INK_P1_CURRENT_CORE_REPORT ",JSON.stringify(report)); quit(0 if failures.is_empty() else 1)

func current_chain_and_ranks() -> void:
 var parent: GDScript = sim_script.get_base_script()
 var grandparent: GDScript = parent.get_base_script()
 check(grandparent == previous_script,"new settlement directly retains exact current R1 resource")
 var bonuses: Array = [.12,.18,.30,.48]; var refunds: Array = [.05,.08,.14,.23]
 for rank in range(1,5):
  var sim = fresh("q3",rank); var enemy: Dictionary = target(sim,Vector3(2,0,0))
  var director_script: GDScript = sim.enemy_director.get_script()
  check(director_script.resource_path == "res://tests/ink_r1_ordinary_20261005/candidate01/enemy_director.gd","constructor retains current R1 navigation director")
  q3(sim); var item: Dictionary = receipt(sim)
  near(item.final_basis,245,"Q3 original two-channel basis rank%d" % rank)
  near(enemy.hp,10000-245*(1+float(bonuses[rank-1])),"original P1 final bonus rank%d" % rank)
  near(item.cooldown_after,item.cooldown_before*(1-float(refunds[rank-1])),"original current-CD refund rank%d" % rank)
  check(item.passive_rank == rank,"root snapshots explicit passive rank")
  sim.free()
 completed.append("current_chain_and_ranks")

func q1_endpoint_and_h02() -> void:
 for count in [1,2]:
  var sim = fresh("q1"); target(sim,Vector3(.51,0,.2 if count == 2 else 0))
  if count == 2: target(sim,Vector3(.51,0,-.2))
  var outside: Dictionary = target(sim,Vector3(.52,0,0))
  q1(sim,[Vector3.ZERO,Vector3(.26,0,0)]); sim.step(.02)
  check(damage(sim,"q1").size() == count,"exact endpoint batch includes all legal contacts")
  var item: Dictionary = receipt(sim)
  check(item.distinct_targets == count and bool(item.qualified) == (count == 1),"same-time endpoint whole-root target set")
  check(supplements(sim).size() == (1 if count == 1 else 0),"no payout between same-time endpoint contacts")
  near(outside.hp,10000,"unchanged exact outside control")
  if not sim.ink_receipts.is_empty() and not sim.ink_finished.is_empty():
   var bits: String = PackedFloat64Array([float(sim.ink_finished[0].finished_at)]).to_byte_array().hex_encode()
   for contact in sim.ink_receipts: check(PackedFloat64Array([float(contact.contact_time)]).to_byte_array().hex_encode() == bits,"canonical endpoint time bit-for-bit")
  sim.free()
 var sim = fresh("q1",1,false,["yanguizhou_h01","yanguizhou_h02"])
 target(sim,Vector3(1,0,0)); var pulled: Dictionary = target(sim,Vector3(4,0,4.2))
 q1(sim,[Vector3.ZERO,Vector3(2,0,0),Vector3(2,0,2),Vector3(4,0,2)]); sim.step(.3)
 check(receipt(sim).distinct_targets == 1 and sim.ink_vortices.size() == 1,"H01 one wave settles before H02 pure-pull expiry")
 check(pulled.position.z < 4.2,"retained H02 real pull runs")
 near(pulled.hp,10000,"pure pull contributes no extra Q1 hit")
 sim.free()
 sim = fresh("q1"); target(sim,Vector3(.51,0,.2)); target(sim,Vector3(.51,0,-.2))
 var pause_probe: Dictionary = {"done":false,"second_hero_time":-1.0,"second_core_steps":-1}
 sim.combat_event.connect(func(event: Dictionary):
  if event.kind == "damage" and event.get("source","") == "q1" and not pause_probe.done:
   pause_probe.done = true; sim.paused = true
  elif event.kind == "damage" and event.get("source","") == "q1":
   pause_probe.second_hero_time = sim.hero_time; pause_probe.second_core_steps = sim.ink_core_steps
 )
 q1(sim,[Vector3.ZERO,Vector3(.26,0,0)]); sim.step(.02)
 check(pause_probe.done and damage(sim,"q1").size() == 1,"first exact endpoint Q1 callback actually pauses")
 check(not sim.ink_waves.is_empty() and sim.ink_p1_receipts.is_empty(),"paused Q1 retains unfinished wave and cannot truncate target union")
 check(sim.ink_rivers.is_empty() and sim._q2_enemy_hits.is_empty(),"Q1 resumable dispatch uses no fabricated river or hostile-hit placeholder")
 check(not sim._q2_motion_resume.is_empty() and sim._q2_resume_from == -1.0,"real pause stores remainder after consuming fresh interval cursor")
 var paused_time: float = sim.hero_time; var paused_core_steps: int = sim.ink_core_steps
 near(paused_time,.02,"pause happens after exactly the admitted source step")
 check(paused_core_steps == 1,"one source core step before pause")
 if not sim._q2_motion_resume.is_empty():
  near(sim._q2_motion_resume.start,0.0,"saved original interval start")
  near(sim._q2_motion_resume.end,.02,"saved original interval end")
  near(sim._q2_motion_resume.cursor,.26/24.0,"saved cursor is actual terminal-contact source time")
 sim.step(.5)
 near(sim.hero_time,paused_time,"paused public step cannot advance source time")
 check(sim.ink_core_steps == paused_core_steps,"paused public step cannot execute core")
 sim.paused = false; sim.step(.02)
 check(damage(sim,"q1").size() == 2,"resumed Q1 applies the second original endpoint contact")
 check(receipt(sim).distinct_targets == 2 and supplements(sim).is_empty(),"Q1 pause cannot fabricate single-target P1")
 near(pause_probe.second_hero_time,paused_time,"resumed second contact completes old interval before new hero-time step")
 check(pause_probe.second_core_steps == paused_core_steps,"resumed second contact runs before any new core step")
 near(sim.hero_time,.04,"resume adds only the requested next fixed step")
 check(sim.ink_core_steps == 2,"two public active steps execute exactly two core steps total")
 check(sim._q2_motion_resume.is_empty() and sim._q2_resume_from == -1.0,"completed continuation clears both saved remainder and cursor")
 var resumed_contacts: Array = sim.ink_receipts.filter(func(item): return item.source == "q1")
 check(resumed_contacts.size() == 2,"both original contact receipts retained")
 if resumed_contacts.size() == 2 and sim.ink_finished.size() == 1:
  var end_bits: String = PackedFloat64Array([float(sim.ink_finished[0].finished_at)]).to_byte_array().hex_encode()
  for contact in resumed_contacts: check(PackedFloat64Array([float(contact.contact_time)]).to_byte_array().hex_encode() == end_bits,"pause-resumed endpoint contact retains exact original terminal timestamp")
 observations["q1_pause_resume"] = {"second_contact_hero_time":pause_probe.second_hero_time,"second_contact_core_steps":pause_probe.second_core_steps,"final_hero_time":sim.hero_time,"final_core_steps":sim.ink_core_steps,"contact_count":resumed_contacts.size(),"remainder_cleared":sim._q2_motion_resume.is_empty()}
 observations["q1_endpoint"] = "Known exact endpoint bug correction intentionally also active with P1 unlearned; baseline equality excludes that bugcase"
 sim.free(); completed.append("q1_endpoint_and_h02")

func q2_marker_and_lifetime() -> void:
 var sim = fresh()
 check(sim.q2_preview(Vector3(2,0,-3)).accepted and sim.p1.roots.is_empty(),"Q2 preview creates no collector")
 check(sim.request_q2("first",Vector3(2,0,-3)).accepted,"Q2 marker-only fixture accepted")
 var id: int = int(sim.ink_q2_pending.cast_id)
 check(sim.p1.roots.has(id) and sim._p1_q2_rivers.is_empty(),"marker root is not an active damage river")
 near(sim.hero.cooldowns.q,0,"first marker starts no CD")
 sim.step(5.1)
 check(sim.ink_q2_pending.is_empty() and not sim.p1.roots.has(id),"marker timeout discards unpaid collector")
 check(sim.ink_p1_receipts.is_empty() and supplements(sim).is_empty(),"marker timeout never refunds or supplements")
 check(sim.hero.cooldowns.q > 10.0,"original timeout CD remains")
 sim.free()
 for rank in range(1,5):
  sim = fresh("q2",rank); var enemy: Dictionary = target(sim,Vector3(2,0,0)); var state: Dictionary = river(sim)
  if state.is_empty(): sim.free(); continue
  near(enemy.hp,9850,"real birth-overlap ordinary damage immediate")
  check(is_same(sim._p1_q2_rivers.get(state.cast_id,{}),state),"collector binds exact input-created river object")
  sim.finish_cast(state.cast_id); sim.step(.25)
  check(sim.ink_p1_receipts.is_empty(),"generic finish cannot end live river damage lifetime")
  near(enemy.hp,9850,"standing target hit once per river")
  expire(sim,state); var item: Dictionary = receipt(sim,int(state.cast_id))
  near(item.final_basis,150,"Q2 base accepted amount collected once")
  near(item.actual_supplement,150*sim.v("P1-1",rank)*.01,"Q2 four-rank bonus from original table")
  near(item.cooldown_after,item.cooldown_before*(1-sim.v("P1-2",rank)*.01),"Q2 refund uses lifetime-end remaining cooldown")
  sim._q2_finish(state,"expired",state.expires_at); sim.finish_cast(state.cast_id)
  check(sim.ink_p1_receipts.size() == 1 and supplements(sim).size() == 1,"duplicate river expiry cannot pay again")
  sim.free()
 completed.append("q2_marker_and_lifetime")

func q2_distinct_targets_and_roots() -> void:
 var sim = fresh(); target(sim,Vector3(2,0,0)); var state: Dictionary = river(sim)
 sim.step(3.5); var late: Dictionary = target(sim,Vector3(-3,0,1))
 sim.push_enemy(late,Vector3.RIGHT,7.0,"fixture_motion",0,0.0,.25,0.0); sim.step(.3)
 check(damage(sim,"q2").size() == 2,"late real push crosses original live river")
 expire(sim,state)
 check(receipt(sim).distinct_targets == 2 and supplements(sim).is_empty(),"late second enemy defeats whole-river single target")
 sim.free()
 sim = fresh(); target(sim,Vector3(2,0,0)); var first: Dictionary = river(sim)
 sim.step(.5); sim.hero.cooldowns.q = 0.0 # EXPLICIT TEST ONLY: simultaneous roots without ordinary rewards/reset.
 var second: Dictionary = river(sim)
 check(not first.is_empty() and not second.is_empty() and first.cast_id != second.cast_id,"two explicit overlapping rivers own different roots")
 check(damage(sim,"q2").size() == 2,"same enemy gets one original hit from each river")
 expire(sim,first)
 check(sim.ink_p1_receipts.size() == 1,"first expiry cannot settle second live river")
 near(receipt(sim,int(first.cast_id)).final_basis,150,"first root does not absorb second river packet")
 expire(sim,second)
 near(receipt(sim,int(second.cast_id)).final_basis,150,"second root retains its own packet")
 check(sim.ink_p1_receipts.size() == 2 and supplements(sim).size() == 2,"one settlement for each complete river")
 observations["two_rivers"] = sim.ink_p1_receipts.duplicate(true)
 sim.free(); completed.append("q2_distinct_targets_and_roots")

func q2_pause_and_resume() -> void:
 var sim = fresh(); target(sim,Vector3(2,0,-.5)); target(sim,Vector3(2,0,.5)); var armed: Dictionary = {"done":false}
 sim.combat_event.connect(func(event: Dictionary):
  if event.kind == "damage" and event.get("source","") == "q2" and not armed.done:
   armed.done = true; sim.paused = true
 )
 var state: Dictionary = river(sim)
 check(armed.done and sim.paused and sim._q2_deferred_contacts.size() == 1,"pause callback retains second exact birth contact")
 check(damage(sim,"q2").size() == 1 and sim.ink_p1_receipts.is_empty(),"paused partial batch cannot qualify")
 var clock_before: float = sim.hero_time; sim.step(.5); near(sim.hero_time,clock_before,"paused clock frozen")
 sim.paused = false; sim.step(.02)
 check(damage(sim,"q2").size() == 2 and sim._q2_deferred_contacts.is_empty(),"resume applies original deferred second contact once")
 expire(sim,state)
 check(receipt(sim).distinct_targets == 2 and supplements(sim).is_empty(),"deferred second target stays in original root union")
 sim.free()
 sim = fresh(); target(sim,Vector3(2,0,0)); armed = {"done":false,"paid_inside":-1}
 sim.combat_event.connect(func(event: Dictionary):
  if event.kind == "ink_q2_finished" and not armed.done:
   armed.done = true; sim.paused = true; sim.finish_cast(event.cast_id); armed.paid_inside = supplements(sim).size()
 )
 state = river(sim); expire(sim,state)
 check(armed.done and armed.paid_inside == 0 and sim.ink_p1_receipts.is_empty(),"terminal pause defers payment through event and batch barriers")
 sim.paused = false; sim.step(.02)
 var item: Dictionary = receipt(sim)
 near(item.cooldown_refund,item.cooldown_before*.05,"resumed payment reads then-current CD")
 check(supplements(sim).size() == 1,"resume settles once")
 sim.free(); completed.append("q2_pause_and_resume")

func q2_scope_and_callbacks() -> void:
 for mode in ["cancel","room","death"]:
  var sim = fresh(); target(sim,Vector3(2,0,0)); var probe: Dictionary = {"seen":false,"inside":-1}
  sim.combat_event.connect(func(event: Dictionary):
   if event.kind == "ink_q2_finished" and not probe.seen:
    probe.seen = true; sim.finish_cast(event.cast_id); probe.inside = supplements(sim).size()
    if mode == "cancel": sim.cancel_cast(event.cast_id)
    elif mode == "room": sim.end_encounter("fixture_boundary"); sim.begin_encounter("new-fixture-room",[])
    else: sim.damage_hero(100000.0,Vector3.ZERO,0.0,true,true)
  )
  var state: Dictionary = river(sim); expire(sim,state)
  check(probe.seen and probe.inside == 0,"real terminal callback stays unpaid before " + mode)
  check(sim.ink_p1_receipts.is_empty() and supplements(sim).is_empty(),"terminal " + mode + " discards pending P1")
  check(sim._p1_q2_rivers.is_empty() and sim._p1_q2_terminal_frames.is_empty(),"terminal " + mode + " cannot leak old river ownership")
  sim.free()
 var sim = fresh(); target(sim,Vector3(2,0,0)); var state: Dictionary = river(sim)
 sim.cancel_cast(state.cast_id); sim.step(5.0)
 check(not sim.p1.roots.has(state.cast_id) and sim.ink_p1_receipts.is_empty(),"midriver cancellation never pays later")
 sim.free(); completed.append("q2_scope_and_callbacks")

func actual_identity_and_once() -> void:
 var sim = fresh(); var enemy: Dictionary = target(sim,Vector3(2,0,0)); enemy.defence = 100.0
 var probe: Dictionary = {"seen":false}
 sim.combat_event.connect(func(event: Dictionary):
  if event.kind == "damage" and event.get("source","") == "q2" and not probe.seen:
   probe.seen = true; enemy.hp += 17.0; sim.damage_enemy(enemy,7.0,"fixture_unrelated",event.cast_id)
 )
 var state: Dictionary = river(sim); expire(sim,state)
 var item: Dictionary = receipt(sim)
 near(item.final_basis,75.0,"Q2 basis is committed post-defence event before healing callback")
 near(item.actual_supplement,9.0,"supplement does not reapply defence or nested damage")
 sim.free()
 sim = fresh(); enemy = target(sim,Vector3(2,0,0)); state = river(sim)
 var old_id: String = enemy.actor_id; sim.enemies.erase(enemy)
 var replacement: Dictionary = target(sim,Vector3(20,0,20)); replacement.actor_id = old_id
 expire(sim,state); check(receipt(sim).target_status == "original_missing_or_replaced","same-ID replacement not original river target")
 near(replacement.hp,10000,"replacement cannot inherit supplement")
 sim.free()
 sim = fresh(); enemy = target(sim,Vector3(2,0,0),160.0); state = river(sim)
 check(not enemy.dead and enemy.hp == 10.0 and supplements(sim).is_empty(),"ordinary river hit cannot receive early bonus kill")
 expire(sim,state); check(enemy.dead and events(sim,"kill").size() == 1,"one supplemental lethal only after river end")
 near(receipt(sim).actual_supplement,10.0,"supplement capped to remaining HP")
 sim.free()
 var collector = Collector.new(); var owner = RefCounted.new(); collector.begin({"cast_id":1},owner,1,.12,.05)
 var original: Dictionary = {"actor_id":"same"}; var other: Dictionary = {"actor_id":"same"}
 collector.capture(1,1,original,0.0); collector.capture(1,1,original,50.0); collector.capture(1,2,other,0.0)
 check(collector.roots[1].targets.size() == 2,"accepted zero-amount packets and same-ID distinct objects retain identity")
 collector.enter(1); collector.complete(1); check(not collector.ready(1),"collector waits full batch")
 collector.leave(1); check(not collector.take(1).is_empty() and collector.take(1).is_empty(),"collector claim is idempotent")
 sim = fresh("q3"); enemy = target(sim,Vector3(2,0,0)); var context: Dictionary = sim.new_cast("q","explicit_zero_cd_collector_fixture")
 sim.damage_enemy(enemy,50.0,"q3",context.cast_id); sim.hero.cooldowns.q = 0.0
 sim.p1.complete(context.cast_id); sim.finish_cast(context.cast_id)
 near(receipt(sim).cooldown_refund,0.0,"zero remaining CD has no deferred credit")
 sim.hero.cooldowns.q = 10.0; sim.finish_cast(context.cast_id); near(sim.hero.cooldowns.q,10.0,"later cooldown cannot receive old refund")
 sim.free(); completed.append("actual_identity_and_once")

func q3_e1_r1_composition() -> void:
 var sim = fresh("q3"); target(sim,Vector3(2,0,0)); sim.request_action("q",Vector3(2,0,0))
 target(sim,Vector3(5,0,0)); sim.request_action("q",Vector3(10,0,0))
 check(receipt(sim).distinct_targets == 2 and supplements(sim).is_empty(),"current Q3 late collapse target prevents P1")
 sim.free()
 sim = fresh("e1"); var enemy: Dictionary = target(sim,Vector3(.5,0,0)); rain(sim)
 var item: Dictionary = receipt(sim)
 near(item.final_basis,145.0,"current corrected E1 retains base plus marked channel")
 check(item.ordinary_packet_count == 2 and item.distinct_targets == 1,"current E1 completes both channels before P1")
 near(enemy.hp,10000.0-145.0*1.12,"current E1 one final supplement")
 sim.free()
 sim = fresh(); enemy = target(sim,Vector3(2,0,0)); check(sim.request_action("r",Vector3.ZERO).accepted,"retained R1 real cast accepted")
 check(sim.p1.roots.is_empty() and sim.ink_snow.size() > 0,"R1 excluded from original Q/E passive scope")
 var state: Dictionary = river(sim); sim.step(.1)
 check(sim.r1_enemy_rates(enemy).in_domain,"current R1 rates survive concurrent river/P1")
 expire(sim,state); check(receipt(sim).qualified,"Q2 P1 works while original R1 field active")
 check(damage(sim,"r1").is_empty(),"R1 still deals no damage")
 sim.free(); completed.append("q3_e1_r1_composition")

func ordinary_baseline_and_common() -> void:
 for family in ["q1","q2","q3","e1"]:
  var sim = fresh(family,0); var before = fresh(family,0,true)
  var a: Dictionary = target(sim,Vector3(2,0,0)); var b: Dictionary = target(before,Vector3(2,0,0))
  if family == "q1": q1(sim,[Vector3.ZERO,Vector3(4,0,0)]); q1(before,[Vector3.ZERO,Vector3(4,0,0)]); sim.step(.3); before.step(.3)
  elif family == "q2": var state: Dictionary = river(sim); var previous_state: Dictionary = river(before); expire(sim,state); expire(before,previous_state)
  elif family == "q3": q3(sim); q3(before)
  else: rain(sim); rain(before)
  near(a.hp,b.hp,"general unlearned-P1 inherited damage equality " + family)
  near(sim.hero.cooldowns.q,before.hero.cooldowns.q,"general unlearned-P1 Q cooldown equality " + family)
  near(sim.hero.cooldowns.e,before.hero.cooldowns.e,"general unlearned-P1 E cooldown equality " + family)
  near(sim.hero_time,before.hero_time,"single shared inherited hero clock " + family)
  check(sim.p1.roots.is_empty() and sim.ink_p1_receipts.is_empty(),"unlearned P1 creates no collector " + family)
  sim.free(); before.free()
 var hexes: Array = ["common_g01","common_g05","common_g06","common_g15","common_g24","common_g30"]
 var sim = fresh("e1",1,false,hexes); var before = fresh("e1",0,true,hexes)
 target(sim,Vector3(.5,0,0)); target(before,Vector3(.5,0,0)); rain(sim); rain(before)
 var a: Array = damage(sim,"e1"); var b: Array = damage(before,"e1")
 check(a.size() == 2 and b.size() == 2,"six retained common hooks preserve two original E1 packets")
 if a.size() == b.size():
  for index in range(a.size()): near(a[index].amount,b[index].amount,"common ordinary packet unchanged %d" % index)
 check(supplements(sim).size() == 1,"common composition adds only one final correction")
 sim.free(); before.free(); completed.append("ordinary_baseline_and_common")
