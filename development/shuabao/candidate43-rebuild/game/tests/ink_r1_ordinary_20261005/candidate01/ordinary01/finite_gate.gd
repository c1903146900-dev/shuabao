extends SceneTree
## Ordinary zero-resource admission plus explicitly seeded mechanics/level fixtures.
## InputEvent calls are not native device evidence. No natural Lv6 claim.
const Sim = preload("res://tests/ink_r1_ordinary_20261005/candidate01/sim.gd")
const OldSim = preload("res://tests/ink_e1_ordinary_20261005/candidate01/sim.gd")
const Session = preload("res://tests/ink_r1_ordinary_20261005/candidate01/ordinary01/floor_session.gd")
const Binding = preload("res://tests/ink_r1_ordinary_20261005/candidate01/ordinary01/live_binding.gd")
const Router = preload("res://tests/ink_r1_ordinary_20261005/candidate01/ordinary01/input_adapter.gd")
const Growth = preload("res://tests/ink_r1_ordinary_20261005/candidate01/ordinary01/growth_hud.gd")
const Controller = preload("res://tests/ink_q3_input_growth_20261004/controller.gd")
const Navigation = preload("res://tests/ink_r1_ordinary_20261005/candidate01/ordinary01/navigation_install.gd")
const RCard = preload("res://tests/ink_r1_ordinary_20261005/candidate01/ordinary01/r_hud.gd")
const QCard = preload("res://tests/ink_r1_ordinary_20261005/candidate01/ordinary01/hud_projection.gd")
const ECard = preload("res://tests/ink_e1_ordinary_20261005/candidate01/e1_hud.gd")
const Bottom = preload("res://tests/ink_style_specimen_20261004/revision10_hud/hud.gd")
const View = preload("res://tests/ink_r1_ordinary_20261005/candidate01/ordinary01/domain_view.gd")
const Room = preload("res://scripts/integration/yanguizhou_first_floor.gd")
const Design = preload("res://data/final_design/catalog.gd")
const REWARDS := "res://tests/ink_first_floor_user_route_20261005/runtime01/"
var checks := 0
var failures: Array[String] = []
var groups: Array[String] = []
var output_path := "user://r1_ordinary_finite.json"
var serial := 0
func _initialize() -> void:
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--r1-ordinary-result="): output_path = arg.trim_prefix("--r1-ordinary-result=")
 run.call_deferred()
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok: failures.append(label); push_error(label)
func near(a: float, b: float, label: String) -> void: check(is_finite(a) and absf(a-b)<.00001,label)
func key(code: int, down: bool = true, echo: bool = false) -> InputEventKey:
 var e := InputEventKey.new(); e.physical_keycode = code; e.pressed = down; e.echo = echo; return e
func mouse(down: bool, button: int = MOUSE_BUTTON_LEFT) -> InputEventMouseButton:
 var e := InputEventMouseButton.new(); e.button_index = button; e.pressed = down; return e
func arm(router, point: Vector3 = Vector3.ZERO) -> Dictionary:
 var result: Dictionary = router.handle_event(key(KEY_R),point)
 router.handle_event(key(KEY_R,false),point); return result
func fixture(q: String = "q3") -> Dictionary:
 var sim = Sim.new(); root.add_child(sim); sim.ai_enabled = false; sim.auto_finish = false
 sim.hero.loadout.r = "r1"; sim.hero.ranks.r = 1
 sim.hero.loadout.q = q; sim.hero.ranks.q = 1
 sim.hero.loadout.e = "e1"; sim.hero.ranks.e = 1
 sim.arena_half_extent = 100; sim.obstacles = []; serial += 1
 sim.begin_encounter("explicit-r1-input-fixture-%d"%serial,[])
 var router = Router.new(); router.bind(sim)
 return {"sim":sim,"router":router}
func run() -> void:
 var ordinary: Dictionary = ordinary_admission()
 if not ordinary.is_empty():
  level_fixture(ordinary)
  await ui_geometry(ordinary)
  ordinary.s.close_run(); ordinary.growth.free(); ordinary.sim.free()
 input_pairs(); preview_competition(); rain_frontdoor(); view_readback()
 var report: Dictionary = {"passed":failures.is_empty(),"checks":checks,"failures":failures,"groups":groups,"binding":FileAccess.get_sha256(Binding.BINDING_PATH),"gate_sha256":FileAccess.get_sha256(get_script().resource_path),"scope":"ordinary zero-resource authority plus labeled Lv6 and source-input fixtures","level6_fixture":true,"natural_level6_verified":false,"native_input":false,"full_floor":false,"art_audio_accepted":false,"R2_H13_H16_opened":false}
 var file := FileAccess.open(output_path,FileAccess.WRITE)
 if file != null: file.store_string(JSON.stringify(report,"  ")); file.close()
 else: failures.append("result_write_failed"); report.passed = false
 print("INK_R1_ORDINARY_REPORT ",JSON.stringify(report)); quit(0 if failures.is_empty() else 1)

func ordinary_admission() -> Dictionary:
 var old = OldSim.new(); root.add_child(old)
 check(not Binding.read_capabilities(old,true).accepted,"new exact binding rejects old E1 sim"); old.free()
 var sim = Sim.new(); root.add_child(sim)
 var identity: int = sim.enemy_director.get_instance_id()
 check(Navigation.apply_to_fresh_ink_sim(sim).accepted,"fresh exact constructor director admitted")
 check(not Navigation.apply_to_fresh_ink_sim(sim).accepted and sim.enemy_director.get_instance_id()==identity,"navigation never replaces director or admits twice")
 var s = Session.new()
 check(s.configure_reward_table(REWARDS+"reward_table.json",REWARDS+"rewards.csv",REWARDS+"validation_result.json",true).accepted,"same authored reward table")
 var definition: Dictionary = Session.MixedSchema.load_definition(Session.DEFAULT_DEFINITION,true)
 var initialized: Dictionary = s.initialize_floor(sim,definition.definition,"r1-ordinary-gate",true)
 check(initialized.accepted,"one exact ordinary Session initialized: "+str(initialized.reason))
 if not initialized.accepted: sim.free(); return {}
 var router = Router.new(); router.bind(sim); s.bind_input_suspender(router.suspend_input)
 var growth = Growth.new(); root.add_child(growth)
 var c = Controller.new(); c.bind_session(s,growth); c.gameplay_block_changed.connect(s.set_modal_blocked)
 var state: Dictionary = s.ledger.model.snapshot()
 check(state.level==1 and state.points==1 and state.gold==0 and state.xp==0,"ordinary original1SP zero gold/XP")
 check(state.selected_hex.is_empty() and state.reward_ids.is_empty(),"no automatic Hex or reward receipt")
 check(s._owner_intact() and is_same(sim.progression,s.ledger),"one HP/stat/reward/economy owner")
 growth.r1_choice.pressed.emit()
 check(not c.last_result.accepted and c.last_result.reason=="mandatory_hex_pending","R cannot skip original mandatory Hex")
 c.ensure_auto_hex(); growth.adapter.request("hex_select",{"milestone":1,"slot":3})
 check(c.last_result.accepted,"actual initial offer selected through unchanged controller")
 growth.r1_choice.pressed.emit()
 check(not c.last_result.accepted and c.last_result.reason=="level_gate" and growth.r1_choice.disabled,"Lv1 R button/model both retain Lv6 gate")
 growth.e1_choice.pressed.emit(); check(c.last_result.accepted and sim.hero.ranks.e==1 and s.ledger.model.state.points==0,"original1SP learns E1")
 growth.undo_button.pressed.emit(); check(c.last_result.accepted and sim.hero.ranks.e==0 and s.ledger.model.state.points==1,"undo returns only original point")
 growth.e1_choice.pressed.emit()
 var caps: Dictionary = Binding.read_capabilities(sim,true)
 check(caps.accepted and caps.capabilities.runtime_candidates==["Q1","Q2","Q3","E1","R1"],"only base R1 added")
 var count := 0
 for id: String in s.ledger.definitions.hexes:
  if s.ledger.model.support(s.ledger.definitions.hexes[id]).supported: count += 1
 check(count==10,"unchanged ten available hooks")
 for id: String in ["yanguizhou_h13","yanguizhou_h14","yanguizhou_h15","yanguizhou_h16"]:
  check(not s.ledger.model.support(s.ledger.definitions.hexes[id]).supported,"unconsumed R Hex stays closed: "+id)
 groups.append("ordinary_zero_resource_learning_owner_and_exact_caps")
 return {"sim":sim,"s":s,"router":router,"growth":growth,"c":c}

func level_fixture(f: Dictionary) -> void:
 # Explicit cost/UI fixture ONLY. These writes are never in host startup and
 # do not add a reward ID, gold or claim a naturally played Lv6 run.
 var model = f.s.ledger.model
 model.state.level = 6; model.state.points = 5
 model.state.granted_level_ids = [1,2,3,4,5,6]; model.state.revision += 1
 f.c.refresh(); f.c.ensure_auto_hex()
 f.growth.adapter.request("hex_select",{"milestone":4,"slot":3})
 check(f.c.last_result.accepted,"fixture Lv4 milestone still uses real offer choice")
 f.c.refresh(); f.growth.r1_choice.pressed.emit()
 check(f.c.last_result.accepted and model.state.points==4 and f.sim.hero.ranks.r==1,"labeled Lv6 fixture button spends1SP for R1")
 f.growth.r1_choice.pressed.emit()
 check(f.c.last_result.accepted and model.state.level==6 and model.state.points==2 and f.sim.hero.ranks.r==2,"same Lv6 next R rank costs2 without level11 gate")
 f.growth.r1_choice.pressed.emit()
 check(f.c.last_result.accepted and model.state.level==6 and model.state.points==0 and f.sim.hero.ranks.r==3,"same Lv6 third rank costs2 without level16 gate")
 f.growth.r1_choice.pressed.emit()
 check(not f.c.last_result.accepted and f.c.last_result.reason=="insufficient_points" and f.growth.r1_choice.disabled,"fourth R rank still needs2 real model points")
 check(model.state.gold==0 and model.state.xp==0 and model.state.reward_ids.is_empty(),"level fixture never forges gold XP or reward receipt")
 f.growth.undo_button.pressed.emit()
 check(f.c.last_result.accepted and f.sim.hero.ranks.r==2 and model.state.points==2,"same safe visit undo refunds actual2SP")
 groups.append("explicit_level6_cost_and_button_fixture_not_natural_progression")

func ui_geometry(f: Dictionary) -> void:
 var viewport := SubViewport.new(); viewport.size = Vector2i(1280,720); root.add_child(viewport)
 f.growth.reparent(viewport)
 preload("res://tests/ink_normal_floor_layout_fix01_20261005/growth_hud.gd").apply_layout(f.growth)
 Growth.apply_r_layout(f.growth)
 var hud = Bottom.new(); viewport.add_child(hud)
 await process_frame
 var q: Dictionary = QCard.apply_to(hud,f.sim)
 ECard.apply_to(hud,f.sim); var shown: Dictionary = RCard.apply_to(hud,f.sim)
 check(shown.learned and shown.rank==2 and shown.level==6,"R HUD reads actual fixture ledger and selected rank")
 check(Design.description("yanguizhou","r1",2) in str(shown.tooltip) and "美术" in str(shown.tooltip),"R tooltip contains full original rank description and temporary-art limit")
 var r: Control = hud.get_node(NodePath(RCard.PATCH_NAME))
 var e: Control = hud.get_node(NodePath(ECard.PATCH_NAME))
 var q_patch: Control = hud.get_node(NodePath("SelectedQReadOnlyProjection"))
 check(not r.get_global_rect().intersects(e.get_global_rect()) and not r.get_global_rect().intersects(q_patch.get_global_rect()),"R card does not overlap actual Q/E Controls")
 check(Rect2(Vector2.ZERO,Vector2(1280,720)).encloses(r.get_global_rect()),"R card stays inside1280x720")
 var panel: Rect2 = f.growth.growth_panel.get_global_rect()
 check(Rect2(Vector2.ZERO,Vector2(1280,720)).encloses(panel),"growth panel including actual minimum-size container fits viewport")
 check(panel.end.y<=598.01 and panel.size.x<=420.01,"growth row expands upward and preserves bottom-clearance/width")
 check(f.growth.r1_choice.get_global_rect().intersects(panel),"R button lies in visible growth panel")
 check(not q.is_empty(),"full selected-Q successor projection still available")
 f.growth.reparent(root); viewport.free(); groups.append("full_tooltip_readback_and_actual_control_rectangles")

func input_pairs() -> void:
 var f: Dictionary = fixture(); var sim = f.sim; var router = f.router
 check(arm(router).accepted and sim.ink_snow.is_empty() and sim.hero.cooldowns.r==0,"R-down/up only preaim")
 check(not router.handle_event(mouse(false)).accepted and not router.r1_aim.is_empty(),"unpaired up never commits")
 check(router.handle_event(mouse(true),Vector3(3,0,0)).accepted,"fresh LMB-down commits once")
 var count: int = sim.cast_serial; var cd: float = sim.hero.cooldowns.r
 router.handle_event(mouse(true),Vector3(4,0,0)); router.handle_event(mouse(false),Vector3(4,0,0))
 check(sim.cast_serial==count and sim.ink_snow.position==Vector3(3,0,0),"duplicate down/up neither recasts nor moves circle")
 near(sim.hero.cooldowns.r,cd,"duplicate physical pair leaves CD unchanged")
 check(not arm(router).accepted,"new R on cooldown refused")
 router.suspend_input("pause"); check(not sim.ink_snow.is_empty(),"suspension keeps committed domain")
 sim.free()
 for why: String in ["escape","right","focus","range","gui","control"]:
  f=fixture(); sim=f.sim; router=f.router; arm(router)
  if why=="escape": router.handle_event(key(KEY_ESCAPE))
  elif why=="right": router.handle_event(mouse(true,MOUSE_BUTTON_RIGHT))
  elif why=="focus": router.focus_lost()
  elif why=="control": sim.hero.stun_left=.4
  var point := Vector3(12.1,0,0) if why=="range" else Vector3(3,0,0)
  var projector: Callable = func(_p: Vector2) -> Vector3: return point
  var result: Dictionary = router.route_event(mouse(true),projector,point,true) if why=="gui" else router.handle_event(mouse(true),point)
  router.handle_event(mouse(false),point)
  check(not result.accepted and sim.ink_snow.is_empty() and sim.ink_basics.is_empty() and sim.cast_serial==0,"retired/invalid R click never falls through BASIC: "+why)
  sim.free()
 groups.append("R_input_pair_dedup_cooldown_cancel_gui_control")

func preview_competition() -> void:
 var f: Dictionary = fixture("q3"); var sim=f.sim; var router=f.router
 check(router.handle_event(key(KEY_Q),Vector3(4,0,0)).accepted,"Q3 preaim available")
 check(arm(router).accepted and router.q3_aim.is_empty(),"R replaces only Q3 preaim")
 check(router.handle_event(key(KEY_Q),Vector3(4,0,0)).accepted and router.r1_aim.is_empty(),"new Q takes over R preaim")
 check(router.handle_event(mouse(true),Vector3(4,0,0)).accepted,"replacement click goes only to Q3")
 router.handle_event(mouse(false)); var mountain: String=sim.ink_mountain.terrain_id
 check(arm(router).accepted and sim.ink_mountain.terrain_id==mountain,"R preserves committed Q3 mountain")
 check(router.handle_event(mouse(true),Vector3(3,0,0)).accepted and sim.ink_mountain.terrain_id==mountain,"R field and committed Q3 coexist")
 router.handle_event(mouse(false)); sim.free()
 f=fixture("q2"); sim=f.sim; router=f.router
 router.handle_event(key(KEY_Q)); router.handle_event(mouse(true),Vector3(3,0,0)); router.handle_event(mouse(false))
 var marker: int=sim.ink_q2_pending.cast_id
 router.handle_event(key(KEY_Q)); check(arm(router).accepted and sim.ink_q2_pending.cast_id==marker,"R retires Q2 second preview while retaining actual marker")
 sim.free()
 f=fixture("q1"); sim=f.sim; router=f.router
 router.handle_event(key(KEY_Q)); check(arm(router).accepted and sim.ink_input.phase=="idle","R replaces unstarted Q1 preaim")
 router.handle_event(key(KEY_Q)); router.handle_event(mouse(true),Vector3.ZERO)
 check(not arm(router).accepted and sim.ink_input.phase in ["drawing","frozen"],"R cannot steal held Q1 drawing")
 sim.free(); groups.append("Q_R_uncommitted_preview_ownership_and_existing_effects")

func rain_frontdoor() -> void:
 var f: Dictionary=fixture(); var sim=f.sim; var router=f.router
 check(router.handle_event(key(KEY_E)).accepted,"real-event E1 entry remains")
 check(not arm(router).accepted and sim.ink_snow.is_empty(),"rain form rejects new R")
 var room=Room.new(); room.sim=sim; room.input_router=router; room._mainprep_required=false
 room.frontdoor_clear_input(); room.frontdoor_clear_input()
 check(router.e1_release_is_owned() and not router.r1_input_snapshot().armed,"frontdoor R clearing retains true E release ownership")
 sim.paused=true
 var release: Dictionary=room.frontdoor_observe_e1_release(key(KEY_E,false))
 check(release.accepted and sim.ink_rain.release_pending,"real owned E-up still queues at boundary")
 var at: float=sim.hero_time; sim.step(.4); near(sim.hero_time,at,"queued E-up cannot advance paused source")
 sim.paused=false; sim.step(.02)
 check(sim.ink_rain.is_empty() and sim.ink_e1_finished.size()==1,"queued E-up reforms once after resume")
 room.free(); sim.free()
 f=fixture(); sim=f.sim; router=f.router; arm(router)
 room=Room.new(); room.sim=sim; room.input_router=router; room._mainprep_required=false
 room.frontdoor_clear_input()
 check(router.r1_aim.is_empty() and arm(router).accepted,"frontdoor fresh-event reset permits only a new R preaim")
 room.free(); sim.free(); groups.append("frontdoor_R_clear_preserves_true_E_up_pending")

func view_readback() -> void:
 var f: Dictionary=fixture(); var sim=f.sim; var router=f.router
 var view=View.new(); root.add_child(view); arm(router,Vector3(4,0,0))
 var snapshot: Dictionary=sim.ink_presenter_snapshot(); var bytes: PackedByteArray=var_to_bytes(snapshot)
 view.present_source(snapshot,router.r1_preview_for_view(Vector3(4,0,0)))
 check(not view.preview_sample.is_empty() and view.domain_sample.is_empty(),"temporary view shows preaim only before commit")
 check(var_to_bytes(snapshot)==bytes and sim.ink_snow.is_empty(),"preview view cannot mutate snapshot or source")
 router.handle_event(mouse(true),Vector3(4,0,0)); router.handle_event(mouse(false))
 snapshot=sim.ink_presenter_snapshot(); bytes=var_to_bytes(snapshot)
 view.present_source(snapshot,{})
 check(view.domain_sample.get("position",Vector3.INF)==Vector3(4,0,0) and var_to_bytes(snapshot)==bytes,"fixed functional circle uses source snapshot only")
 snapshot.snow.generation+=1; view.present_source(snapshot,{})
 check(view.domain_sample.is_empty(),"wrong generation hides stale domain circle")
 snapshot=sim.ink_presenter_snapshot(); snapshot.snow.remaining=0; view.present_source(snapshot,{})
 check(view.domain_sample.is_empty(),"expired snapshot hides domain circle")
 view.free(); sim.free(); groups.append("temporary_circle_read_only_identity_and_expiry")
