extends SceneTree
## New fixture revision on the current P3+worldFX+UI source. Synthetic original UI/route inputs.
## No gameplay seeds, enemy edits, combat-event emission, or unvalidated front animation.
const WALL_MS: int = 180000
const SOFT_MS: int = 170000
const FINISH_MS: int = 5000
const ENTRY_CHOOSER: int = 0
const ENTRY_RUN: int = 1
const BINDING_PATH = "res://yan_worldfx_ui_probe_20261018b/binding.json"
const BINDING_SHA = "06aab60aec766118e9563a528942d740d7d2874d114b86a642e825c1ba3892e7"
const RouteDriver = preload("res://natural_route_replay_prepare/visible_route_replay.gd")
const RiverShader = preload("res://visual_rework_20261009/views/q1_river.gdshader")
const UIReadback = preload("res://yan_worldfx_ui_probe_20261018b/ui_readback.gd")
const Observer = preload("res://yan_worldfx_observation_20261018/observer.gd")
var started: int = 0
var finishing: bool = false
var final_emitted: bool = false
var finish_deadline: int = 0
var stopped: String = ""
var output: String = ""
var output_owned: bool = false
var entry: Node
var host: Node
var owner_ids: Dictionary = {}
var owner_hero: Object = null
var observations: Array = []
var shots: Array = []
var covered: bool = false
var phase_label: String = "initialize"
var post_draw_seen: bool = false
var observer: Node
var worldfx: Node
var driver: RefCounted
var first_release: Dictionary = {}
var first_release_counter: int = -1
var visual_samples: Array = []
var failure_diagnostics: Array = []
var failure_shot_attempted: bool = false
var ui_covered: Dictionary = {}
var ui_connections: Dictionary = {}

func _initialize() -> void:
 started = Time.get_ticks_msec()
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--worldfx-ui-evidence="): output = arg.trim_prefix("--worldfx-ui-evidence=")
 # Independent non-coroutine watchdogs survive a runtime error in _work/_finish.
 process_frame.connect(_watchdog_frame)
 create_timer(float(SOFT_MS)/1000.0,true,false,true).timeout.connect(_watchdog_soft)
 call_deferred("_run")

func _process(_delta: float) -> bool:
 if not final_emitted and not _budget(): _watchdog_exit("absolute_or_finish_deadline")
 return false

func _watchdog_frame() -> void:
 if not final_emitted and Time.get_ticks_msec()>=started+WALL_MS: _watchdog_exit("absolute_180s_deadline")

func _watchdog_soft() -> void:
 if not final_emitted: _watchdog_exit("independent_170s_soft_deadline")

func _watchdog_exit(reason: String) -> void:
 if final_emitted: return
 # Lock before any I/O so an already-queued continuation cannot report green.
 covered=false;final_emitted=true;finishing=true;stopped=reason
 var row: Dictionary={"accepted":false,"reason":reason,"phase":phase_label,"elapsed_ms":Time.get_ticks_msec()-started,"source_released":false,"work_coroutine_completion_required":false}
 var io_ok: bool=false
 if output_owned:
  var file:=FileAccess.open(output.path_join("deadline.json"),FileAccess.WRITE)
  if file!=null:
   file.store_string(JSON.stringify(row,"  ")+"\n");file.flush();io_ok=file.get_error()==OK;file.close()
 print("WORLD_FX_UI_PROBE_FINAL ",JSON.stringify({"accepted":false,"io_ok":io_ok,"reason":reason,"source_released":false}))
 quit(4)

func _record(label: String, value: Dictionary) -> void:
 if observations.size() < 256: observations.append({"label":label,"wall_ms":Time.get_ticks_msec()-started,"value":value.duplicate(true)})

func _brief() -> Dictionary:
 var row: Dictionary = {"phase_label":phase_label,"reason":stopped,"owner_ids":owner_ids.duplicate(),"entry_valid":is_instance_valid(entry),"host_valid":is_instance_valid(host)}
 if is_instance_valid(host):
  for key: String in ["startup_session_error","floor_error","_mainprep_required","_mainprep_pending","initial_started","finished"]: row[key] = host.get(key)
  row["ordinary_visual_installation"] = host.ordinary_visual_installation.duplicate(true)
  if is_instance_valid(host.sim):
   row["source"] = {"id":host.sim.get_instance_id(),"room_id":host.sim.room_id,"generation":host.sim.encounter_generation,"phase":host.sim.phase,"hero_time":host.sim.hero_time,"paused":host.sim.paused,"hero_dead":host.sim.hero.dead,"hero_hp":host.sim.hero.hp}
  if host.shop_session != null: row["session_status"] = host.shop_session.status
  if is_instance_valid(host.initial_hud): row["hex_choosing"] = host.initial_hud.hex_draft.choosing
 if is_instance_valid(entry):
  row["worldfx_attachment"] = entry.worldfx_attachment_receipt.duplicate(true)
  row["worldfx_error"] = entry.worldfx_attachment_error
 row["first_release"] = _event_brief(first_release)
 return row

func _stop(reason: String) -> void:
 if stopped.is_empty(): stopped = reason
 if failure_diagnostics.size() < 4: failure_diagnostics.append(_brief())
 if not failure_shot_attempted:
  failure_shot_attempted = true
  if post_draw_seen and _budget():
   var pixels: Image = root.get_texture().get_image()
   if pixels != null and not pixels.is_empty():
    while shots.size() >= 3: shots.pop_back()
    var total: int = pixels.get_data().size()
    for shot: Dictionary in shots: total += shot.image.get_data().size()
    if total <= 16*1024*1024: shots.append({"name":"failure.png","image":pixels})
 _record("failure",_brief())

func _sample(label: String) -> Dictionary:
 if not _identity(): _stop("original_owner_changed"); return {}
 var state: Dictionary = host.shop_session.ledger.model.snapshot()
 var row: Dictionary = {"room_id":host.sim.room_id,"generation":host.sim.encounter_generation,"skills":state.skills.duplicate(true),"points":state.points,"level":state.level,"xp":state.xp,"gold":state.gold,"phase":state.phase,"session_status":host.shop_session.status,"hero_time":host.sim.hero_time,"hero_q":host.sim.hero.loadout.q,"hero_q_rank":host.sim.hero.ranks.q}
 _record(label,row)
 return row

func _event_brief(event: Dictionary) -> Dictionary:
 var out: Dictionary = {}
 for key: String in ["kind","sequence","room_id","generation","wave_id","cast_id","gesture_id","source","source_time","released_at","path_length","width","speed"]:
  var value: Variant = event.get(key)
  if value is String or value is int or value is bool or (value is float and is_finite(value)): out[key] = value
 return out

func _source_event(event: Dictionary) -> void:
 if event.get("kind","") != "ink_q1_released" or not first_release.is_empty(): return
 first_release = event.duplicate(true)
 first_release_counter = int(worldfx.observed_events) if is_instance_valid(worldfx) else -1
 _record("first_real_Q1_release",{"event":_event_brief(event),"controller_counter_after":first_release_counter,"synthetic_event_emitted":false})

func _visual_sample() -> Dictionary:
 # Called only after the same frame_post_draw awaited by _capture. No presentation
 # update or source snapshot is forced here. Match GPU age to this actual Sim clock.
 var now: float = float(host.sim.hero_time)
 var born: float = float(first_release.get("released_at",NAN))
 var expected_age: float = now-born
 var result: Dictionary = {"accepted":false,"reason":"","source_hero_time":now,"released_at":born,"expected_shader_age":expected_age,"source_phase":host.sim.phase,"wave_id":str(first_release.get("wave_id","")),"legacy_q1_visible":host.q1_view.visible,"controller_counter":worldfx.observed_events,"layers":[]}
 if not is_finite(now) or not is_finite(born) or expected_age < 0.0: result.reason="nonfinite_source_clock"; return result
 if not is_instance_valid(worldfx.q1): result.reason="q1_view_invalid"; return result
 var key: String = result.wave_id
 var drawn: Dictionary = worldfx.q1._drawn
 result["drawn_keys"] = drawn.keys()
 if not drawn.has(key): result.reason="released_wave_not_drawn"; return result
 for candidate: Variant in drawn[key]:
  if not is_instance_valid(candidate) or not candidate is MeshInstance3D: result.reason="layer_node_invalid"; return result
  var node: MeshInstance3D = candidate
  if not is_instance_valid(node.mesh) or node.mesh.get_surface_count()<1: result.reason="layer_mesh_invalid"; return result
  if not is_instance_valid(node.material_override) or not node.material_override is ShaderMaterial: result.reason="layer_material_invalid"; return result
  var material: ShaderMaterial = node.material_override
  if not is_instance_valid(material.shader) or material.shader!=RiverShader: result.reason="unsealed_river_shader"; return result
  var age_value: Variant = material.get_shader_parameter("age")
  var front: Variant = material.get_shader_parameter("front_distance")
  if not (age_value is float or age_value is int) or not is_finite(float(age_value)) or absf(float(age_value)-expected_age)>0.00001: result.reason="shader_age_not_same_draw_source_time"; return result
  if not (front is float or front is int) or not is_finite(float(front)): result.reason="shader_front_distance_invalid"; return result
  var arrays: Array = node.mesh.surface_get_arrays(0)
  result.layers.append({"node_id":node.get_instance_id(),"mesh_id":node.mesh.get_instance_id(),"material_id":material.get_instance_id(),"visible":node.is_visible_in_tree(),"geometry_sha256":var_to_bytes(arrays).hex_encode().sha256_text(),"age":float(age_value),"age_error":absf(float(age_value)-expected_age),"front_distance":float(front),"shader_path":material.shader.resource_path,"sealed_shader_instance":true})
 result.accepted=result.layers.size()==3
 if not result.accepted: result.reason="three_actual_layers_required"
 return result

func _capture(name: String, river: bool = false) -> bool:
 if shots.size() >= 3 or not await _frame(): return false
 if not _identity(): _stop("capture_owner_changed"); return false
 if river:
  var sample: Dictionary = _visual_sample()
  if not sample.accepted: _record("invalid_river_sample",sample); _stop("river_sample:"+str(sample.reason)); return false
  if sample.layers.size() != 3 or sample.legacy_q1_visible: _stop("real_Q1_three_layers_or_legacy_hide_missing"); return false
  for layer: Dictionary in sample.layers:
   if not layer.visible: _stop("real_Q1_layer_not_visible"); return false
  visual_samples.append(sample.duplicate(true)); _record("capture:"+name,sample)
 else: _sample("capture:"+name)
 var pixels: Image = root.get_texture().get_image()
 if pixels == null or pixels.is_empty(): _stop("root_image_missing"); return false
 var total: int = pixels.get_data().size()
 for shot: Dictionary in shots: total += shot.image.get_data().size()
 if total > 16*1024*1024: _stop("raw_image_budget"); return false
 shots.append({"name":name,"image":pixels})
 return true

func _run() -> void:
 await _work()
 if not final_emitted: await _finish()

func _work() -> void:
 phase_label = "validate_fixture_and_source"
 if DisplayServer.get_name() == "headless": _stop("normal_window_required"); return
 if not output.is_absolute_path() or DirAccess.dir_exists_absolute(output) or FileAccess.file_exists(output): _stop("fresh_absolute_evidence_required"); return
 if DirAccess.make_dir_recursive_absolute(output) != OK: _stop("evidence_create_failed"); return
 output_owned = true
 if FileAccess.get_sha256(BINDING_PATH) != BINDING_SHA: _stop("fixture_binding_changed"); return
 var binding: Variant = JSON.parse_string(FileAccess.get_file_as_string(BINDING_PATH))
 if not binding is Dictionary: _stop("fixture_binding_invalid"); return
 for path: String in binding.files:
  if FileAccess.get_sha256(path) != binding.files[path]: _stop("source_pin_changed:"+path); return
 root.size = Vector2i(1280,720)
 var scene: PackedScene = load("res://scenes/hero_entry.tscn")
 if scene == null: _stop("thin_entry_missing"); return
 entry = scene.instantiate(); root.add_child(entry)
 observer = Observer.new(); root.add_child(observer); observer.attach_to_entry(entry)
 if not await _frame(): return
 phase_label = "original_Y_start_mainprep"
 entry.request_start("yanguizhou")
 while stopped.is_empty():
  if not await _frame(): return
  if is_instance_valid(entry.active_room):
   host = entry.active_room
   if not str(host.startup_session_error).is_empty() or not str(host.floor_error).is_empty(): _stop("original_startup_failed"); return
   if not host._mainprep_required and not host._mainprep_pending and host.initial_controller != null and host.initial_started and host.shop_session != null and host.shop_session.ledger != null: break
 if not stopped.is_empty(): return
 owner_hero = host.sim.hero
 owner_ids = {"room_id":host.sim.room_id,"generation":host.sim.encounter_generation,"host":host.get_instance_id(),"sim":host.sim.get_instance_id(),"session":host.shop_session.get_instance_id(),"model":host.shop_session.ledger.model.get_instance_id()}
 phase_label = "worldFX_attachment"
 while entry.worldfx_attachment_receipt.is_empty():
  if not _identity() or not await _frame(): return
 worldfx = host.get_node_or_null("InkSkillVisuals")
 if not is_instance_valid(worldfx) or worldfx.source != host.sim or not host.sim.combat_event.is_connected(Callable(worldfx,"_event")): _stop("original_worldFX_sink_missing"); return
 var initial_observation: Dictionary = observer.snapshot()
 _record("worldfx_attachment",initial_observation)
 if not initial_observation.failures.is_empty() or not initial_observation.observer_started_before_attach: _stop("observer_startup_order_unproven"); return
 host.sim.combat_event.connect(_source_event)
 var state: Dictionary = host.shop_session.ledger.model.snapshot()
 if state.level != 1 or state.xp != 0 or state.gold != 0 or state.points != 1 or not state.inventory.is_empty() or not state.body.is_empty(): _stop("fresh_original_budget_required"); return
 for skill: Dictionary in state.skills.values():
  if int(skill.rank) != 0: _stop("fresh_unlearned_skills_required"); return
 if host.shop_session.status != "preparation" or host.sim.hero_time != 0.0 or host.sim.phase != "preparation": _stop("original_preparation_required"); return
 if host.initial_hud.hex_draft.cards.size() != 4 or not host.initial_hud.hex_draft.is_visible_in_tree(): _stop("original_four_hex_choices_required"); return
 if not _ui_observe("initial_four_choice_modal"): return
 if not host.shop_session.initial_modal_open or entry.return_button.is_visible_in_tree(): _stop("initial_modal_return_visibility"); return
 ui_covered["initial_four_choice_modal"] = "OBSERVED"
 if not await _press_original_hex(): return
 if not await _frame(): return
 state = host.shop_session.ledger.model.snapshot()
 if not state.pending_milestones.is_empty() or state.points != 1: _stop("original_hex_not_settled"); return
 if not await _growth_reachability(): return
 if not _press(host.initial_hud.q_choices.Q1.upgrade,"learn_Q1"): return
 if not await _frame(): return
 var q: Dictionary = _sample("learned_Q1")
 if q.is_empty(): return
 if q.points != 0 or q.skills.Q != {"candidate":"Q1","rank":1} or q.hero_q != "q1" or q.hero_q_rank != 1: _stop("Q1_model_hero_projection_failed"); return
 if not await _ui_roundtrip(): return
 if host.initial_hud.growth_panel.is_visible_in_tree():
  _key_k()
  if not await _frame(): return
 driver = RouteDriver.new(); driver.bind_existing(host,started+SOFT_MS)
 if not await _enter_route_node(1,"r01a"): return
 if not await _frame() or not _ui_observe("first_original_room"): return
 phase_label = "first_real_Q1_release"
 while first_release.is_empty() and _budget() and stopped.is_empty():
  if not _identity(): _stop("combat_owner_changed"); return
  if host.sim.hero.dead: _stop("NOT_REACHED_natural_death_before_first_release"); return
  driver.advance_inputs()
  if not driver.failure.is_empty(): _stop("original_driver:"+driver.failure); return
  if not await _frame(): return
 if first_release.is_empty(): _stop("NOT_REACHED_first_Q1_release"); return
 driver.release_between_nodes()
 if first_release.get("room_id","") != owner_ids.room_id or first_release.get("generation",-1) != owner_ids.generation or first_release.get("source","") != "q1": _stop("real_release_scope_mismatch"); return
 var born: float = float(first_release.get("released_at",NAN))
 if not is_finite(born) or first_release_counter < 1: _stop("release_clock_or_controller_observation_missing"); return
 phase_label = "river_flow_two_source_times"
 for point: Dictionary in [{"age":0.10,"name":"01_q1_flow_early.png"},{"age":0.55,"name":"02_q1_flow_later.png"}]:
  while host.sim.hero_time-born < float(point.age):
   if not _identity() or host.sim.hero.dead: _stop("river_sampling_owner_or_hero_lost"); return
   if not await _frame(): return
  if not await _capture(point.name,true): return
 if visual_samples.size() != 2: _stop("two_river_samples_required"); return
 var early: Dictionary = visual_samples[0]
 var later: Dictionary = visual_samples[1]
 if later.source_hero_time <= early.source_hero_time: _stop("source_clock_not_advanced"); return
 for index: int in range(3):
  var a: Dictionary = early.layers[index]; var b: Dictionary = later.layers[index]
  if a.node_id != b.node_id or a.mesh_id != b.mesh_id or a.geometry_sha256 != b.geometry_sha256 or float(b.age) <= float(a.age): _stop("river_geometry_or_flow_age_contract_failed"); return
 var observed: Dictionary = observer.snapshot(); _record("worldfx_final_observation",observed)
 if not observed.failures.is_empty() or observed.ready_skill_events_before_attach != 0 or int(observed.events_by_kind.get("ink_q1_released",0)) != 1: _stop("actual_event_delivery_failed"); return
 if not _identity(): _stop("final_owner_changed"); return
 if final_emitted or not _budget() or Time.get_ticks_msec() >= started+SOFT_MS: _stop("final_coverage_deadline"); return
 covered = true

func _budget() -> bool:
 return Time.get_ticks_msec()<started+WALL_MS and (not finishing or Time.get_ticks_msec()<finish_deadline)

func _frame() -> bool:
 if final_emitted or not stopped.is_empty():return false
 await process_frame
 if final_emitted or not stopped.is_empty():return false
 await RenderingServer.frame_post_draw
 post_draw_seen=true
 return not final_emitted and stopped.is_empty() and _budget()

func _identity() -> bool:
 return not owner_ids.is_empty() and is_instance_valid(entry) and is_instance_valid(host) and entry.active_room==host and is_instance_valid(host.sim) and host.shop_session!=null and host.shop_session.ledger!=null and host.shop_session._owner_intact() and host.get_instance_id()==owner_ids.host and host.sim.get_instance_id()==owner_ids.sim and host.shop_session.get_instance_id()==owner_ids.session and host.shop_session.ledger.model.get_instance_id()==owner_ids.model and is_instance_valid(owner_hero) and is_same(host.sim.hero,owner_hero) and host.sim.room_id==owner_ids.room_id and host.sim.encounter_generation==owner_ids.generation

func _hex_trace(label: String, before_count: int) -> void:
 if not _identity():_record(label,{"owner_current":false});return
 var new_rows: Array=[]
 for index: int in range(before_count,host.initial_actions.size()):new_rows.append(host.initial_actions[index].duplicate(true))
 _record(label,{"initial_actions_count":host.initial_actions.size(),"before_count":before_count,"new_receipts":new_rows,"choosing":host.initial_hud.hex_draft.choosing,"view_error":host.initial_hud.hex_draft.error_text,"hud_receipt":host.initial_hud.receipt.duplicate(true),"projection":host.initial_hud.projection.duplicate(true),"model":host.shop_session.ledger.model.snapshot(),"owner_current":true})

func _press_original_hex() -> bool:
 phase_label="original_hex_slot1"
 if not _identity():_stop("original_owner_changed");return false
 var button: Button=host.initial_hud.hex_draft.cards[0].select
 if not is_instance_valid(button) or not button.is_visible_in_tree() or button.disabled or host.initial_hud.hex_draft.choosing:_stop("original_hex_slot1_button_unavailable");return false
 var count: int=host.initial_actions.size()
 var before: Dictionary=host.shop_session.ledger.model.snapshot()
 var milestone: int=int(host.initial_controller.active_milestone)
 var offered: String=str(before.offers[str(milestone)].slots[0])
 var rect: Rect2=button.get_global_rect()
 _hex_trace("hex_before_signal",count)
 button.pressed.emit()
 _record("hex_single_synthetic_signal",{"slot":0,"milestone":milestone,"offered_id":offered,"rect_position":[rect.position.x,rect.position.y],"rect_size":[rect.size.x,rect.size.y],"synthetic_button_signal":true,"native_hit_test_proven":false})
 _hex_trace("hex_immediately_after_signal",count)
 # Original _choose awaits its own0.24s commitment flash before selected.emit.
 # No retry, direct selected signal, adapter request or state mutation.
 var receipt_deadline: int=mini(started+SOFT_MS,Time.get_ticks_msec()+3000)
 while Time.get_ticks_msec()<receipt_deadline:
  if not _identity():_stop("original_owner_changed");return false
  if host.initial_actions.size()>count+1:break
  if host.initial_actions.size()==count+1 and not host.initial_hud.hex_draft.choosing:break
  if not await _frame():return false
 if not _identity():_stop("original_owner_changed_after_hex_wait");return false
 if not _budget() or Time.get_ticks_msec()>=receipt_deadline:_stop("original_hex_commit_deadline");return false
 _hex_trace("hex_after_original_commit_wait",count)
 if host.initial_actions.size()!=count+1 or host.initial_hud.hex_draft.choosing:_stop("original_hex_slot1_exact_receipt_required");return false
 var receipt: Dictionary=host.initial_actions.back().duplicate(true)
 var request: Dictionary=receipt.get("request",{})
 if request.get("action")!="hex_select" or int(request.get("slot",-1))!=0 or int(request.get("milestone",-1))!=milestone:_stop("original_hex_slot1_receipt_identity_mismatch");return false
 if not receipt.get("result",{}).get("accepted",false):_stop("original_hex_slot1_original_business_rejected");return false
 var state: Dictionary=host.shop_session.ledger.model.snapshot()
 if state.selected_hex!=[offered] or not state.pending_milestones.is_empty() or state.points!=1:_stop("original_hex_choice_projection_mismatch");return false
 if not _budget() or Time.get_ticks_msec()>=receipt_deadline:_stop("original_hex_commit_deadline");return false
 return true

func _press(button: Button, label: String) -> bool:
 phase_label=label
 if not _identity():_stop("original_owner_changed");return false
 if not is_instance_valid(button) or not button.is_visible_in_tree() or button.disabled:
  _record(label,{"accepted":false,"reason":"visible_enabled_button_required"});_stop(label+"_button_unavailable");return false
 var count: int=host.initial_actions.size()
 var rect: Rect2=button.get_global_rect()
 button.pressed.emit()
 if host.initial_actions.size()!=count+1:_stop(label+"_exact_receipt_required");return false
 var receipt: Dictionary=host.initial_actions.back().duplicate(true)
 _record(label,{"receipt":receipt,"button_text":button.text,"rect_position":[rect.position.x,rect.position.y],"rect_size":[rect.size.x,rect.size.y],"synthetic_button_signal":true,"native_hit_test_proven":false})
 if not receipt.get("result",{}).get("accepted",false):_stop(label+"_original_business_rejected");return false
 return true

func _key_k() -> void:
 _key(KEY_K)

func _key(code: int) -> void:
 for down: bool in [true,false]:
  var event:=InputEventKey.new();event.physical_keycode=code;event.pressed=down
  host._input(event)
 _record("original_host_key",{"physical_keycode":code,"synthetic_host_input":true,"native_device_proven":false})


func _ui_buttons() -> Dictionary:
 var out: Dictionary={"growth":host.growth_toggle,"next":host.session_next,"service":host.service_continue,"shop_open":host.shop_open_button,"return":entry.return_button,"resume":entry.chooser.resume_button,"learn_Q1":host.initial_hud.q_choices.Q1.upgrade}
 for key: String in UIReadback.growth_buttons(host): out["growth_original_"+key]=UIReadback.growth_buttons(host)[key]
 for child: Node in host.hud.get_children():
  if child is Button:
   if child.text.begins_with("商店"):out["hud_shop"]=child
   elif child.text.begins_with("诊断"):out["hud_diagnostics"]=child
   elif child.text.begins_with("退出"):out["hud_exit"]=child
 return out

func _ui_connection_state() -> Dictionary:
 var out: Dictionary={}
 for key: String in _ui_buttons():
  var button: Variant=_ui_buttons()[key]
  if not is_instance_valid(button) or not button is Button:out[key]={"valid":false};continue
  var connections: Array=[]
  for row: Dictionary in button.get_signal_connection_list("pressed"):
   var callback: Callable=row.callable
   var target: Object=callback.get_object()
   connections.append({"target_id":target.get_instance_id() if is_instance_valid(target) else 0,"method":str(callback.get_method()),"flags":row.flags})
  out[key]={"node_id":button.get_instance_id(),"connections":connections}
 return out

func _ui_observe(label: String) -> bool:
 if not _identity():_stop("ui_owner_changed:"+label);return false
 var row: Dictionary=UIReadback.sample(host,entry)
 row["probe_label"]=label
 row["same_original_owner"]=true
 # Check the actual postdraw text against the last UI projection, without
 # calling present or waiting extra frames to conceal a late Host overwrite.
 var projected: Dictionary=entry._trial_ui._projected
 var labels: Dictionary={"header":host.session_header,"hint":host.session_hint,"equipment":host.session_equipment,"footer":host.hud.footer,"buffs":host.hud.buffs}
 var matches: Dictionary={}
 var mismatch: String=""
 for key: String in labels:
  var actual: String=labels[key].text
  var expected: String=str(projected.get(key,""))
  var equal: bool=projected.has(key) and actual==expected
  matches[key]={"equal":equal,"projected_exists":projected.has(key),"actual_sha256":actual.sha256_text(),"projected_sha256":expected.sha256_text()}
  if not equal and mismatch.is_empty():mismatch=key
 row["same_draw_projection_text"]=matches
 _record("ui:"+label,row)
 if entry.screen==ENTRY_RUN and not mismatch.is_empty():_stop("ui_projection_overwritten:"+label+":"+mismatch);return false
 var diagnostic: Node=host.session_canvas.get_node_or_null("TrialF1Diagnostics")
 var backing: Node=host.session_hint.get_parent().get_node_or_null("TrialLiveHintBacking")
 if not is_instance_valid(diagnostic) or not is_instance_valid(backing):_stop("ui_display_nodes_missing:"+label);return false
 if host.hud.diag.visible or (is_instance_valid(host.h02_label) and host.h02_label.get_parent().visible):_stop("old_diagnostic_still_visible:"+label);return false
 if backing.mouse_filter!=Control.MOUSE_FILTER_IGNORE:_stop("hint_backing_blocks_input");return false
 var modal: bool=host.shop_session.panel_open or host.shop_session.initial_modal_open
 if entry.screen==ENTRY_RUN:
  if entry.return_button.visible==modal or diagnostic.visible!=(host.diagnostic and not modal):_stop("ui_modal_or_diagnostic_visibility:"+label);return false
  if backing.visible!=host.session_hint.visible:_stop("ui_hint_backing_residual:"+label);return false
  if modal and (backing.visible or host.session_hint.visible):_stop("ui_modal_hint_leaked:"+label);return false
  var expected_map: bool=host.map_visible_requested and host.shop_session.status!="combat" and not modal
  if host.route_map.is_visible_in_tree()!=expected_map:_stop("map_request_visibility_mismatch:"+label);return false
  if host.shop_session.status=="preparation" and not modal and host.initial_hud.growth_panel.is_visible_in_tree()!=host.growth_open_requested:_stop("growth_request_visibility_mismatch:"+label);return false
 if entry.screen==ENTRY_RUN and not _growth_copy_observe(label):return false
 var current: Dictionary=_ui_connection_state()
 if ui_connections.is_empty():ui_connections=current
 elif current!=ui_connections:_stop("ui_original_button_or_connection_changed:"+label);return false
 return true

# Independent whitelist oracle: all non-development text must survive exactly.
func _expected_growth_copy(candidate: String, raw: String) -> String:
 var expected: String=raw
 for pair: Array in [
  ["；H11/H12未开放。临时显示","；相关强化尚未开放。"],
  ["。临时显示","。"],
  ["；H09/H10均未开放。临时功能显示，最终美术和音效未完成。","；相关强化尚未开放。"],
  ["；H11/H12均未开放。临时功能圆与文字；最终美术与音效未完成。","；相关强化尚未开放。"],
  ["基础"+candidate+"已接入；美术与音效未完成。",""],
  ["基础"+candidate+"已接入；美术与音效尚未全部完成。",""]
 ]: expected=expected.replace(str(pair[0]),str(pair[1]))
 return expected

func _growth_copy_observe(label: String) -> bool:
 var presenter: RefCounted=entry._trial_ui
 var source: Dictionary=presenter._original
 var projected: Dictionary=presenter._projected
 var f1: Label=presenter._diagnostics_text
 if not is_instance_valid(f1):_stop("growth_F1_label_missing:"+label);return false
 var expected_hints: Dictionary={"E2":"E朝鼠标发舟，松开后再E登舟。触边停留，按原时间消散；落点站不下就保留原船。", "E3":"E放A，松开后5秒内再E放B。只移动的敌人受伤，近高远低；相关强化尚未开放。"}
 var model: RefCounted=host.shop_session.ledger.model
 # Read only the real Model's admitted hooks and source definitions, never seed
 # availability or call a presentation/selection method to make this pass.
 for number: int in range(9,13):
  var hex_id: String="yanguizhou_h%02d" % number
  var required_hook: String="hex.final_design."+hex_id+".v1"
  if not model.config.hexes.has(hex_id) or required_hook not in model.config.hexes[hex_id].get("required_hooks",[]) or required_hook in model.supported_hooks:
   _stop("growth_unavailable_copy_not_authoritative:"+hex_id+":"+label);return false
 var results: Dictionary={}
 for pair: Array in [["E2",host.initial_hud.e2_rule_hint,host.initial_hud.e2_choice],["E3",host.initial_hud.e3_rule_hint,host.initial_hud.e3_choice]]:
  var candidate: String=str(pair[0])
  var hint: Label=pair[1]
  var button: Button=pair[2]
  if hint.text!=str(expected_hints[candidate]):_stop("growth_exact_rule_hint_changed:"+candidate+":"+label);return false
  for field: Array in [["hint",hint.text],["tooltip",button.tooltip_text],["hint_tooltip",hint.tooltip_text]]:
   var key: String="growth_"+candidate+"_"+str(field[0])
   var actual: String=str(field[1])
   var raw: String=str(source.get(key,""))
   var expected: String=_expected_growth_copy(candidate,raw)
   var in_f1: bool=raw.is_empty() or f1.text.contains(raw)
   var equal: bool=source.has(key) and projected.has(key) and actual==expected and actual==str(projected[key])
   var leaked: bool=false
   for marker: String in ["临时显示","H09/H10","H11/H12","美术与音效未完成","美术与音效尚未全部完成","最终美术"]:
    if actual.contains(marker):leaked=true
   results[key]={"exact_whitelist_match":equal,"full_original_in_F1":in_f1,"developer_clause_leaked":leaked,"actual":actual,"original_sha256":raw.sha256_text(),"original_empty":raw.is_empty()}
   if not equal or not in_f1 or leaked:
    _record("growth_copy_failure:"+label,results);_stop("growth_copy_or_F1_retention_failed:"+key+":"+label);return false
 _record("growth_copy:"+label,{"fields":results,"diagnostic_visible":presenter._diagnostics.visible,"F1_flag":host.diagnostic,"original_button_captions_permissions_and_signals_untouched":true})
 ui_covered["growth_E2_E3_copy_and_F1_originals"]="OBSERVED_SIX_ACTUAL_FIELDS_EXACT_WHITELIST_AND_FULL_ORIGINAL_TEXT_RETENTION"
 return true

func _visible_button_signal(button: Button, label: String) -> bool:
 if not _identity() or not is_instance_valid(button) or not button.is_visible_in_tree() or button.disabled:_stop("ui_button_unavailable:"+label);return false
 var rect: Rect2=button.get_global_rect()
 _record("ui_button:"+label,{"id":button.get_instance_id(),"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"synthetic_button_signal":true,"native_hit_test_proven":false})
 button.pressed.emit()
 return true

func _growth_reachability() -> bool:
 phase_label="actual_growth_expansion_and_reachability"
 if not _identity():_stop("growth_owner_changed");return false
 # Explicitly reopen through the actual original toggle. Never force visible,
 # change disabled, reparent controls, or emit any skill button here.
 if host.initial_hud.growth_panel.is_visible_in_tree():
  if not _visible_button_signal(host.growth_toggle,"growth_close_before_reopen"):return false
  if not await _frame():return false
  if host.initial_hud.growth_panel.is_visible_in_tree():_stop("growth_original_toggle_did_not_close");return false
 if not _visible_button_signal(host.growth_toggle,"growth_explicit_open"):return false
 if not await _frame():return false
 if not host.initial_hud.growth_panel.is_visible_in_tree():_stop("growth_original_toggle_did_not_open");return false
 if not await _capture("00_growth_expanded.png"):return false
 if not _ui_observe("growth_expanded"):return false
 var sample: Dictionary=UIReadback.growth_sample(host)
 _record("growth_actual_geometry",sample)
 if int(sample.get("button_count",0))!=13:_stop("growth_13_original_buttons_required");return false
 for key: String in sample.buttons:
  var row: Dictionary=sample.buttons[key]
  if not row.get("valid",false) or not row.get("fully_visible_rect",false):
   _stop("growth_button_not_reachable_without_scrolling:"+key);return false
 var before: Dictionary=host.shop_session.ledger.model.snapshot()
 var targets: Dictionary=UIReadback.growth_buttons(host)
 var hover_count: int=0
 var disabled_geometry_only: Array=[]
 # Pure motion goes through the real Viewport GUI dispatcher. No click is
 # generated. Disabled controls keep their original business permission.
 root.notify_mouse_entered()
 for key: String in targets:
  var button: Button=targets[key]
  if button.disabled:disabled_geometry_only.append(key);continue
  if not _identity() or not button.is_visible_in_tree():_stop("growth_hover_owner_or_button_lost");return false
  var rect: Rect2=button.get_global_rect()
  var event:=InputEventMouseMotion.new()
  event.position=rect.get_center();event.global_position=event.position
  root.push_input(event,true)
  if not await _frame():return false
  var hovered: Control=root.gui_get_hovered_control()
  var matched: bool=is_instance_valid(hovered) and (hovered==button or button.is_ancestor_of(hovered))
  _record("growth_GUI_hover:"+key,{"button_id":button.get_instance_id(),"disabled":button.disabled,"point":[event.position.x,event.position.y],"hovered_id":hovered.get_instance_id() if is_instance_valid(hovered) else 0,"hovered_path":str(hovered.get_path()) if is_instance_valid(hovered) else "","matched":matched,"synthetic_viewport_motion":true,"native_OS_input_proven":false})
  if not matched:_stop("growth_original_button_GUI_occluded:"+key);return false
  hover_count+=1
 var after: Dictionary=host.shop_session.ledger.model.snapshot()
 for key: String in ["points","skills","gold","xp","level","inventory","body","selected_hex","pending_milestones"]:
  if before.get(key)!=after.get(key):_stop("growth_hover_changed_progression:"+key);return false
 if not _ui_observe("growth_after_hover_checks"):return false
 ui_covered["growth_13_original_button_geometry"]="OBSERVED_FULLY_IN_VIEWPORT_AND_ANCESTOR_CLIPS"
 ui_covered["growth_enabled_GUI_hover_targets"]={"count":hover_count,"synthetic_viewport_motion":true,"native_OS_input_proven":false,"disabled_controls_geometry_only":disabled_geometry_only}
 return true

func _ui_roundtrip() -> bool:
 phase_label="original_UI_roundtrips"
 if not _ui_observe("before_roundtrips"):return false
 var original_map: bool=host.map_visible_requested
 var original_growth: bool=host.growth_open_requested
 var original_pause: bool=host.sim.paused
 var original_debug: bool=host.diagnostic
 var baseline: Dictionary=host.shop_session.ledger.model.snapshot()
 for code: int in [KEY_M,KEY_K,KEY_F1]:
  _key(code)
  if not await _frame() or not _ui_observe("toggle_open:"+str(code)):return false
  if code==KEY_M and host.map_visible_requested==original_map:_stop("M_request_did_not_toggle");return false
  if code==KEY_K and host.growth_open_requested==original_growth:_stop("K_request_did_not_toggle");return false
  if code==KEY_F1 and host.diagnostic==original_debug:_stop("F1_request_did_not_toggle");return false
  _key(code)
  if not await _frame() or not _ui_observe("toggle_restored:"+str(code)):return false
  if host.map_visible_requested!=original_map or host.growth_open_requested!=original_growth or host.diagnostic!=original_debug:_stop("UI_request_not_restored");return false
 ui_covered["M_K_F1_and_original_callbacks"]="OBSERVED_TWO_WAY_POSTDRAW"
 # Exercise the original safe preparation shop. It may change its own visit
 # bookkeeping; no buy/undo/commit command is issued and no ledger is written here.
 _key(KEY_P)
 if not await _frame() or not _ui_observe("shop_modal_open"):return false
 if not host.shop_session.panel_open or entry.return_button.is_visible_in_tree():_stop("safe_shop_modal_not_open");return false
 _key(KEY_P)
 if not await _frame() or not _ui_observe("shop_modal_closed"):return false
 if host.shop_session.panel_open or not entry.return_button.is_visible_in_tree() or host.sim.paused!=original_pause:_stop("safe_shop_modal_not_restored");return false
 ui_covered["P_shop_modal"]="OBSERVED_OPEN_CLOSE"
 _key(KEY_SPACE)
 if not await _frame() or not _ui_observe("Space_toggle"):return false
 if host.sim.paused==original_pause:_stop("Space_pause_did_not_toggle");return false
 if host.sim.paused and (not host.session_header.text.contains("已暂停") or not host.session_hint.is_visible_in_tree()):_stop("pause_status_not_visible");return false
 _key(KEY_SPACE)
 if not await _frame() or not _ui_observe("Space_restored"):return false
 if host.sim.paused!=original_pause:_stop("Space_pause_not_restored");return false
 ui_covered["Space_pause_status"]="OBSERVED_PREPARATION_ONLY"
 if not _visible_button_signal(entry.return_button,"choose_hero"):return false
 var suspend_deadline: int=mini(started+SOFT_MS,Time.get_ticks_msec()+3000)
 while entry.screen!=ENTRY_CHOOSER and Time.get_ticks_msec()<suspend_deadline:
  if not await _frame():return false
 if entry.screen!=ENTRY_CHOOSER or not host.sim.paused or host.visible or host.process_mode!=Node.PROCESS_MODE_DISABLED:_stop("chooser_suspend_not_established");return false
 var paused_time: float=host.sim.hero_time
 if not await _frame() or not await _frame():return false
 if not _identity() or host.sim.hero_time!=paused_time:_stop("chooser_suspended_owner_or_clock_changed");return false
 if not _ui_observe("chooser_suspended"):return false
 if not _visible_button_signal(entry.chooser.resume_button,"resume_original_run"):return false
 if not await _frame() or not _ui_observe("chooser_resumed"):return false
 if entry.screen!=ENTRY_RUN or not host.is_visible_in_tree() or host.sim.paused!=original_pause:_stop("chooser_resume_not_restored");return false
 var after: Dictionary=host.shop_session.ledger.model.snapshot()
 for key: String in ["points","skills","gold","xp","level","inventory","body","selected_hex","pending_milestones"]:
  if after.get(key)!=baseline.get(key):_stop("UI_roundtrip_progression_changed:"+key);return false
 if host.map_visible_requested!=original_map or host.growth_open_requested!=original_growth:_stop("UI_final_requests_changed");return false
 ui_covered["chooser_suspend_resume_same_objects"]="OBSERVED"
 return true

func _save_json(name: String, value: Dictionary) -> bool:
 if not _budget():return false
 var bytes: PackedByteArray=(JSON.stringify(value,"  ")+"\n").to_utf8_buffer()
 var file:=FileAccess.open(output.path_join(name),FileAccess.WRITE)
 if file==null:return false
 file.store_buffer(bytes);file.flush();var error: Error=file.get_error();file.close()
 return error==OK and FileAccess.get_file_as_bytes(output.path_join(name))==bytes and _budget()

func _same_objects() -> bool:
 return not owner_ids.is_empty() and is_instance_valid(entry) and is_instance_valid(host) and entry.active_room==host and host.get_instance_id()==owner_ids.host and is_instance_valid(host.sim) and host.sim.get_instance_id()==owner_ids.sim and is_instance_valid(owner_hero) and is_same(host.sim.hero,owner_hero) and host.shop_session!=null and host.shop_session.get_instance_id()==owner_ids.session and host.shop_session.ledger.model.get_instance_id()==owner_ids.model and host.shop_session._owner_intact()

func _enter_route_node(row: int, node_id: String) -> bool:
 phase_label="enter:"+node_id
 if not _identity():_stop("route_owner_changed_before_entry");return false
 var old_room: String=host.sim.room_id
 var old_generation: int=host.sim.encounter_generation
 driver.release_between_nodes()
 var receipt: Dictionary
 if row==1:
  host._select_row(row,node_id)
  if not host.shop_session.last_receipt.get("accepted",false):_stop("initial_route_selection_failed");return false
  host._request_next_room();receipt=host.shop_session.last_receipt.duplicate(true)
 else:
  # Existing driver handles only legal visible WASD if original entry preflight
  # reports hero_too_close_to_next_spawn; never edits position or future enemies.
  receipt=await driver.prepare_next_original_node(row,node_id,false)
 if not _same_objects():_stop("route_objects_replaced");return false
 _record("original_node_entry",{"row":row,"node":node_id,"receipt":receipt,"old_room":old_room,"old_generation":old_generation,"new_room":host.sim.room_id,"new_generation":host.sim.encounter_generation})
 if not receipt.get("accepted",false):_stop("original_node_entry_rejected");return false
 var actual: Dictionary=host.shop_session._active_entry
 if actual.get("identity",{}).get("node_id","")!=node_id:_stop("original_entry_node_mismatch");return false
 if row<3:
  if host.shop_session.status!="combat" or host.sim.encounter_generation!=old_generation+1 or host.sim.room_id==old_room or actual.get("payload",{}).get("room_id","")!=host.sim.room_id:_stop("original_combat_scope_mismatch");return false
 else:
  if not host.shop_session._entered_service("rest") or host.sim.encounter_generation!=old_generation or host.sim.room_id!=old_room:_stop("service_must_not_begin_encounter");return false
 # Expected scope advances only after exact original accepted entry and the
 # same Host/Sim/Hero/Session/Model objects have been checked.
 owner_ids.room_id=host.sim.room_id;owner_ids.generation=host.sim.encounter_generation
 if not _budget():_stop("route_entry_deadline");return false
 return true

func _finish() -> void:
 if finishing or final_emitted:return
 if driver!=null and _identity():
  driver.release_between_nodes()
  _record("route_driver",{"receipts":driver.receipts.duplicate(true),"visibility_checks":driver.visibility_log.size(),"failure":driver.failure})
 if is_instance_valid(observer):_record("final_observer",observer.snapshot())
 phase_label="finish_after:"+phase_label
 finishing=true;finish_deadline=mini(started+WALL_MS,Time.get_ticks_msec()+FINISH_MS)
 while _identity() and host.initial_hud.hex_draft.choosing and _budget():
  await process_frame
  if final_emitted:return
 var released: bool=not is_instance_valid(entry)
 if is_instance_valid(host):
  if not _identity():_stop("finish_owner_changed_no_unsafe_free")
  elif host.initial_hud.hex_draft.choosing:_stop("hex_commit_not_joined_no_unsafe_free")
  elif host._mainprep_pending or host._mainprep_required:_stop("startup_not_joined_no_unsafe_free")
  elif host.frontdoor_close_run("worldfx_ui_probe_complete"):
   _record("original_safe_close",host.frontdoor_last_close)
   entry.queue_free()
  else:_stop("original_safe_close_rejected")
 elif is_instance_valid(entry) and not is_instance_valid(entry.active_room):entry.queue_free()
 await process_frame
 if final_emitted:return
 await process_frame
 if final_emitted:return
 released=not is_instance_valid(entry)
 if not released:_stop("original_entry_not_released")
 if is_instance_valid(observer):observer.queue_free()
 var io_ok: bool=output_owned and _budget()
 if io_ok:
  for shot: Dictionary in shots:
   if not _budget():io_ok=false;break
   if shot.image.save_png(output.path_join(shot.name))!=OK or not FileAccess.file_exists(output.path_join(shot.name)):io_ok=false;break
   var readback: Image=Image.load_from_file(output.path_join(shot.name))
   if readback==null or readback.is_empty() or readback.get_size()!=shot.image.get_size():io_ok=false;break
  if io_ok:io_ok=_save_json("observations.json",{"rows":observations,"synthetic_input":true})
 var report: Dictionary={"accepted":covered and stopped.is_empty() and released,"reason":stopped,"source_released":released,"synthetic_visible_buttons_and_route_inputs":true,"native_hit_test_proven":false,"coverage":"real_first_room_first_Q1_release_worldFX_listener_legacy_hide_two_source_times_plus_UI_roundtrips","ui_observed":ui_covered.duplicate(true),"ui_native_hit_test":"NATIVE_OS_NOT_EXERCISED; enabled growth controls use observed synthetic Viewport GUI hover","UI_terminal_states":"NOT_REACHED","UI_real_error_state":"NOT_INJECTED_OR_OBSERVED","shader_clock_tolerance":0.00001,"all_skill_branches":"NOT_OBSERVED","curved_gesture":"NOT_EXERCISED_BY_STRAIGHT_ROUTE_DRIVER","art_acceptance":"NOT_REVIEWED","source_state_seeded":false,"elapsed_ms":Time.get_ticks_msec()-started,"images":shots.size(),"failure_diagnostics":failure_diagnostics.duplicate(true),"first_release":_event_brief(first_release),"visual_samples":visual_samples.duplicate(true)}
 if io_ok:io_ok=_save_json("report.json",report)
 if not _budget():io_ok=false;report.accepted=false;report.reason="finish_deadline"
 final_emitted=true
 print("WORLD_FX_UI_PROBE_FINAL ",JSON.stringify({"accepted":report.accepted,"io_ok":io_ok,"reason":report.reason,"source_released":released}))
 quit(0 if report.accepted and io_ok else 4)

