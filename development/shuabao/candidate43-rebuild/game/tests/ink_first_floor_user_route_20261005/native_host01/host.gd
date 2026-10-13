extends "res://tests/ink_first_floor_user_route_20261005/native_host01/flow_bridge.gd"
## Opt-in ordinary new-route host. Q1/native/audio presentation methods unchanged.
## The single fresh authority is runtime01:30nodes,300paths, XP27/40/140, safe P shop.
const ROUTE_HOST_ROOT := "res://tests/ink_first_floor_user_route_20261005/native_host01/"
var growth_toggle: Button
var growth_open_requested := true
var growth_last_status := ""
var growth_battle_collapses := 0

func _session_scope() -> String:
 return "晏归舟 · 首层十二行连线路线候选 / 30节点 · 300条完整路径\n普通Lv1 · 0金0XP原1SP；Q1动作/effect05保留，XP试案与休息功能仍待完整实玩"

func _create_session_controls() -> void:
 super._create_session_controls()
 growth_toggle = Button.new()
 growth_toggle.position = Vector2(916,14); growth_toggle.size = Vector2(146,36)
 growth_toggle.add_theme_font_size_override("font_size",14)
 growth_toggle.pressed.connect(_toggle_growth)
 session_canvas.add_child(growth_toggle)
 _sync_growth_visibility()

func _refresh_session_controls(force: bool) -> void:
 super._refresh_session_controls(force)
 _sync_growth_visibility()

func _learning_panel_allowed() -> bool:
 if shop_session == null or shop_session.ledger == null or sim == null or sim.hero.dead: return false
 if _mainprep_required or finished or not floor_error.is_empty() or shop_session.panel_open or shop_session.initial_modal_open: return false
 var state: Dictionary = shop_session.ledger.model.snapshot()
 if not state.pending_milestones.is_empty(): return false
 if state.phase == "safe": return true
 # No new pause is imposed. Explicitly paused combat may expose earned-point
 # learning through the same existing source HUD; running combat never does.
 return sim.paused and int(state.points) > 0

func _sync_growth_visibility() -> void:
 if initial_hud == null or not is_instance_valid(initial_hud.growth_panel) or shop_session == null or shop_session.ledger == null: return
 var status: String = str(shop_session.status)
 if status == "combat" and growth_last_status != "combat":
  growth_open_requested = false; growth_battle_collapses += 1
 growth_last_status = status
 var allowed: bool = _learning_panel_allowed()
 initial_hud.growth_panel.visible = growth_open_requested and allowed
 # Route-entry instructions belong to preparation; no full panel covers active play.
 if is_instance_valid(session_next): session_next.visible = status != "combat"
 if is_instance_valid(session_hint): session_hint.visible = status != "combat"
 if is_instance_valid(growth_toggle):
  growth_toggle.visible = allowed
  growth_toggle.disabled = not allowed
  growth_toggle.text = "收起技能 · K" if initial_hud.growth_panel.visible else "展开技能 · K"

func _toggle_growth() -> void:
 if not _learning_panel_allowed(): return
 growth_open_requested = not growth_open_requested
 _sync_growth_visibility()

func _input(event: InputEvent) -> void:
 if event is InputEventKey:
  var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
  if key == KEY_K:
   if event.pressed and not event.echo: _toggle_growth()
   get_viewport().set_input_as_handled(); return
 super._input(event)

func user_route_report() -> Dictionary:
 var flow: Dictionary = shop_session.snapshot() if shop_session != null else {}
 var checked: Dictionary = FloorSession.MixedSchema.validate(shop_session.route,true) if shop_session != null and shop_session.row_state != null else {}
 return {"schema":"ink-user-route-native-host01","binding_sha256":FileAccess.get_sha256(ROUTE_HOST_ROOT+"source_binding.json"),"session_script":shop_session.get_script().resource_path if shop_session != null else "","route_version":flow.get("route_version",""),"node_count":checked.get("possible_node_count",0),"complete_path_count":checked.get("complete_path_count",0),"reward_binding":shop_session.ledger.model.reward_binding() if shop_session != null and shop_session.ledger != null else {},"growth_panel_visible":initial_hud.growth_panel.visible if initial_hud != null else false,"growth_battle_collapses":growth_battle_collapses,"rest_effect":"UNFINISHED_NO_DEFINED_RESTORATION","navigation_candidate_installed":false,"new_floor_native_passed":false,"boss_passed":false,"art_accepted":false}

func composition_report() -> Dictionary:
 var result: Dictionary = super.composition_report()
 result["upstream_presentation_binding"] = result.get("binding","")
 result["binding"] = FileAccess.get_sha256(ROUTE_HOST_ROOT+"source_binding.json")
 result["route_identity"] = user_route_report()
 return result

func _write_json(filename: String, contents: Dictionary) -> void:
 if evidence_dir.is_empty(): return
 var output: Dictionary = contents.duplicate(true)
 output["new_user_route_host"] = user_route_report()
 output["q1_native_wip"] = flow_native_report()
 output["audio_candidate"] = {"id":"ink_composed_audio_fix01_20261005","binding":FileAccess.get_sha256(AUDIO_ROOT+"source_binding.json"),"installed":audio_candidate_installed,"router":audio_output.router.snapshot() if is_instance_valid(audio_output) and audio_output.router != null else {},"new_Q3_authored_cues":true,"hardware_listening":false,"audio_quality_accepted":false}
 output["scope"] = _session_scope()
 output["first_battle_composition"] = composition_report()
 output["normal_floor"] = {"status":"NEW_30_NODE_USER_ROUTE_CANDIDATE","binding":FileAccess.get_sha256(ROUTE_HOST_ROOT+"source_binding.json"),"ancestor_floor_binding":FileAccess.get_sha256(REWARD_ROOT+"source_binding.json"),"flow":shop_session.snapshot() if shop_session != null else {},"enemies":enemy_layer.report if is_instance_valid(enemy_layer) else {},"q3":mountain_view.get_diagnostics() if is_instance_valid(mountain_view) else {},"preview":aim_preview.sample if is_instance_valid(aim_preview) else {},"dropped_history":dropped_history.duplicate(),"reward":_commerce_evidence(),"full_floor_passed":false,"native_art_performance_passed":false,"q3_gesture_imported":_actor_is_composed() and hero_view.q3_bound,"legacy_enemy_metrics_are_empty_anchor":true}
 var file: FileAccess = FileAccess.open(evidence_dir.path_join(filename),FileAccess.WRITE)
 if file != null: file.store_string(JSON.stringify(_json_safe(output),"  ")); file.close()
