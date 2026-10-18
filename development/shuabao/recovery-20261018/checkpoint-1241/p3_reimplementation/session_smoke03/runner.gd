extends SceneTree
# REIMPLEMENTATION. Synthetic visible-button input; no gameplay state writes.
const BINDING = "res://yan_p3_smoke_20261018b/binding.json"
const BINDING_SHA = "d4af4d000f69c4bfc1be2d833a37b6d2701f4d745cf1c3a335950020bac4ea60"
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
 deadline = started + 180000
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--p3-evidence="): evidence = argument.trim_prefix("--p3-evidence=")
 process_frame.connect(_wall_watchdog)
 call_deferred("_run")

func _wall_watchdog() -> void:
 if Time.get_ticks_msec() >= deadline: _watchdog_exit("absolute_180s_deadline")

func _watchdog_exit(why: String = "independent_170s_watchdog") -> void:
 if watchdog_fired: return
 watchdog_fired = true
 finishing = true
 reason = why
 # Independent signal callback survives a failed _run coroutine. No second finish.
 var diagnostic: Dictionary = {"accepted":false,"reason":why,"phase":phase,"elapsed_ms":Time.get_ticks_msec()-started,"source_released":released,"draw_count":draw_count}
 if not evidence.is_empty():
  if screenshots.size()<3 and Time.get_ticks_msec()<deadline: _picture("watchdog_failure")
  _json("watchdog.json",diagnostic)
  _json("observations.json",observations)
  _json("report.json",diagnostic)
 print("P3_REIMPLEMENTATION_SMOKE_WATCHDOG ",JSON.stringify(diagnostic))
 quit(4)

func _budget() -> bool:
 return Time.get_ticks_msec() < deadline - (0 if finishing else 10000)

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

func _picture(name: String) -> bool:
 if screenshots.size() >= 3 or not _budget() or draw_count < 1: return false
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
 create_timer(170.0,true,false,true).timeout.connect(_watchdog_exit)
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
 phase="open_growth"
 var hud = host.initial_hud
 if not hud.growth_panel.is_visible_in_tree():
  if not _available(host.growth_toggle): await _stop("growth_button_unavailable"); return
  host.growth_toggle.pressed.emit()
 await _frame()
 if not _identity() or not hud.growth_panel.is_visible_in_tree(): await _stop("original_growth_panel_not_visible"); return
 var before: Dictionary = _sample("before_learning")
 if not before.accepted or before.points!=1 or before.skills.P.rank!=0: await _stop("fresh_one_sp_required"); return
 phase="learn_p3"
 if not _press(hud.p3_choice,"learn"): await _stop("p3_learning_receipt_required"); return
 var learned: Dictionary = _sample("p3_learned")
 if not learned.accepted or learned.points!=0 or learned.skills.P.candidate!="P3" or learned.skills.P.rank!=1 or learned.hero_loadout.passive!="p3" or learned.hero_ranks.passive!=1 or learned.p3.counts!={"q":0,"e":0} or learned.p3.ready!={"q":false,"e":false}: await _stop("p3_projection_or_cost_failed"); return
 if not await _capture("01_p3_learned",learned): await _stop("p3_capture_failed"); return
 phase="undo_p3"
 if not _press(hud.undo_button,"undo_new_points"): await _stop("original_safe_undo_failed"); return
 var undone: Dictionary = _sample("p3_undone")
 if not undone.accepted or undone.points!=1 or undone.skills.P!=before.skills.P or undone.hero_loadout.passive!=before.hero_loadout.passive or undone.hero_ranks.passive!=before.hero_ranks.passive or undone.p3.rank!=0: await _stop("undo_projection_or_fee_failed"); return
 if not await _capture("02_p3_undone",undone): await _stop("undo_capture_failed"); return
 phase="learn_q1"
 if not _press(hud.q_choices.Q1.upgrade,"learn"): await _stop("q1_learning_receipt_required"); return
 var q1: Dictionary = _sample("q1_learned")
 if not q1.accepted or q1.points!=0 or q1.skills.Q.candidate!="Q1" or q1.skills.Q.rank!=1 or q1.hero_loadout.q!="q1" or q1.hero_ranks.q!=1 or q1.skills.P!=before.skills.P or q1.hero_loadout.passive!=before.hero_loadout.passive: await _stop("q1_projection_or_fee_failed"); return
 if not await _capture("03_q1_learned",q1): await _stop("q1_capture_failed"); return
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
 var report: Dictionary = {"accepted":completed and released and _budget(),"reason":reason,"synthetic":true,"scope":"original_entry_hex_P3_fee_Hero_Model_undo_Q1_only","source_released":released,"elapsed_ms":Time.get_ticks_msec()-started,"draw_count":draw_count,"screenshots":screenshots,"raw_image_bytes":image_bytes}
 var io_ok: bool = _json("observations.json",observations)
 io_ok = _json("report.json",report) and io_ok
 if Time.get_ticks_msec() >= deadline:
  report.accepted = false
  report.reason = "absolute_deadline_after_io"
  io_ok = _json("report.json",report) and io_ok
 print("P3_REIMPLEMENTATION_SMOKE_FINAL ",JSON.stringify(report)," IO_OK=",io_ok)
 quit(0 if report.accepted and io_ok and Time.get_ticks_msec() < deadline else 4)
