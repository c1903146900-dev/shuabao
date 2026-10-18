extends SceneTree
# REIMPLEMENTATION. Synthetic visible-button input; no gameplay state writes.
const BINDING = "res://yan_p3_earned_20261018b/binding.json"
const BINDING_SHA = "ec028d600629237809483cc51bb0cce0633bfa18b12bb8a0258a7c12eadd44c1"
const Driver = preload("res://yan_p3_earned_20261018b/survival_driver.gd")
const Tuning = preload("res://tests/ink_q1_foundation_20261004/revision02/scripts/ink_tuning.gd")
var driver
var observing_p3: bool = false
var release_cursor: int = 0
var release_ids: Dictionary = {}
var release_base_serial: int = 0
var release_epoch: int = 0
var q_count_seen: int = 0
var event_sequence: int = 0
var last_health_time: float = -1.0
var coverage: Dictionary = {"earned_P3":"NOT_REACHED","successful_Q1":"NOT_REACHED","threshold_refund":"NOT_REACHED","cross_room_nonzero":"NOT_REACHED","rest_retention":"NOT_REACHED","death_reset":"NOT_OBSERVED"}
var started: int
var deadline: int
var evidence: String = ""
var entry: Node
var host: Node
var sim: Node
var session: RefCounted
var model: RefCounted
var hero: Object
var room: String
var generation: int
var phase: String = "boot"
var reason: String = ""
var observations: Array = []
var screenshots: Array = []
var image_bytes: int = 0
var finishing: bool = false
var completed: bool = false
var released: bool = false
var draw_count: int = 0
var watchdog_fired: bool = false

func _initialize() -> void:
 started = Time.get_ticks_msec()
 deadline = started + 360000
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--p3-evidence="): evidence = argument.trim_prefix("--p3-evidence=")
 process_frame.connect(_wall_watchdog)
 call_deferred("_run")

func _wall_watchdog() -> void:
 if Time.get_ticks_msec() >= deadline: _watchdog_exit("absolute_360s_deadline")

func _watchdog_exit(why: String = "independent_350s_watchdog") -> void:
 if watchdog_fired: return
 watchdog_fired = true
 completed = false
 finishing = true
 reason = why
 # Independent signal callback survives a failed _run coroutine. No second finish.
 var diagnostic: Dictionary = {"accepted":false,"reason":why,"phase":phase,"elapsed_ms":Time.get_ticks_msec()-started,"source_released":released,"draw_count":draw_count}
 if not evidence.is_empty():
  if screenshots.size()<3 and Time.get_ticks_msec()<deadline: _picture("watchdog_failure",true)
  _json("watchdog.json",diagnostic)
  _json("observations.json",observations)
  _json("report.json",diagnostic)
 print("P3_REIMPLEMENTATION_EARNED_WATCHDOG ",JSON.stringify(diagnostic))
 quit(4)

func _budget() -> bool:
 return not watchdog_fired and Time.get_ticks_msec() < deadline - (0 if finishing else 10000)

func _frame() -> void:
 await process_frame
 await RenderingServer.frame_post_draw
 draw_count += 1

func _identity() -> bool:
 return is_instance_valid(entry) and is_instance_valid(host) and is_same(entry.active_room,host) and is_instance_valid(sim) and is_same(host.sim,sim) and is_instance_valid(session) and is_same(host.shop_session,session) and session._owner_intact() and is_same(session.ledger.model,model) and is_instance_valid(hero) and is_same(sim.hero,hero) and sim.room_id == room and sim.encounter_generation == generation

func _available(button: Variant) -> bool:
 return is_instance_valid(button) and button is Button and button.is_visible_in_tree() and not button.disabled

func _sample(label: String) -> Dictionary:
 if not _identity(): return {"accepted":false,"reason":"owner_or_scope_changed"}
 var state: Dictionary = model.snapshot()
 var out: Dictionary = {"accepted":true,"label":label,"phase":phase,"source_time":sim.hero_time,"room_id":room,"generation":generation,"points":state.points,"skills":state.skills.duplicate(true),"allocations":state.allocations.size(),"selected_hex":state.selected_hex.duplicate(),"pending_milestones":state.pending_milestones.duplicate(),"hero_loadout":hero.loadout.duplicate(),"hero_ranks":hero.ranks.duplicate(),"p3":sim.ink_p3.snapshot(),"initial_actions":host.initial_actions.size()}
 observations.append(out.duplicate(true))
 return out

func _diagnose() -> Dictionary:
 var out: Dictionary = {"phase":phase,"reason":reason,"draw_count":draw_count,"elapsed_ms":Time.get_ticks_msec()-started}
 if is_instance_valid(entry):
  out.entry_id = entry.get_instance_id()
  out.entry_room_id = entry.active_room.get_instance_id() if is_instance_valid(entry.active_room) else 0
 if is_instance_valid(host):
  out.host_id = host.get_instance_id()
  var names: Array = []
  for property: Dictionary in host.get_property_list(): names.append(property.name)
  for key: String in ["startup_session_error","floor_error","_mainprep_required","_mainprep_pending","ordinary_visual_installation","ordinary_visual_asset_binding","ordinary_visual_clock_binding","root_return_installation","ultimate_visual_installation","frontdoor_last_close"]:
   if key in names:
    var value: Variant = host.get(key)
    if value is Dictionary or value is Array or value is String or value is bool or value is int: out[key] = value
  out.initial_actions = host.initial_actions.duplicate(true)
  if is_instance_valid(host.hero_view): out.hero_view_proof = host.hero_view.get("proof")
  if is_instance_valid(host.sim):
   out.sim_id = host.sim.get_instance_id()
   out.sim_phase = host.sim.phase
   out.source_time = host.sim.hero_time
 return out

func _json(name: String, value: Variant) -> bool:
 var text: String = JSON.stringify(value,"  ") + "\n"
 var file = FileAccess.open(evidence.path_join(name),FileAccess.WRITE)
 if file == null: return false
 file.store_string(text)
 file.flush()
 var ok: bool = file.get_error() == OK
 file.close()
 return ok and FileAccess.get_file_as_string(evidence.path_join(name)) == text

func _picture(name: String, watchdog_capture: bool = false) -> bool:
 var time_allowed: bool = _budget() or (watchdog_capture and watchdog_fired and Time.get_ticks_msec()<deadline)
 if screenshots.size() >= 3 or not time_allowed or draw_count < 1: return false
 var img: Image = root.get_texture().get_image()
 if img == null or img.is_empty(): return false
 var size: int = img.get_data().size()
 if image_bytes + size > 16*1024*1024: return false
 var path: String = evidence.path_join(name+".png")
 if img.save_png(path) != OK: return false
 if FileAccess.get_file_as_bytes(path).is_empty(): return false
 image_bytes += size
 screenshots.append({"name":name,"sha256":FileAccess.get_sha256(path),"raw_bytes":size})
 return true

func _capture(name: String, expected: Dictionary) -> bool:
 await _frame()
 if not _budget() or not _identity(): return false
 var actual: Dictionary = _sample(name+"_postdraw")
 for key: String in ["points","skills","hero_loadout","hero_ranks","p3","room_id","generation","allocations","selected_hex","pending_milestones"]:
  if actual.get(key) != expected.get(key): return false
 return _picture(name)

func _press(button: Variant, action: String) -> bool:
 if not _budget() or not _identity() or not _available(button): return false
 var count: int = host.initial_actions.size()
 button.pressed.emit()
 if not _identity() or not _budget() or host.initial_actions.size() != count+1: return false
 var receipt: Dictionary = host.initial_actions.back()
 observations.append({"button_action":action,"receipt":receipt.duplicate(true)})
 return receipt.request.action == action and receipt.result.get("accepted",false)

func _hex() -> bool:
 var view = host.initial_hud.hex_draft
 if not _identity() or view.cards.size()!=4 or not _available(view.cards[0].select): return false
 var before: Dictionary = model.snapshot()
 var milestone: int = int(host.initial_controller.active_milestone)
 var offered: String = before.offers[str(milestone)].slots[0]
 var count: int = host.initial_actions.size()
 var receipt_deadline: int = mini(deadline-10000,Time.get_ticks_msec()+3000)
 observations.append({"hex_before_count":count,"choosing":view.choosing,"offered":offered})
 view.cards[0].select.pressed.emit()
 while _identity() and _budget() and Time.get_ticks_msec()<receipt_deadline and (host.initial_actions.size()==count or view.choosing):
  await _frame()
 if not _identity() or not _budget() or Time.get_ticks_msec()>=receipt_deadline: return false
 observations.append({"hex_after_count":host.initial_actions.size(),"choosing":view.choosing,"receipts":host.initial_actions.slice(count)})
 if host.initial_actions.size()!=count+1 or view.choosing: return false
 var receipt: Dictionary = host.initial_actions.back()
 var state: Dictionary = model.snapshot()
 return receipt.request.action=="hex_select" and receipt.request.get("slot",-1)==0 and receipt.request.get("milestone",-1)==milestone and receipt.result.get("accepted",false) and state.selected_hex==[offered] and state.pending_milestones.is_empty() and state.points==1

func _run() -> void:
 create_timer(350.0,true,false,true).timeout.connect(_watchdog_exit)
 root.size = Vector2i(1280,720)
 if not evidence.is_absolute_path() or DirAccess.dir_exists_absolute(evidence): reason="fresh_absolute_evidence_required"; quit(4); return
 if DirAccess.make_dir_recursive_absolute(evidence)!=OK: quit(4); return
 if FileAccess.get_sha256(BINDING)!=BINDING_SHA: await _stop("binding_changed"); return
 var binding: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BINDING))
 for path: String in binding.files:
  if FileAccess.get_sha256(path)!=binding.files[path]: await _stop("source_pin_changed:"+path); return
 phase="original_entry"
 entry = load("res://scenes/hero_entry.tscn").instantiate()
 root.add_child(entry)
 await _frame()
 entry.request_start("yanguizhou")
 while _budget() and not is_instance_valid(entry.active_room): await _frame()
 if not _budget(): await _stop("entry_not_ready"); return
 host = entry.active_room
 phase="original_mainprep"
 while _budget() and (host._mainprep_required or not host.initial_started):
  if not str(host.startup_session_error).is_empty() or not str(host.floor_error).is_empty(): break
  await _frame()
 if not _budget() or not str(host.startup_session_error).is_empty() or not str(host.floor_error).is_empty(): await _stop("original_startup_failed"); return
 sim=host.sim; session=host.shop_session; model=session.ledger.model; hero=sim.hero; room=sim.room_id; generation=sim.encounter_generation
 phase="original_hex"
 if not await _hex(): await _stop("original_hex_receipt_required"); return
 if not await _earned_route(): await _stop(reason if not reason.is_empty() else "earned_route_failed"); return
 completed=true
 await _finish()

func _stop(why: String) -> void:
 reason=why
 observations.append({"failure":_diagnose()})
 # On failure preserve one actual drawn viewport; do not require established owners.
 if screenshots.size()<3: _picture("failure")
 await _finish()

func _finish() -> void:
 if finishing: return
 finishing=true
 if driver != null and _same_owners():
  driver.release_between_nodes()
  observations.append({"driver_receipts":driver.receipts.duplicate(true),"driver_failure":driver.failure,"coverage":coverage.duplicate(true)})
 var join_deadline: int = mini(deadline,Time.get_ticks_msec()+5000)
 if is_instance_valid(host) and is_instance_valid(host.initial_hud):
  while is_instance_valid(host.initial_hud.hex_draft) and host.initial_hud.hex_draft.choosing and Time.get_ticks_msec()<join_deadline: await _frame()
 if is_instance_valid(host) and _identity() and not host._mainprep_required and Time.get_ticks_msec()<join_deadline:
  var closed: bool = host.frontdoor_close_run("p3_reimplementation_smoke")
  observations.append({"safe_close":closed,"receipt":host.frontdoor_last_close.duplicate(true)})
  if closed:
   entry.queue_free()
   await _frame()
   await _frame()
   released=not is_instance_valid(entry)
 var report: Dictionary = {"accepted":completed and released and _budget(),"reason":reason,"synthetic":true,"scope":"original_r01_earned_P3_r02_Q1_r03_rest","coverage":coverage.duplicate(true),"source_released":released,"elapsed_ms":Time.get_ticks_msec()-started,"draw_count":draw_count,"screenshots":screenshots,"raw_image_bytes":image_bytes}
 var io_ok: bool = _json("observations.json",observations)
 io_ok = _json("report.json",report) and io_ok
 if Time.get_ticks_msec() >= deadline:
  report.accepted = false
  report.reason = "absolute_deadline_after_io"
  io_ok = _json("report.json",report) and io_ok
 print("P3_REIMPLEMENTATION_EARNED_FINAL ",JSON.stringify(report)," IO_OK=",io_ok)
 quit(0 if not watchdog_fired and report.accepted and io_ok and Time.get_ticks_msec() < deadline else 4)

func _same_owners() -> bool:
 return is_instance_valid(entry) and is_instance_valid(host) and is_same(entry.active_room,host) and is_same(host.sim,sim) and is_same(host.shop_session,session) and session._owner_intact() and is_same(session.ledger.model,model) and is_same(sim.hero,hero)

func _adopt_entry(node_id: String, combat: bool) -> bool:
 if not _same_owners(): return false
 var flow: Dictionary = session.snapshot()
 if flow.row_state.get("entry_receipt",{}).get("identity",{}).get("node_id","") != node_id: return false
 if combat:
  if session.status!="combat" or sim.encounter_generation!=generation+1 or not str(sim.room_id).ends_with("/"+node_id): return false
 else:
  if session.status!="service" or sim.encounter_generation!=generation or sim.room_id!=room: return false
 room=sim.room_id;generation=sim.encounter_generation
 return _identity()

func _growth_open() -> bool:
 if not _identity() or not host._learning_panel_allowed(): return false
 if not host.initial_hud.growth_panel.is_visible_in_tree():
  if not _available(host.growth_toggle): return false
  host.growth_toggle.pressed.emit()
 return host.initial_hud.growth_panel.is_visible_in_tree()

func _poll_releases() -> bool:
 if not _identity(): return false
 while release_cursor < sim.ink_p3_receipts.size():
  var receipt: Dictionary = sim.ink_p3_receipts[release_cursor]
  release_cursor+=1
  observations.append({"authenticated_p3_release":receipt.duplicate(true)})
  if not receipt.get("accepted",false) or receipt.family!="q1" or receipt.slot!="q" or receipt.generation!=generation or receipt.room_id!=room or release_ids.has(receipt.identity): return false
  release_ids[receipt.identity]=true
  var threshold: int = sim.ink_p3.threshold()
  var expected_count: int = mini(q_count_seen+1,threshold)
  var expected_refund: float = float(receipt.cd.before)*Tuning.fraction("P3-2",1) if expected_count>=threshold else 0.0
  var pending: bool = expected_count>=threshold and float(receipt.cd.before)<=0.0
  if not is_equal_approx(float(receipt.cd.refunded),expected_refund) or not is_equal_approx(float(receipt.cd.after),float(receipt.cd.before)-expected_refund) or bool(receipt.cd.pending)!=pending: return false
  q_count_seen=0 if expected_refund>0.0 else expected_count
  if receipt.state.counts.q!=q_count_seen or receipt.state.counts.e!=0 or receipt.state.release_serial!=release_base_serial+release_ids.size() or receipt.state.epoch!=release_epoch: return false
  if expected_refund>0.0: coverage.threshold_refund="PASS"
  coverage.successful_Q1="PASS"
 return true

func _record_health() -> void:
 for event: Dictionary in sim.event_log:
  var seq: int = int(event.get("sequence",-1))
  if seq<=event_sequence: continue
  if seq>event_sequence+1: observations.append({"event_gap":{"before":event_sequence,"next":seq,"bounded_source_ring":true}})
  event_sequence=seq
  if event.get("kind","") in ["damage","heal","enemy_impact","encounter_finished"]: observations.append({"health_event":event.duplicate(true)})
 if float(sim.hero_time)-last_health_time>=0.5 or hero.dead:
  last_health_time=sim.hero_time
  observations.append({"health":{"source_time":sim.hero_time,"room":room,"hp":hero.hp,"max_hp":hero.stats.max_hp,"position":hero.position,"dead":hero.dead,"inventory":model.state.inventory.duplicate(true),"flask_charges":model.state.shop_visit.flask_charges,"p3":sim.ink_p3.snapshot()}})

func _combat_until_safe() -> bool:
 while _budget() and _identity():
  driver.advance_inputs()
  await _frame()
  if not _budget() or not _identity(): reason="scope_or_budget_during_combat";return false
  if observing_p3 and not _poll_releases(): reason="p3_release_oracle_failed";return false
  _record_health()
  if hero.dead:
   var dead: Dictionary = _sample("actual_death_core")
   if observing_p3 and q_count_seen>0 and dead.accepted and dead.p3.release_serial==release_base_serial+release_ids.size() and dead.p3.epoch>release_epoch and dead.p3.rank==1 and dead.p3.counts=={"q":0,"e":0} and dead.p3.ready=={"q":false,"e":false}: coverage.death_reset="PASS"
   reason="NOT_REACHED_natural_death_before_route_complete"
   return false
  if session.status!="combat" and model.state.phase=="safe":
   driver.release_between_nodes()
   return true
 reason="NOT_REACHED_combat_deadline_or_scope"
 return false

func _earned_route() -> bool:
 phase="initial_Q1"
 if not _growth_open() or not _press(host.initial_hud.q_choices.Q1.upgrade,"learn"): reason="original_Q1_learning_failed";return false
 var initial: Dictionary = _sample("original_Q1_build")
 if not initial.accepted or initial.points!=0 or initial.skills.Q.rank!=1 or initial.hero_loadout.q!="q1" or initial.hero_ranks.q!=1 or initial.skills.P.rank!=0: reason="initial_Q1_projection_failed";return false
 driver=Driver.new();driver.bind_existing(host,deadline-10000)
 phase="r01a_original_entry"
 host._select_row(1,"r01a")
 if not session.last_receipt.get("accepted",false): reason="original_row1_selection_failed";return false
 host._request_next_room()
 if not session.last_receipt.get("accepted",false) or not _adopt_entry("r01a",true): reason="original_row1_entry_failed";return false
 phase="r01a_earn_SP"
 if not await _combat_until_safe(): return false
 phase="safe_earned_P3"
 if int(model.state.points)<1 or model.state.phase!="safe" or session.status=="combat": reason="NOT_REACHED_safe_earned_point";return false
 var before_points: int = int(model.state.points)
 if not _growth_open() or not _press(host.initial_hud.p3_choice,"learn"): reason="earned_P3_button_failed";return false
 var learned: Dictionary = _sample("earned_P3_learned")
 if not learned.accepted or learned.points!=before_points-1 or learned.skills.P.candidate!="P3" or learned.skills.P.rank!=1 or learned.hero_loadout.passive!="p3" or learned.hero_ranks.passive!=1 or learned.p3.counts!={"q":0,"e":0}: reason="earned_P3_projection_failed";return false
 coverage.earned_P3="PASS"
 release_base_serial=int(learned.p3.release_serial);release_epoch=int(learned.p3.epoch);release_cursor=sim.ink_p3_receipts.size();observing_p3=true
 if not await _capture("01_earned_P3",learned): reason="earned_P3_capture_failed";return false
 if host.initial_hud.growth_panel.is_visible_in_tree() and _available(host.growth_toggle): host.growth_toggle.pressed.emit()
 phase="r02a_original_entry"
 var entered: Dictionary = await driver.prepare_next_original_node(2,"r02a",false)
 observations.append({"r02_entry":entered})
 if not entered.get("accepted",false) or not _adopt_entry("r02a",true): reason="original_row2_entry_failed";return false
 phase="r02a_P3_combat"
 if not await _combat_until_safe(): return false
 var before_rest: Dictionary = _sample("r02_safe_before_rest")
 if not before_rest.accepted or before_rest.p3.counts.q!=q_count_seen or before_rest.p3.release_serial!=release_base_serial+release_ids.size() or before_rest.p3.epoch!=release_epoch: reason="release_to_safe_state_mismatch";return false
 if release_ids.is_empty() or q_count_seen<=0: reason="NOT_REACHED_nonzero_P3_progress_for_retention";return false
 phase="r03a_rest_entry"
 entered=await driver.prepare_next_original_node(3,"r03a",false)
 observations.append({"r03_entry":entered})
 if not entered.get("accepted",false) or not _adopt_entry("r03a",false): reason="original_rest_entry_failed";return false
 var rested: Dictionary = _sample("actual_rest_core")
 if not rested.accepted or rested.p3.counts!=before_rest.p3.counts or rested.p3.ready!=before_rest.p3.ready or rested.p3.rank!=before_rest.p3.rank or rested.p3.epoch!=before_rest.p3.epoch or rested.p3.release_serial!=before_rest.p3.release_serial or rested.p3.cd_reset_serial.q<=before_rest.p3.cd_reset_serial.q or hero.cooldowns.q!=0.0 or hero.cooldowns.e!=0.0: reason="rest_retention_failed";return false
 coverage.cross_room_nonzero="PASS";coverage.rest_retention="PASS"
 if not await _capture("02_rest_retained",rested): reason="rest_capture_failed";return false
 phase="original_rest_continue"
 if not _available(host.service_continue): reason="rest_continue_unavailable";return false
 var input_count: int = host.inputs.size()
 var serial: int = host.session_input_serial
 host.service_continue.pressed.emit()
 if not _identity() or not _budget() or host.inputs.size()!=input_count+1 or host.session_input_serial!=serial+1: reason="rest_continue_receipt_count_failed";return false
 var receipt: Dictionary = host.inputs.back()
 var flow: Dictionary = session.snapshot()
 observations.append({"rest_continue":receipt.duplicate(true),"flow":flow})
 if receipt.category!="normal_floor_ui" or receipt.action!="complete_service" or not receipt.receipt.get("accepted",false) or flow.status!="between_rooms" or not session._service_ready or flow.row_state.get("row_number",0)!=4 or flow.row_state.get("status","")!="awaiting_selection" or flow.row_state.get("completed_rows",[]).size()!=3: reason="rest_continue_not_committed";return false
 return _identity() and _budget()
