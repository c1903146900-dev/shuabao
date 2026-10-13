extends "res://tests/ink_initial_vortex_host_20261004/host.gd"
## New exact constructor composition only. Initial four cards/real1SP, H02 v2,
## source input/safe clock/Q07/audio/death and ANY-room authority stay inherited.
const IntermediateSim = preload("res://tests/ink_intermediate_stats_20261004/ink_intermediate_sim.gd")
const IntermediateSession = preload("res://tests/ink_intermediate_shop_ui_20261004/session.gd")
const IntermediateFundedSession = preload("res://tests/ink_intermediate_shop_ui_20261004/funded_session.gd")
const IntermediatePanel = preload("res://tests/ink_intermediate_shop_ui_20261004/shop_panel.gd")
var intermediate_funded_diagnostic: bool = false

func _ready() -> void:
 intermediate_funded_diagnostic = "--ink-intermediate-funded-diagnostic" in OS.get_cmdline_user_args()
 super._ready()

func _session_scope() -> String:
 var context: String = super._session_scope()
 if intermediate_funded_diagnostic:
  context = context.replace("普通Lv1", "明确测试资金诊断 Lv1").replace("0金", "1500 TEST金币") + "；" + IntermediateFundedSession.FUNDING_LABEL
 return context + "；基础11/一级17真实属性合成接线候选"

func _start_encounter() -> void:
 if shop_session != null:
  startup_session_error = "fresh_restart_requires_exit_and_new_session"; return
 sim = IntermediateSim.new(); add_child(sim)
 sim.hero.position = Vector3(0,0,4)
 sim.arena_half_extent = Stage.EXTENT; sim.obstacles = Stage.OBSTACLES.duplicate(true)
 sim.ai_enabled = true; sim.auto_finish = false
 input_router = InitialInputRouter.new(); input_router.bind(sim)
 hero_view = HeroView.new(); add_child(hero_view)
 enemy_view = MinionView.new(); add_child(enemy_view); enemy_view.visible = false
 audio_output.restart_scope()
 shop_session = IntermediateFundedSession.new() if intermediate_funded_diagnostic else IntermediateSession.new()
 var run_id: String = "intermediate-ui-%d" % Time.get_ticks_usec()
 var initialized: Dictionary = shop_session.initialize_funded_session(sim, run_id, initial_flow_diagnostic, true) if intermediate_funded_diagnostic else shop_session.initialize_session(sim, run_id, initial_flow_diagnostic)
 if not initialized.accepted: startup_session_error = str(initialized.reason)
 else: shop_session.bind_input_suspender(input_router.suspend_input)
 sim.combat_event.connect(_combat_event)
 sim.encounter_finished.connect(_session_terminal)
 seen_receipts.clear(); q1_view.reset_visuals(); audio_output.clear()
 _refresh(0.0)


func _create_session_controls() -> void:
 super._create_session_controls()
 if not is_instance_valid(shop_panel): return
 # Replace only the view before any user input; same Session and handlers.
 shop_panel.free()
 shop_panel = IntermediatePanel.new(); session_canvas.add_child(shop_panel)
 shop_panel.bind_session(shop_session)
 shop_panel.close_requested.connect(func(): _shop(false))
 shop_panel.transaction_requested.connect(_submit_shop)
 _refresh_session_controls(true)

func _refresh_session_controls(force: bool) -> void:
 super._refresh_session_controls(force)
 if not is_instance_valid(session_header) or shop_session == null or shop_session.ledger == null: return
 if intermediate_funded_diagnostic:
  session_header.text = "1500 TEST初始金币 · 非自然赚金/非平衡验收\n" + session_header.text.get_slice("\n", 1)
  session_hint.text += "\n明确测试资金只在本次启动注入；仍需真实初始选择并花原1SP学习。"

func _refresh_local_text() -> void:
 super._refresh_local_text()
 if is_instance_valid(shop_panel) and is_instance_valid(shop_panel._title):
  if intermediate_funded_diagnostic: shop_panel._title.text = shop_panel._title.text.replace("普通成长入口", "测试资金诊断入口")
  shop_panel._title.text += " · 一级合成接线候选" + (" · 1500 TEST初始金币" if intermediate_funded_diagnostic else "")

func _journal_scope() -> Dictionary:
 var out: Dictionary = super._journal_scope()
 out["branch"] = ("intermediate_funded_TEST_" if intermediate_funded_diagnostic else "intermediate_zero_gold_") + ("one_ai" if initial_flow_diagnostic else "ordinary_12_rows_HOLD")
 return out

func _journal_ledger() -> Dictionary:
 var out: Dictionary = super._journal_ledger()
 out["test_initial_funding"] = 1500 if intermediate_funded_diagnostic else 0
 out["runtime_source_binding"] = IntermediateSession.IntermediateBinding.EXPECTED_BINDING
 return out

func _h02_evidence() -> Dictionary:
 var out: Dictionary = super._h02_evidence()
 out["ancestor_runtime_source_binding"] = out.runtime_source_binding
 out["runtime_source_binding"] = IntermediateSession.IntermediateBinding.EXPECTED_BINDING
 return out

func _commerce_evidence() -> Dictionary:
 return {"runtime_source_binding":IntermediateSession.IntermediateBinding.EXPECTED_BINDING, "scope":_session_scope(), "test_initial_gold":1500 if intermediate_funded_diagnostic else 0, "funding_receipt":shop_session.funding_receipt.duplicate(true) if intermediate_funded_diagnostic and shop_session != null else {}, "recipe_projection":shop_panel.recipe_projection.duplicate(true) if is_instance_valid(shop_panel) and shop_panel.get_script() == IntermediatePanel else {}, "initial_hex_skipped":false, "automatic_learning":false, "natural_earning_accepted":false, "final_shop_art_accepted":false, "ordinary_12_rows_ready":false}

func _write_json(filename: String, contents: Dictionary) -> void:
 var out: Dictionary = contents.duplicate(true)
 if out.has("source_binding"):
  out["ancestor_source_binding"] = out.source_binding
  out["source_binding"] = IntermediateSession.IntermediateBinding.EXPECTED_BINDING
 if out.has("funding"): out["ancestor_funding"] = out.funding
 out["funding"] = IntermediateFundedSession.FUNDING_LABEL if intermediate_funded_diagnostic else "0 initial gold; original source rewards only"
 out["test_initial_gold"] = 1500 if intermediate_funded_diagnostic else 0
 if out.has("diagnostic_flag"):
  out["ancestor_diagnostic_flag"] = out.diagnostic_flag
  out["diagnostic_flag"] = intermediate_funded_diagnostic or initial_flow_diagnostic
 out["intermediate_commerce"] = _commerce_evidence()
 super._write_json(filename, out)

func _json_safe(value: Variant) -> Variant:
 if value is Dictionary and value.has("source_snapshot") and value.has("frame_post_draw_index"):
  var frame: Dictionary = value.duplicate(false)
  frame["intermediate_commerce"] = _commerce_evidence()
  return super._json_safe(frame)
 return super._json_safe(value)
