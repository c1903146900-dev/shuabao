extends SceneTree
## Text-only integration assertions. No E2/P1 mechanics or old full matrices.
const Chooser = preload("res://scripts/ui/hero_chooser.gd")
const Production = preload("res://scripts/integration/yanguizhou_first_floor.gd")
const FixtureHost = preload("res://tests/ink_e2_boundary_20261006/ordinary01/finite_host.gd")
const Session = preload("res://tests/ink_e2_boundary_20261006/ordinary01/text01/floor_session.gd")
const Binding = preload("res://tests/ink_e2_boundary_20261006/ordinary01/text01/live_binding.gd")
const RuntimeText = preload("res://tests/ink_e2_boundary_20261006/ordinary01/text01/runtime_text.gd")
const RuntimeCatalog = preload("res://tests/ink_e2_boundary_20261006/ordinary01/catalog.gd")
const QPCard = preload("res://tests/ink_e2_boundary_20261006/ordinary01/hud_projection.gd")
const ECard = preload("res://tests/ink_e2_boundary_20261006/ordinary01/e_hud.gd")
const RCard = preload("res://tests/ink_r1_ordinary_20261005/candidate01/ordinary01/r_hud.gd")
const Bottom = preload("res://tests/ink_style_specimen_20261004/revision10_hud/hud.gd")
const Audio = preload("res://tests/ink_style_specimen_20261004/audio_output.gd")
const Design = preload("res://data/final_design/catalog.gd")
const HOME := "res://tests/ink_first_floor_user_route_20261005/runtime01/"
const LEAF := "res://tests/ink_e2_boundary_20261006/ordinary01/text01/"
const REQUIRED := ["catalog_chooser_and_source_scope","real_growth_and_hover_consistency","same_owner_and_refresh_lifecycle"]
var checks: int = 0
var failures: Array[String] = []
var groups: Array[String] = []
var output_path: String = ""

func _initialize() -> void:
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--text-result=" ): output_path = arg.trim_prefix("--text-result=")
 run.call_deferred()
func check(ok: bool, label: String) -> bool:
 checks += 1
 if not ok: failures.append(label); push_error(label)
 return ok
func source_state(sim: Node, session: RefCounted) -> Dictionary:
 return {"source_time":sim.hero_time,"core_steps":sim.ink_core_steps,"casts":sim.cast_serial,"hp":sim.hero.hp,"cooldowns":sim.hero.cooldowns.duplicate(true),"actor":sim.hero.get_instance_id(),"director":sim.enemy_director.get_instance_id(),"ledger":session.ledger.get_instance_id(),"model":session.ledger.model.snapshot(),"room":sim.room_id,"run":session.run_id}
func build_hud(room, sim) -> void:
 room.q2_selected_projection = QPCard.apply_to(room.hud,sim)
 room.composed_q_projection = room.q2_selected_projection.duplicate(true)
 room.p1_selected_projection = QPCard.apply_p_to(room.hud,sim)
 room.e2_selected_projection = ECard.apply_to(room.hud,sim)
 room.e1_selected_projection = room.e2_selected_projection.duplicate(true)
 room.r1_selected_projection = RCard.apply_to(room.hud,sim)
 room._refresh_runtime_text()
func check_card(room, slot: String, node_name: String, candidate: String) -> void:
 var shown: Dictionary = room.hud.source_model.get(slot,{})
 var card: Control = room.hud.get_node_or_null(NodePath(node_name))
 check(not shown.is_empty() and card != null,"real "+candidate+" card exists")
 if shown.is_empty() or card == null: return
 check(not str(shown.tooltip).contains(RuntimeText.LEGACY_UNIMPLEMENTED),candidate+" selected model has no obsolete implementation notice")
 check(card.tooltip_text == str(shown.tooltip) and str(card.projected.tooltip) == str(shown.tooltip),candidate+" actual hover and detached projection agree")

func run() -> void:
 check(RuntimeText.candidates() == RuntimeCatalog.FIRST_SLICE_ALLOWED_CANDIDATES,"chooser skill list derives exact current capability ceiling")
 var chooser = Chooser.new(); root.add_child(chooser)
 chooser.select_hero("yanguizhou")
 check(chooser.skill_label.text == RuntimeText.skill_line(),"real selected chooser line uses current catalog")
 check(chooser.note_label.text == RuntimeText.hero_note() and chooser.hero_buttons.yanguizhou.tooltip_text == RuntimeText.hero_note(),"chooser body and hero-button hover share one current note")
 for candidate: String in RuntimeText.candidates(): check(chooser.skill_label.text.contains(candidate),"chooser includes admitted "+candidate)
 check(chooser.note_label.text.contains("回满生命") and chooser.note_label.text.contains("基础血瓶不补充") and not chooser.note_label.text.contains("不恢复生命"),"chooser states the effective rest rule")
 chooser.select_hero("xuanlei")
 check(chooser.note_label.text == Chooser.NOTES.xuanlei,"other hero copy remains unchanged")
 chooser.set_session("晏归舟"); chooser.set_busy(true)
 check(chooser.resume_button.visible and chooser.enter_button.disabled and chooser.resume_button.disabled,"text correction retains chooser busy/session lifecycle")
 chooser.set_busy(false); chooser.select_hero("yanguizhou")
 check(not chooser.enter_button.disabled and chooser.skill_label.text == RuntimeText.skill_line(),"returning to hero restores live consistent copy")
 check(Design.description("yanguizhou","p1",1).contains(RuntimeText.LEGACY_UNIMPLEMENTED),"source description remains immutable")
 for candidate: String in ["E3","P2","P3","R2"]:
  check(RuntimeText.correct(candidate,RuntimeText.LEGACY_UNIMPLEMENTED) == RuntimeText.LEGACY_UNIMPLEMENTED,"closed "+candidate+" is never presented as implemented")
 check(RuntimeText.correct("Q2","美术/音频未实现，实机未验；H03/H04未开放") == "美术/音频未实现，实机未验；H03/H04未开放","art, validation and closed-Hex limits are preserved")
 groups.append("catalog_chooser_and_source_scope")
 var room = FixtureHost.new(); root.add_child(room)
 var sim: Node = room._make_floor_sim(); room.sim = sim; room.add_child(sim)
 var session: RefCounted = room._make_floor_session(); room.shop_session = session
 room.input_router = room._make_floor_router(); room.input_router.bind(sim)
 room.audio_output = Audio.new(); room.add_child(room.audio_output)
 room._mainprep_required = false; room._mainprep_pending = false
 var production_script: GDScript = Production
 check(production_script.get_base_script().resource_path == LEAF+"host.gd","production selects text-only leaf")
 check(sim.get_script().resource_path == Binding.SIM_PATH and room.input_router.get_script().resource_path == "res://tests/ink_e2_boundary_20261006/ordinary01/input_adapter.gd","exact previously tested Sim and input router stay unchanged")
 check(room._install_source_navigation().accepted,"text successor independently admits retained navigation")
 check(session.configure_reward_table(HOME+"reward_table.json",HOME+"rewards.csv",HOME+"validation_result.json",true).accepted,"same source rewards configured")
 var definition: Dictionary = Session.MixedSchema.load_definition(Session.DEFAULT_DEFINITION,true)
 var initialized: Dictionary = session.initialize_floor(sim,definition.definition,"e2-text-only-finite",true)
 if check(initialized.accepted,"text Session/Bridge selects same single authority: "+str(initialized.get("reason",""))):
  session.bind_input_suspender(room.input_router.suspend_input)
  room._create_session_controls()
  room.hud = Bottom.new(); room.add_child(room.hud)
  await process_frame
  room.initial_controller.ensure_auto_hex()
  room.initial_hud.adapter.request("hex_select",{"milestone":1,"slot":3})
  check(room.initial_controller.last_result.accepted,"existing mandatory Hex flow still works")
  var initial: Dictionary = session.ledger.model.snapshot()
  check(initial.level == 1 and initial.gold == 0 and initial.xp == 0 and initial.points == 1,"text update preserves ordinary initial resources")
  for candidate: String in RuntimeText.candidates():
   var descriptions: Array = session.ledger.definitions.get("skill_descriptions",{}).get(candidate,[])
   if not descriptions.is_empty():
    check(not RuntimeText.correct(candidate,descriptions[0]).contains(RuntimeText.LEGACY_UNIMPLEMENTED) and not RuntimeText.correct(candidate,descriptions.back()).contains(RuntimeText.LEGACY_UNIMPLEMENTED),"current "+candidate+" first/last rank descriptions clean only obsolete clause")
  check(session.ledger.definitions.skill_descriptions.P1[0].contains(RuntimeText.LEGACY_UNIMPLEMENTED),"runtime mechanics definitions remain unchanged; presentation alone is corrected")
  build_hud(room,sim)
  check(str(room.hud.source_model.selected_q.tooltip).contains("Q1 / Q2 / Q3"),"unlearned Q prompt includes all currently admitted Q candidates")
  for candidate: String in ["Q1","E1","P1","Q2","E2"]:
   var button: Button = room.initial_hud.q_choices[candidate].upgrade if candidate.begins_with("Q") else room.initial_hud.e1_choice if candidate == "E1" else room.initial_hud.e2_choice if candidate == "E2" else room.initial_hud.p1_choice
   button.pressed.emit()
   check(room.initial_controller.last_result.accepted and session.ledger.model.state.points == 0,"original one SP learns "+candidate+" through unchanged button")
   check(not button.tooltip_text.contains(RuntimeText.LEGACY_UNIMPLEMENTED),"actual "+candidate+" growth hover is corrected after refresh")
   if candidate == "P1": check(button.tooltip_text.contains("当前") and button.tooltip_text.contains("下一阶"),"P1 current and next-rank descriptions both remain visible")
   build_hud(room,sim)
   if candidate.begins_with("Q"): check_card(room,"selected_q","SelectedQReadOnlyProjection",candidate)
   elif candidate == "P1": check_card(room,"selected_p","P1ReadOnlyTemporaryCard",candidate)
   else: check_card(room,"selected_e","E2OrdinaryReadOnlyTemporaryCard",candidate)
   room.initial_hud.undo_button.pressed.emit()
   check(room.initial_controller.last_result.accepted and session.ledger.model.state.points == 1,"safe undo retains original "+candidate+" skill point")
  check(room.initial_hud.r1_choice.disabled and room.initial_hud.r1_choice.tooltip_text.contains("6级") and room.initial_hud.r1_choice.tooltip_text.contains("未完成"),"R1 level and unfinished-art limits remain truthful")
  check_card(room,"selected_r","R1ReadOnlyTemporaryCard","R1")
  groups.append("real_growth_and_hover_consistency")
  var before: Dictionary = source_state(sim,session)
  for _i in range(3):
   room.initial_controller.refresh(); build_hud(room,sim); room._refresh_session_controls(true)
  check(source_state(sim,session) == before,"repeated actual text refresh cannot mutate source clocks, HP, skills, resources or owners")
  room.frontdoor_suspend(); room.frontdoor_resume()
  check(source_state(sim,session) == before and session._owner_intact() and is_same(sim.progression,session.ledger),"same production menu Continue retains original actor/director/Session/ledger")
  check(room._session_scope().contains(RuntimeText.skill_line()) and room._session_scope().contains(RuntimeText.rest_rule()),"runtime scope uses the same skill list and rest rule as chooser")
  groups.append("same_owner_and_refresh_lifecycle")
  session.close_run()
 room.free(); chooser.free()
 for group: String in REQUIRED: check(group in groups,"required group completed: "+group)
 if output_path.is_empty() or FileAccess.file_exists(output_path): failures.append("fresh_explicit_output_required")
 var report: Dictionary = {"passed":failures.is_empty(),"checks":checks,"groups":groups,"failures":failures,"binding":FileAccess.get_sha256(Binding.BINDING_PATH),"gate_sha256":FileAccess.get_sha256(get_script().resource_path),"text_only":true,"mechanic_matrices_rerun":false,"native_input":false,"art_acceptance":false}
 if not output_path.is_empty() and not FileAccess.file_exists(output_path):
  var file := FileAccess.open(output_path,FileAccess.WRITE)
  if file == null: report.passed = false
  else: file.store_string(JSON.stringify(report,"  ")); file.close()
 print("INK_E2_TEXT_REPORT ",JSON.stringify(report))
 quit(0 if report.passed else 1)
