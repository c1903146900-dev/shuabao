extends SceneTree
## Four finite groups. Actual engine execution is owned by the coordinator.
const Sim = preload("res://tests/ink_river_hexes_20261006/candidate01/sim.gd")
const Router = preload("res://tests/ink_river_hexes_20261006/candidate01/input_adapter.gd")
const REQUIRED_GROUPS = ["h03_physical_scope", "h04_source_ticks", "h04_discontinuous_atomic_samples", "composition_retirement"]
var checks: int = 0
var failures: Array[String] = []
var completed: Array[String] = []
var observations: Dictionary = {}
var output_path: String = ""
var serial: int = 0

func _initialize() -> void:
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--river-hex-result="): output_path = arg.trim_prefix("--river-hex-result=")
 run.call_deferred()

func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok: failures.append(label); push_error(label)

func near(a: float, b: float, label: String) -> void:
 check(is_finite(a) and absf(a-b)<0.0001,label+" actual="+str(a)+" expected="+str(b))

func fresh(ids: Array = ["yanguizhou_h03","yanguizhou_h04"]):
 serial += 1
 var sim = Sim.new(); root.add_child(sim)
 sim.auto_finish=false; sim.ai_enabled=false; sim.obstacles=[]; sim.arena_half_extent=30.0
 sim.hero.loadout.q="q2"; sim.hero.ranks.q=1
 sim.hero.loadout.e="e3"; sim.hero.ranks.e=1
 sim.hero.loadout.r="r2"; sim.hero.ranks.r=1
 sim.hero.loadout.passive="p1"; sim.hero.ranks.passive=0
 sim.set_projected_stats({"AP":100.0,"move_speed":10.0,"defence":0.0,"crit_chance":0.0,"regen":0.0,"lifesteal":0.0,"cdr":0.0})
 check(sim.begin_encounter("river-hex-source-fixture-%d"%serial,[]).accepted,"fresh exact-current-parent encounter")
 sim.set_hexes(ids); sim.hero.position=Vector3.ZERO
 return sim

func enemy(sim, position: Vector3) -> Dictionary:
 var target: Dictionary = sim.spawn_enemy("minion",position,100000.0)
 target.state="chase"; target.defence=0; target.radius=0.1
 return target

func river(sim) -> Dictionary:
 check(sim.request_q2("first",Vector3(0,0,-4)).accepted,"real Q2 A")
 near(sim.hero.cooldowns.q,0.0,"A does not start CD")
 check(sim.request_q2("second",Vector3.ZERO).accepted,"real Q2 B")
 check(sim.ink_rivers.size()==1,"one river root")
 return sim.ink_rivers[0]

func sunset(sim) -> Array:
 return sim.ink_q2_receipts.filter(func(hit): return hit.kind=="sunset")

func key(code: int, down: bool = true) -> InputEventKey:
 var event:=InputEventKey.new(); event.physical_keycode=code; event.pressed=down; return event

func mouse(down: bool = true, corner: bool = false) -> InputEventMouseButton:
 var event:=InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=down; event.ctrl_pressed=corner; return event

func done_group(name: String) -> void:
 completed.append(name); print("INK_RIVER_HEX_GROUP ",name)

func h03_physical_scope() -> void:
 var sim=fresh(); var input=Router.new(); input.bind(sim)
 check(input.handle_event(key(KEY_Q),Vector3(0,0,-4)).accepted,"Q arms A")
 check(input.handle_event(mouse(),Vector3(0,0,-4)).accepted,"fresh click commits A")
 input.handle_event(mouse(false)); input.handle_event(key(KEY_Q,false))
 check(input.handle_event(key(KEY_Q),Vector3.ZERO).accepted,"new Q arms B")
 var cast_id: int=int(sim.ink_q2_pending.cast_id)
 var expires: float=float(sim.ink_q2_pending.expires_at)
 check(input.handle_event(mouse(true,true),Vector3(2,0,-3)).accepted,"Ctrl click adds first H03 corner")
 check(not input.handle_event(mouse(true,true),Vector3(2,0,-2)).accepted,"held duplicate cannot add a corner")
 check(sim.ink_q2_pending.path.size()==2 and not input.q2_aim.is_empty(),"same B preview owns committed first corner")
 input.handle_event(mouse(false,true))
 check(input.handle_event(mouse(true,true),Vector3(2,0,-1)).accepted,"second fresh Ctrl click adds second corner")
 input.handle_event(mouse(false,true))
 var rejected: Dictionary=input.handle_event(mouse(true,true),Vector3(1,0,-1))
 check(not rejected.accepted and rejected.reason=="corner_limit","third corner rejects without becoming B")
 near(sim.ink_q2_pending.expires_at,expires,"corners never refresh original window")
 near(sim.hero.cooldowns.q,0.0,"corners never start CD")
 check(int(sim.ink_q2_pending.cast_id)==cast_id and sim.ink_rivers.is_empty(),"corners retain single incomplete root")
 input.handle_event(mouse(false,true))
 check(input.handle_event(mouse(),Vector3.ZERO).accepted,"unmodified fresh click commits B")
 check(sim.ink_rivers[0].path.size()==4 and int(sim.ink_rivers[0].cast_id)==cast_id,"three legs share one river and root")
 near(sim.hero.cooldowns.q,10.5,"legal B starts original CD once")
 check(not input.handle_event(mouse(),Vector3.ZERO).accepted,"held B duplicate cannot shoot")
 input.handle_event(mouse(false)); check(sim.ink_basics.is_empty(),"matching up never creates BASIC")
 sim.combat_event.disconnect(input._source_event); input=null; sim.free()
 sim=fresh([]); input=Router.new(); input.bind(sim)
 input.handle_event(key(KEY_Q),Vector3(0,0,-4)); input.handle_event(mouse(),Vector3(0,0,-4)); input.handle_event(mouse(false))
 input.handle_event(key(KEY_Q,false)); input.handle_event(key(KEY_Q),Vector3.ZERO)
 rejected=input.handle_event(mouse(true,true),Vector3(2,0,-2))
 check(not rejected.accepted and rejected.reason=="requires_H03","Ctrl does not grant missing H03")
 input.handle_event(mouse(false,true)); input.suspend_input("focus_lost")
 check(sim.ink_q2_pending.path.size()==1 and input.q2_aim.is_empty(),"focus clears preview but preserves source marker")
 sim.step(5.0)
 check(sim.ink_q2_pending.is_empty(),"source deadline removes marker")
 near(sim.hero.cooldowns.q,10.5,"timeout starts CD after marker retirement")
 sim.combat_event.disconnect(input._source_event); input=null; sim.free(); done_group(REQUIRED_GROUPS[0])

func h04_source_ticks() -> void:
 var sim=fresh(["yanguizhou_h04"]); var target: Dictionary=enemy(sim,Vector3.ZERO)
 var state: Dictionary=river(sim)
 check(sim.ink_q2_receipts.size()==1 and sunset(sim).is_empty(),"activation river hits immediately; H04 has no birth tick")
 sim.step(4.0)
 var hits: Array=sunset(sim)
 check(hits.size()==8,"actual current parent step delivers eight H04 ticks")
 for i in range(hits.size()):
  near(hits[i].source_time,0.5*float(i+1),"fixed original H04 schedule")
  near(hits[i].actual_damage,38.0,"source 20 plus 18 percent AP")
  check(int(hits[i].cast_id)==int(state.cast_id),"H04 retains actual Q2 cast root")
 check(sim.ink_q2_finished.size()==1 and sim.ink_rivers.is_empty(),"last tick precedes single root retirement")
 near(100000.0-float(target.hp),150.0+8.0*38.0,"base river plus complete H04 damage")
 check(sim.clock.advances==sim.ink_core_steps and sim.presentation_errors.is_empty(),"H04 adds no world/core step")
 check(sim.ink_qe_holds.is_empty(),"new leaf owns sampler without old HOLD diagnostic")
 observations["actual_tick_trace"]=hits.duplicate(true)
 sim.free(); done_group(REQUIRED_GROUPS[1])

func prepared_tick(origin: Vector3) -> Dictionary:
 # Labelled dispatch seam: actual Q2/E3 transactions and damage pipeline;
 # source interval endpoints are injected to isolate an exact 0.5s tie.
 var sim=fresh(["yanguizhou_h04"]); var target: Dictionary=enemy(sim,origin)
 var state: Dictionary=river(sim)
 check(sim.request_e3("first",origin).accepted,"real E3 A before scheduled sample")
 var before: Dictionary=sim._enemy_motion_snapshot()
 sim.hero_time=0.5
 var contacts: Array=sim._q2_collect_contacts(before,0.48,0.5)
 return {"sim":sim,"target":target,"state":state,"contacts":contacts,"before":before}

func h04_discontinuous_atomic_samples() -> void:
 for spec: Dictionary in [{"from":Vector3(-4,0,0),"to":Vector3.ZERO,"hits":1},{"from":Vector3.ZERO,"to":Vector3(4,0,0),"hits":0},{"from":Vector3(-4,0,0),"to":Vector3(4,0,0),"hits":0}]:
  var f: Dictionary=prepared_tick(spec.from); var sim=f.sim
  check(sim.request_e3("second",spec.to).accepted,"actual same-time E3 exchange commits")
  check(f.target.position.distance_to(spec.to)<0.0001,"exact legal arrival endpoint")
  sim._q2_dispatch_contacts(f.contacts)
  check(sunset(sim).size()==int(spec.hits),"H04 samples committed arrival; outside gap never damages")
  check(sim.ink_qe_holds.is_empty(),"resolved sampler does not inherit old discontinuity HOLD")
  if spec.hits==1: check(sunset(sim)[0].target_position==spec.to,"receipt records arrived position")
  observations["tie_"+str(spec.from)+"_"+str(spec.to)]=sim.h04_sample_receipts.duplicate(true)
  sim.free()
 # Core may already be at .52 while this queued tick is only .50. A real
 # exchange stamped .52 must not rewrite the earlier scheduled sample.
 for spec: Dictionary in [{"from":Vector3(-4,0,0),"to":Vector3.ZERO,"hits":0},{"from":Vector3.ZERO,"to":Vector3(4,0,0),"hits":1}]:
  var earlier=fresh(["yanguizhou_h04"]); var target: Dictionary=enemy(earlier,spec.from)
  river(earlier); check(earlier.request_e3("first",spec.from).accepted,"late-jump real E3 A")
  var before: Dictionary=earlier._enemy_motion_snapshot()
  earlier.hero_time=0.52
  var contacts: Array=earlier._q2_collect_contacts(before,0.48,0.52)
  check(earlier.request_e3("second",spec.to).accepted,"later .52 exchange is committed before .50 ticket dispatch")
  earlier._q2_dispatch_contacts(contacts)
  check(sunset(earlier).size()==int(spec.hits),"earlier tick uses pre-jump continuous leg")
  if spec.hits==1: check(sunset(earlier)[0].target_position==spec.from,"earlier tick receipt cannot adopt later arrival")
  check(target.position==spec.to,"sample never moves live target back to its historical position")
  observations["late_jump_"+str(spec.from)]=earlier.h04_sample_receipts.duplicate(true)
  earlier.free()
 var f: Dictionary=prepared_tick(Vector3(-4,0,0)); var sim=f.sim
 sim.obstacles=[{"position":Vector3.ZERO,"half":Vector3(0.25,0,0.25)}]
 var rejected: Dictionary=sim.request_e3("second",Vector3.ZERO)
 check(not rejected.accepted and sim.ink_qe_discontinuities.is_empty(),"illegal landing rejects atomically without a jump")
 sim._q2_dispatch_contacts(f.contacts); check(sunset(sim).is_empty(),"rejected exchange cannot move H04 sample inside")
 sim.free()
 # A first tick callback moves a later target. The current tick already has a
 # complete atomic snapshot; a paused remainder must retain it exactly once.
 sim=fresh(["yanguizhou_h04"])
 var one: Dictionary=enemy(sim,Vector3(-0.2,0,0)); var two: Dictionary=enemy(sim,Vector3(0.2,0,0))
 river(sim); check(sim.request_e3("first",Vector3.ZERO).accepted,"E3 A for in-batch callback")
 var triggered: Dictionary={"done":false}
 sim.combat_event.connect(func(event: Dictionary):
  if event.kind=="ink_h04_contact" and not triggered.done:
   triggered.done=true
   check(sim.request_e3("second",Vector3(4,0,0)).accepted,"real exchange during first H04 callback")
   sim.paused=true)
 sim.step(0.5)
 check(triggered.done and sim.paused and sunset(sim).size()==1,"first H04 target pauses after real exchange")
 check(one.position.x>3.0 and two.position.x>3.0,"both live targets actually moved outside")
 sim.paused=false; sim.step(0.02)
 check(sunset(sim).size()==2,"paused same-tick remainder retains pre-callback atomic samples")
 check(sunset(sim)[1].target_position.x<1.0,"second receipt retains original sampled endpoint")
 check(sim.h04_sample_receipts.size()==1,"resume does not take a second same-tick snapshot")
 sim.step(0.5)
 check(sunset(sim).size()==2,"next scheduled tick sees outside arrival instead of stale membership")
 sim.free(); done_group(REQUIRED_GROUPS[2])

func composition_retirement() -> void:
 var sim=fresh(["yanguizhou_h03","yanguizhou_h04"])
 sim.hero.ranks.passive=1
 var state: Dictionary=river(sim)
 check(not sim.p1.roots.has(int(state.cast_id)),"historical P1 Hex cancellation guard remains explicit")
 check(not sim.river_hex_fixture_status().ordinary_admission,"technical source leaf does not open ordinary reward pool")
 check(sim.request_action("r",Vector3.ZERO).accepted,"current R2 presentation still starts")
 var before: float=sim.hero_time
 sim.step(0.4)
 near(sim.hero_time-before,0.1,"H04 remains on inherited quarter-speed world timeline")
 check(sunset(sim).is_empty(),"no private wall clock can create an early H04 tick")
 check(sim.clock.advances==sim.ink_core_steps and sim.presentation_errors.is_empty(),"current presentation one-clock ownership intact")
 sim.cancel_cast(int(state.cast_id))
 sim.step(1.0)
 check(sunset(sim).is_empty() and sim.ink_rivers.is_empty(),"cancelled root cannot emit old scheduled H04")
 sim.begin_encounter("river-hex-next-room",[])
 check(sim.h04_sample_receipts.is_empty() and sim._qe_jump_history.is_empty() and sim._q2_deferred_contacts.is_empty(),"new generation retires old sample and jump state")
 sim.free(); done_group(REQUIRED_GROUPS[3])

func run() -> void:
 h03_physical_scope(); h04_source_ticks(); h04_discontinuous_atomic_samples(); composition_retirement()
 var report: Dictionary={"schema":"ink-river-hex-finite-1","passed":failures.is_empty() and completed==REQUIRED_GROUPS,"checks":checks,"completed":completed,"failures":failures,"observations":observations,"source_binding_sha256":FileAccess.get_sha256("res://tests/ink_river_hexes_20261006/candidate01/source_binding.json"),"ordinary_admission":false,"native_input":"NOT_RUN","P1_P2_H04_ownership":"HOLD","art_audio_accepted":false,"real_multiplayer":false}
 if not output_path.is_empty():
  var file:=FileAccess.open(output_path,FileAccess.WRITE)
  if file==null: push_error("cannot_write_river_hex_result"); quit(2); return
  file.store_string(JSON.stringify(report,"  ")); file.close()
 print("INK_RIVER_HEX_RESULT ",JSON.stringify(report))
 quit(0 if report.passed else 1)
