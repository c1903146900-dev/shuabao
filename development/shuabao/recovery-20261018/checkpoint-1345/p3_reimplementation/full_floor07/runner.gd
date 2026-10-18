extends SceneTree
# REIMPLEMENTATION. Synthetic visible-button input; no gameplay state writes.
const BINDING = "res://yan_full_floor_20261018b/binding.json"
const BINDING_SHA = "41c68dc417e3bef39fe024623e46267e7c5bdfd9188bb9f52fb1e5cea2282d68"
const Driver = preload("res://yan_full_floor_20261018b/driver.gd")
const Tuning = preload("res://tests/ink_q1_foundation_20261004/revision02/scripts/ink_tuning.gd")
var driver
const ROUTE = ["r01a","r02a","r03a","r04a","r05a","r06a","r07a","r08a","r09a","r10b","r11a","r12boss"]
const SERVICES = [3,4,6,9,11]
var coverage: Dictionary = {"full_floor":"NOT_REACHED","boss_settlement":"NOT_REACHED","completed_floor_ui":"NOT_REACHED","dedicated_settlement_panel":"NOT_IMPLEMENTED","reward_uniqueness":"NOT_REACHED","shop_current_visit_undo":"NOT_REACHED","shop_cross_room_boundary":"NOT_REACHED","rest":"NOT_REACHED","hero_confirmation_cancel":"NOT_REACHED","confirmed_new_hero_run":"NOT_TESTED"}
var event_sequence: int = 0
var last_health_time: float = -1.0
var all_reward_ids: Dictionary = {}
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
 deadline = started + 480000
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--full-floor-evidence="): evidence = argument.trim_prefix("--full-floor-evidence=")
 process_frame.connect(_wall_watchdog)
 call_deferred("_run")

func _wall_watchdog() -> void:
 if Time.get_ticks_msec() >= deadline: _watchdog_exit("absolute_480s_deadline")

func _watchdog_exit(why: String = "independent_470s_watchdog") -> void:
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
 print("YAN_FULL_FLOOR_WATCHDOG ",JSON.stringify(diagnostic))
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
 if text.to_utf8_buffer().size()>32*1024*1024: return false
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

func _hex(slot: int = 1) -> bool:
 var view = host.initial_hud.hex_draft
 if not _identity() or view.cards.size()!=4 or not _available(view.cards[slot].select): return false
 var before: Dictionary = model.snapshot()
 var milestone: int = int(host.initial_controller.active_milestone)
 var offered: String = before.offers[str(milestone)].slots[slot]
 var count: int = host.initial_actions.size()
 var receipt_deadline: int = mini(deadline-10000,Time.get_ticks_msec()+3000)
 observations.append({"hex_before_count":count,"choosing":view.choosing,"offered":offered})
 view.cards[slot].select.pressed.emit()
 while _identity() and _budget() and Time.get_ticks_msec()<receipt_deadline and (host.initial_actions.size()==count or view.choosing):
  await _frame()
 if not _identity() or not _budget() or Time.get_ticks_msec()>=receipt_deadline: return false
 observations.append({"hex_after_count":host.initial_actions.size(),"choosing":view.choosing,"receipts":host.initial_actions.slice(count)})
 if host.initial_actions.size()!=count+1 or view.choosing: return false
 var receipt: Dictionary = host.initial_actions.back()
 var state: Dictionary = model.snapshot()
 return receipt.request.action=="hex_select" and receipt.request.get("slot",-1)==slot and receipt.request.get("milestone",-1)==milestone and receipt.result.get("accepted",false) and state.selected_hex==before.selected_hex+[offered] and not milestone in state.pending_milestones and state.points==before.points

func _run() -> void:
 create_timer(470.0,true,false,true).timeout.connect(_watchdog_exit)
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
 if not await _full_route(): await _stop(reason if not reason.is_empty() else "full_route_failed"); return
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
 var report: Dictionary = {"accepted":completed and released and _budget(),"reason":reason,"synthetic":true,"scope":"original_Q1_build_full_first_floor_and_cancelled_hero_confirmation","coverage":coverage.duplicate(true),"source_released":released,"elapsed_ms":Time.get_ticks_msec()-started,"draw_count":draw_count,"screenshots":screenshots,"raw_image_bytes":image_bytes}
 var io_ok: bool = _json("observations.json",observations)
 io_ok = _json("report.json",report) and io_ok
 if Time.get_ticks_msec() >= deadline:
  report.accepted = false
  report.reason = "absolute_deadline_after_io"
  io_ok = _json("report.json",report) and io_ok
 print("YAN_FULL_FLOOR_FINAL ",JSON.stringify(report)," IO_OK=",io_ok)
 quit(0 if not watchdog_fired and report.accepted and io_ok and Time.get_ticks_msec() < deadline else 4)

func _same_owners() -> bool:
 return is_instance_valid(entry) and is_instance_valid(host) and is_same(entry.active_room,host) and is_same(host.sim,sim) and is_same(host.shop_session,session) and session._owner_intact() and is_same(session.ledger.model,model) and is_same(sim.hero,hero)

func _adopt_entry(node_id: String, combat: bool) -> bool:
 if not _same_owners(): return false
 var flow: Dictionary = session.snapshot()
 if flow.row_state.get("entry_receipt",{}).get("identity",{}).get("node_id","") != node_id: return false
 if combat:
  if session.status!="combat" or sim.encounter_generation!=generation+1 or not str(sim.room_id).ends_with("/"+node_id) or flow.row_state.get("entry_receipt",{}).get("payload",{}).get("room_id","")!=sim.room_id: return false
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

func _resolve_hexes() -> Dictionary:
 driver.release_between_nodes()
 while _identity() and _budget() and not model.snapshot().pending_milestones.is_empty():
  if not host.initial_hud.hex_draft.is_visible_in_tree(): await _frame(); continue
  if not await _hex(1): return {"accepted":false,"reason":"required_visible_async_hex_failed"}
 return {"accepted":_identity() and _budget() and model.snapshot().pending_milestones.is_empty()}

func _completed_ui(label: String) -> bool:
 if not _identity() or not _budget(): return false
 var state: Dictionary=model.snapshot()
 var ui: Dictionary={"label":label,"pending":state.pending_milestones.duplicate(),"hex_visible":host.initial_hud.hex_draft.is_visible_in_tree(),"header_visible":host.session_header.is_visible_in_tree(),"header_text":host.session_header.text,"next_disabled":host.session_next.disabled,"session_status":session.status,"rows":session.snapshot().row_state.completed_rows.size(),"source_time":sim.hero_time,"room_id":sim.room_id,"generation":sim.encounter_generation}
 observations.append({"completed_floor_ui":ui})
 return ui.pending.is_empty() and not ui.hex_visible and ui.header_visible and "12/12" in ui.header_text and "completed" in ui.header_text and ui.next_disabled and ui.session_status=="completed" and ui.rows==12

func _account() -> Dictionary:
 var state: Dictionary = model.snapshot()
 var out: Dictionary = {}
 for key: String in ["gold","xp","level","points","inventory","reward_ids","act_progress","major_floor_events","bonus_awards"]:
  out[key]=state.get(key)
 return out.duplicate(true)

func _record_health() -> void:
 for event: Dictionary in sim.event_log:
  if int(event.get("sequence",0))<=event_sequence: continue
  event_sequence=int(event.sequence)
  if event.get("kind","") in ["damage","heal","enemy_impact","encounter_finished","kill"]: observations.append({"source_event":event.duplicate(true)})
 if float(sim.hero_time)-last_health_time>=0.5:
  last_health_time=sim.hero_time
  observations.append({"health":{"room":room,"time":sim.hero_time,"hp":hero.hp,"position":hero.position,"inventory":model.state.inventory.duplicate(true)}})

func _combat(row: int) -> bool:
 var expected: Array = session.expected_enemies.duplicate()
 if expected.is_empty(): return false
 while _budget() and _identity():
  if not model.snapshot().pending_milestones.is_empty():
   var resolved: Dictionary = await _resolve_hexes()
   if not resolved.get("accepted",false): return false
  driver.advance_inputs()
  await _frame()
  if not _budget() or not _identity(): return false
  _record_health()
  if hero.dead or not session.fault.is_empty() or not driver.failure.is_empty():
   observations.append({"terminal_classification":{"hero_dead":hero.dead,"hp":hero.hp,"position":hero.position,"phase":sim.phase,"session_status":session.status,"session_fault":session.fault.duplicate(true),"driver_failure":driver.failure,"inventory":model.snapshot().inventory,"actual_Q1_rank":hero.ranks.q}})
   reason="NOT_REACHED_natural_death_or_source_fault";return false
  if session.status in ["between_rooms","completed"] and model.state.phase=="safe":
   driver.release_between_nodes()
   if sim.phase!="victory" or not sim.living().is_empty(): return false
   var flow: Dictionary=session.snapshot()
   if flow.row_state.completed_rows.size()!=row or flow.row_state.completed_rows.back().identity.node_id!=ROUTE[row-1]: return false
   var receipts: Array=[]
   for id: String in expected:
    if not session.kill_receipts.has(id): return false
    var kill: Dictionary=session.kill_receipts[id]
    var reward: String=str(kill.reward_id)
    if reward.is_empty() or all_reward_ids.has(reward) or model.state.reward_ids.count(reward)!=1 or kill.generation!=generation: return false
    if not model.receipts.has("ink-reward:"+reward): return false
    var original: Dictionary=model.receipts["ink-reward:"+reward]
    if not original.get("result",{}).get("accepted",false): return false
    var request: Dictionary=original.get("request",{})
    if request.get("action","")!="reward_minion" or request.get("args",{}).get("event_id","")!=reward or request.get("args",{}).get("room","")!=sim.combat_level_id: return false
    all_reward_ids[reward]=true
    receipts.append({"kill":kill.duplicate(true),"reward":original.duplicate(true)})
   observations.append({"combat_settlement":{"row":row,"flow":flow,"account":_account(),"original_rewards":receipts}})
   return true
 return false

func _upgrade(expected: int) -> bool:
 var resolved: Dictionary=await _resolve_hexes()
 if not resolved.get("accepted",false): return false
 var result: Dictionary=driver.upgrade_earned_Q1_once(expected)
 observations.append({"original_Q1_upgrade":result})
 if not result.get("accepted",false): return false
 if hero.loadout.q!="q1" or hero.ranks.q!=model.state.skills.Q.rank or model.state.skills.P.rank!=0: return false
 return _identity() and _budget()

func _service(row: int, entered: Dictionary) -> bool:
 var before: Dictionary=session.snapshot()
 if not _identity() or not _budget() or session.status!="service": return false
 if row in [3,9,11]:
  var prior: Array=entered.before_entry.rest_settlements
  var current: Array=before.get("rest_settlements",[])
  var entry_receipt: Dictionary=before.row_state.entry_receipt
  if current.size()!=prior.size()+1 or hero.hp!=hero.stats.max_hp: return false
  for old_receipt: Dictionary in prior:
   if not old_receipt in current: return false
  var matched: Array=[]
  for rest: Dictionary in current:
   if rest.get("entry_id","")==entry_receipt.get("receipt_id",""): matched.append(rest)
  if matched.size()!=1: return false
  var newest: Dictionary=matched[0]
  if not newest.get("accepted",false) or newest.get("replayed",true) or newest.get("run_id","")!=session.run_id or newest.get("room_id","")!=session.active_node_room or newest!=entered.entry_result.get("rest",{}): return false
  for key: String in ["q","e","r","shift"]:
   if float(hero.cooldowns.get(key,0.0))!=0.0: return false
  coverage.rest="PASS"
 var training_before: Dictionary={}
 if row in [4,6]:
  training_before=model.snapshot()
  if not session._entered_service("training") or not bool(training_before.training): return false
  observations.append({"training_service_skip":{"row":row,"entered_training":true,"paid":false,"actual_shop_script":host.shop_panel.get_script().resource_path,"reason":"original_service_continue_without_optional_purchase"}})
 if not _available(host.service_continue): return false
 var count: int=host.inputs.size()
 var serial: int=host.session_input_serial
 host.service_continue.pressed.emit()
 await _frame()
 if not _identity() or not _budget() or host.inputs.size()!=count+1 or host.session_input_serial!=serial+1: return false
 var receipt: Dictionary=host.inputs.back()
 var flow: Dictionary=session.snapshot()
 observations.append({"service":{"row":row,"before":before,"input":receipt,"after":flow}})
 if not training_before.is_empty():
  var training_after: Dictionary=model.snapshot()
  if training_after.body!=training_before.body or training_after.gold!=training_before.gold or training_after.skills!=training_before.skills or training_after.points!=training_before.points: return false
 return receipt.category=="normal_floor_ui" and receipt.action=="complete_service" and receipt.receipt.get("accepted",false) and session.status=="between_rooms" and flow.service_ready and flow.row_state.completed_rows.size()==row and flow.row_state.row_number==row+1

func _shop_roundtrip() -> bool:
 var before: Dictionary=model.snapshot()
 var result: Dictionary=driver.buy_one_original_potion()
 observations.append({"shop_first_purchase":result})
 if not result.get("accepted",false) or not result.get("purchased",false): reason="NOT_REACHED_actual_gold_for_shop_undo";return false
 host._shop(true)
 if not session.panel_open or not _available(host.shop_panel._undo): return false
 var count: int=host.inputs.size()
 var serial: int=host.session_input_serial
 host.shop_panel._undo.pressed.emit()
 if not _identity() or not _budget() or host.inputs.size()!=count+1 or host.session_input_serial!=serial+1: return false
 var receipt: Dictionary=host.inputs.back()
 var after: Dictionary=model.snapshot()
 observations.append({"shop_undo":receipt,"before_purchase":before,"after_undo":after})
 if receipt.category!="normal_floor_ui" or receipt.action!="undo" or not receipt.receipt.get("accepted",false) or before.gold!=after.gold or before.inventory!=after.inventory: return false
 coverage.shop_current_visit_undo="PASS"
 if not driver._close_original_shop(): return false
 var bought: Dictionary=driver.buy_one_original_potion()
 observations.append({"original_route_potion_repurchase":bought})
 return bought.get("accepted",false) and bought.get("purchased",false)

func _shop_boundary() -> bool:
 host._shop(true)
 if not _identity() or not session.panel_open or not host.shop_panel._undo.is_visible_in_tree(): return false
 var state: Dictionary=model.snapshot()
 var ok: bool=host.shop_panel._undo.disabled and state.shop_visit.undo.is_empty()
 observations.append({"shop_cross_room_boundary":{"disabled":host.shop_panel._undo.disabled,"visit":state.shop_visit.duplicate(true),"actual_refused_command":"NOT_ATTEMPTED_disabled_UI"}})
 if not driver._close_original_shop(): return false
 if ok: coverage.shop_cross_room_boundary="PASS"
 return ok and _budget()

func _hero_cancel() -> bool:
 var account: Dictionary=_account()
 var settlement: Dictionary=session.settlement.duplicate(true)
 if not _available(entry.return_button): return false
 entry.return_button.pressed.emit()
 var end: int=mini(deadline-10000,Time.get_ticks_msec()+3000)
 while _same_owners() and _budget() and not entry.chooser.is_visible_in_tree() and Time.get_ticks_msec()<end: await _frame()
 if not _identity() or not _budget() or Time.get_ticks_msec()>=end or _account()!=account or session.settlement!=settlement: return false
 if not _available(entry.chooser.hero_buttons.xuanlei): return false
 entry.chooser.hero_buttons.xuanlei.pressed.emit()
 if not _available(entry.chooser.enter_button): return false
 entry.chooser.enter_button.pressed.emit()
 if not _available(entry.cancel_button) or entry.pending_hero!="xuanlei" or _account()!=account or session.settlement!=settlement: return false
 observations.append({"hero_confirmation":{"pending":entry.pending_hero,"account":_account(),"settlement":session.settlement.duplicate(true)}})
 entry.cancel_button.pressed.emit()
 if not _available(entry.chooser.resume_button): return false
 entry.chooser.resume_button.pressed.emit()
 await _frame()
 if not _identity() or not _budget() or _account()!=account or session.settlement!=settlement or entry.active_hero!="yanguizhou": return false
 coverage.hero_confirmation_cancel="PASS"
 return true

func _full_route() -> bool:
 phase="initial_Q1"
 if not _growth_open() or not _press(host.initial_hud.q_choices.Q1.upgrade,"learn"): return false
 if model.state.points!=0 or model.state.skills.Q.rank!=1 or hero.loadout.q!="q1" or hero.ranks.q!=1 or model.state.skills.P.rank!=0: return false
 driver=Driver.new();driver.bind_existing(host,deadline-10000);driver.resolve_hex=Callable(self,"_resolve_hexes")
 for row: int in range(1,13):
  phase="original_"+str(ROUTE[row-1])
  var entered: Dictionary=await _next_node(row,ROUTE[row-1])
  observations.append({"entry":entered})
  if not entered.get("accepted",false) or not _adopt_entry(ROUTE[row-1],not row in SERVICES): return false
  if row in SERVICES:
   if not await _service(row,entered): return false
  else:
   if not await _combat(row): return false
  if row==1 and not await _upgrade(1): return false
  if row==3:
   if not await _upgrade(2) or not _shop_roundtrip(): return false
  if row==4 and not _shop_boundary(): return false
  if row==6 and not await _upgrade(3): return false
  if row==7 and not await _upgrade(4): return false
 var final_state: Dictionary=model.snapshot()
 var act: Dictionary=final_state.get("act_progress",{}).get("first_floor",{})
 var major: Dictionary=final_state.get("major_floor_events",{}).get("first_floor",{})
 if session.status!="completed" or not act.get("completed",false) or not act.get("boss_defeated",false) or major.get("boss_actor_id","")!=session.boss_id or major.get("run_id","")!=session.run_id or session.settlement.get("major_floor_event",{})!=major: return false
 coverage.boss_settlement="PASS"
 var reward_ids_before: Array=final_state.reward_ids.duplicate(true)
 var settlement_before: Dictionary=session.settlement.duplicate(true)
 observations.append({"post_boss_pending":final_state.pending_milestones.duplicate(),"settlement":settlement_before})
 var resolved: Dictionary=await _resolve_hexes()
 if not resolved.get("accepted",false): return false
 await _frame()
 if not _identity() or not _budget() or model.snapshot().reward_ids!=reward_ids_before or session.settlement!=settlement_before or model.snapshot().major_floor_events.get("first_floor",{})!=major: return false
 if not _completed_ui("after_final_hex"): return false
 var account: Dictionary=_account()
 for index: int in range(3): await _frame()
 if not _identity() or not _budget() or _account()!=account: return false
 coverage.reward_uniqueness="PASS"
 if not await _capture("completed_floor_ui",_sample("completed_before_capture")) or not _completed_ui("completed_postdraw"): return false
 coverage.completed_floor_ui="PASS"
 if not await _hero_cancel(): return false
 if not await _capture("resumed_completed_floor_ui",_sample("resumed_before_capture")) or not _completed_ui("resumed_postdraw"): return false
 observations.append({"final_account":_account(),"settlement":session.settlement.duplicate(true),"full_rows":session.snapshot().row_state.completed_rows})
 coverage.full_floor="PASS"
 return true

func _next_node(row: int, node_id: String) -> Dictionary:
 if not _same_owners() or not _identity() or not _budget(): return {"accepted":false,"reason":"owner_or_budget_before_next_node"}
 driver.release_between_nodes()
 if host.shop_session.panel_open:
  host._shop(false)
  driver._record("Host:_shop",{"open":false},host.shop_session.last_receipt)
  if host.shop_session.panel_open:return {"accepted":false,"reason":"original_shop_close_failed"}
 var hex_result: Dictionary=await _resolve_hexes()
 if not hex_result.get("accepted",false):return hex_result
 var upgrade_result: Dictionary={"accepted":true,"upgraded":false}
 if Time.get_ticks_msec()>=deadline-10000:return {"accepted":false,"reason":"deadline_before_next_selection"}
 host._select_row(row,node_id)
 driver._record("Host:_select_row",{"row":row,"node":node_id},host.shop_session.last_receipt)
 if not host.shop_session.last_receipt.get("accepted",false):return host.shop_session.last_receipt.duplicate(true)
 var ready: Dictionary=host.shop_session.next_room_preflight()
 while not ready.get("accepted",false) and ready.get("reason","")=="hero_too_close_to_next_spawn":
  # A fixed visible central floor point, not unseen future enemy coordinates.
  # Original Host free-move/collision remains the sole movement executor.
  if Time.get_ticks_msec()>=deadline-10000:driver.release_between_nodes();return {"accepted":false,"reason":"deadline_during_safe_entry_movement"}
  if host.finished or host.sim.hero.dead or host.sim.paused or not host.shop_session.fault.is_empty():driver.release_between_nodes();return {"accepted":false,"reason":"original_safe_movement_unavailable"}
  var center: Vector3=Vector3.ZERO
  var toward: Vector3=center-host.sim.hero.position
  if toward.length()<0.30:return {"accepted":false,"reason":"original_preflight_still_rejects_center"}
  toward=toward.normalized()
  toward=Vector3(-1.0 if toward.x < -0.30 else (1.0 if toward.x > 0.30 else 0.0),0.0,-1.0 if toward.z < -0.30 else (1.0 if toward.z > 0.30 else 0.0)).normalized()
  if toward==Vector3.ZERO:return {"accepted":false,"reason":"safe_entry_no_legal_key_direction"}
  if driver._visible_ground(host.sim.hero.position+toward).is_empty() or not driver._ground_clear(host.sim.hero.position,host.sim.hero.position+toward,float(host.sim.hero_radius)):return {"accepted":false,"reason":"safe_entry_local_movement_blocked"}
  driver._move(toward)
  await _frame()
  if not _same_owners() or not _identity() or not _budget():return {"accepted":false,"reason":"owner_or_budget_after_safe_movement"}
  ready=host.shop_session.next_room_preflight()
 driver.release_between_nodes()
 if not ready.get("accepted",false):return ready
 var before_entry: Dictionary={"model":host.shop_session.ledger.model.snapshot(),"hp":host.sim.hero.hp,"max_hp":host.sim.hero.stats.max_hp,"cooldowns":host.sim.hero.cooldowns.duplicate(true),"rest_settlements":host.shop_session.snapshot().get("rest_settlements",[]).duplicate(true)}
 if not _same_owners() or not _identity() or not _budget():return {"accepted":false,"reason":"owner_or_budget_before_entry"}
 host._request_next_room()
 driver._record("Host:_request_next_room",{"row":row,"node":node_id},host.shop_session.last_receipt)
 if not host.shop_session.last_receipt.get("accepted",false):return host.shop_session.last_receipt.duplicate(true)
 var entered_flow: Dictionary=host.shop_session.snapshot()
 var expected_status: String="service" if row in SERVICES else "combat"
 if entered_flow.status!=expected_status or entered_flow.row_state.get("entry_receipt",{}).get("identity",{}).get("node_id","")!=node_id:
  return {"accepted":false,"reason":"original_next_entry_scope_not_established"}
 return {"accepted":true,"node_id":node_id,"row":row,"upgrade":upgrade_result,"before_entry":before_entry,"entry_result":host.shop_session.last_receipt.duplicate(true)}
