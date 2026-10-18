extends SceneTree
## Visible original-HUD/route input smoke. No state seeds or simulated combat events.
const WALL_MS: int = 180000
const SOFT_MS: int = 170000
const FINISH_MS: int = 5000
const BINDING_PATH = "res://yan_worldfx_smoke_20261018/binding.json"
const BINDING_SHA = "b043a40ccfc2bcf5d9d4907ac7879602712df2a202cf3aa2148a8e38e3bc858d"
const RouteDriver = preload("res://natural_route_replay_prepare/visible_route_replay.gd")
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

func _initialize() -> void:
 started = Time.get_ticks_msec()
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--worldfx-evidence="): output = arg.trim_prefix("--worldfx-evidence=")
 call_deferred("_run")

func _process(_delta: float) -> bool:
 if final_emitted: return false
 if not _budget():
  final_emitted = true
  print("WORLD_FX_SMOKE_FINAL ", JSON.stringify({"accepted":false,"io_ok":false,"reason":"absolute_deadline","source_released":false}))
  quit(4)
 elif not finishing and Time.get_ticks_msec()-started >= SOFT_MS: _stop("soft_deadline")
 return false

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
 var result: Dictionary = {"source_hero_time":host.sim.hero_time,"source_phase":host.sim.phase,"wave_id":str(first_release.get("wave_id","")),"legacy_q1_visible":host.q1_view.visible,"controller_counter":worldfx.observed_events,"layers":[]}
 var key: String = result.wave_id
 var drawn: Dictionary = worldfx.q1._drawn
 result["drawn_keys"] = drawn.keys()
 if not drawn.has(key): return result
 for node: MeshInstance3D in drawn[key]:
  var material: ShaderMaterial = node.material_override
  var arrays: Array = node.mesh.surface_get_arrays(0)
  result.layers.append({"node_id":node.get_instance_id(),"mesh_id":node.mesh.get_instance_id(),"visible":node.is_visible_in_tree(),"geometry_sha256":var_to_bytes(arrays).hex_encode().sha256_text(),"age":material.get_shader_parameter("age"),"front_distance":material.get_shader_parameter("front_distance"),"shader_path":material.shader.resource_path})
 return result

func _capture(name: String, river: bool = false) -> bool:
 if shots.size() >= 3 or not await _frame(): return false
 if not _identity(): _stop("capture_owner_changed"); return false
 if river:
  var sample: Dictionary = _visual_sample()
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
 if not await _press_original_hex(): return
 if not await _frame(): return
 state = host.shop_session.ledger.model.snapshot()
 if not state.pending_milestones.is_empty() or state.points != 1: _stop("original_hex_not_settled"); return
 if not host.initial_hud.growth_panel.is_visible_in_tree():
  _key_k()
  if not await _frame(): return
 if not _press(host.initial_hud.q_choices.Q1.upgrade,"learn_Q1"): return
 if not await _frame(): return
 var q: Dictionary = _sample("learned_Q1")
 if q.is_empty(): return
 if q.points != 0 or q.skills.Q != {"candidate":"Q1","rank":1} or q.hero_q != "q1" or q.hero_q_rank != 1: _stop("Q1_model_hero_projection_failed"); return
 if host.initial_hud.growth_panel.is_visible_in_tree(): _key_k()
 driver = RouteDriver.new(); driver.bind_existing(host,started+SOFT_MS)
 if not await _enter_route_node(1,"r01a"): return
 if not await _capture("00_first_room.png"): return
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
 var milestone: int=int(host.initial_hud.projection.get("active_milestone",0))
 var choice: Dictionary=host.initial_hud.projection.choices[0].duplicate(true)
 var rect: Rect2=button.get_global_rect()
 _hex_trace("hex_before_signal",count)
 button.pressed.emit()
 _record("hex_single_synthetic_signal",{"slot":0,"milestone":milestone,"choice":choice,"rect_position":[rect.position.x,rect.position.y],"rect_size":[rect.size.x,rect.size.y],"synthetic_button_signal":true,"native_hit_test_proven":false})
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
 if state.selected_hex!=[choice.id] or not state.pending_milestones.is_empty() or state.points!=1:_stop("original_hex_choice_projection_mismatch");return false
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
 for down: bool in [true,false]:
  var event:=InputEventKey.new();event.physical_keycode=KEY_K;event.pressed=down
  host._input(event)
 _record("original_K_input",{"synthetic_host_input":true})

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
  elif host.frontdoor_close_run("worldfx_first_release_smoke_complete"):
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
 var report: Dictionary={"accepted":covered and stopped.is_empty() and released,"reason":stopped,"source_released":released,"synthetic_visible_buttons_and_route_inputs":true,"native_hit_test_proven":false,"coverage":"real_first_room_first_Q1_release_worldFX_listener_legacy_hide_two_source_times","all_skill_branches":"NOT_OBSERVED","curved_gesture":"NOT_EXERCISED_BY_STRAIGHT_ROUTE_DRIVER","art_acceptance":"NOT_REVIEWED","source_state_seeded":false,"elapsed_ms":Time.get_ticks_msec()-started,"images":shots.size(),"failure_diagnostics":failure_diagnostics.duplicate(true),"first_release":_event_brief(first_release),"visual_samples":visual_samples.duplicate(true)}
 if io_ok:io_ok=_save_json("report.json",report)
 if not _budget():io_ok=false;report.accepted=false;report.reason="finish_deadline"
 final_emitted=true
 print("WORLD_FX_SMOKE_FINAL ",JSON.stringify({"accepted":report.accepted,"io_ok":io_ok,"reason":report.reason,"source_released":released}))
 quit(0 if report.accepted and io_ok else 4)

