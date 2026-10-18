extends SceneTree
## Original visible UI and Router inputs; no Sim state, skill, clock or HP writes.
const Driver = preload("res://natural_route_r09_prepare/visible_route_r09.gd")
var entry: Node
var host: Node
var sim: Node
var session: RefCounted
var model: RefCounted
var hero: Object
var display: Node3D
var actor: Node3D
var player: AnimationPlayer
var skeleton: Skeleton3D
var driver
var room: String = ""
var generation: int = -1
var started: int = 0
var deadline: int = 0
var evidence: String = ""
var phase: String = "boot"
var reason: String = ""
var finishing: bool = false
var hard_failed: bool = false
var completed: bool = false
var released: bool = false
var draw_count: int = 0
var rows: Array = []
var events: Array = []
var images: Array = []
var raw_bytes: int = 0
var coverage: Dictionary = {}

func _initialize() -> void:
 started=Time.get_ticks_msec(); deadline=started+90000
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--front-evidence="): evidence=arg.trim_prefix("--front-evidence=")
 process_frame.connect(_watchdog)
 call_deferred("_run")

func _watchdog() -> void:
 if Time.get_ticks_msec()>=deadline: _hard_exit()

func _hard_exit() -> void:
 if hard_failed: return
 hard_failed=true; completed=false
 if reason.is_empty(): reason="absolute_90s_watchdog"
 print("FRONT_COMBAT_FINAL accepted=false IO_OK=false reason=",reason)
 quit(4)

func _budget() -> bool:
 return not hard_failed and Time.get_ticks_msec()<deadline-(0 if finishing else 10000)

func _frame() -> bool:
 await process_frame
 await RenderingServer.frame_post_draw
 draw_count+=1
 if not _budget(): return false
 if is_instance_valid(sim):
  if rows.size()>=1600: reason="metadata_capacity"; return false
  rows.append({"draw":draw_count,"process":Engine.get_process_frames(),"phase":phase,"source_time":sim.hero_time,"paused":sim.paused,"hero_position":sim.hero.position,"hp":sim.hero.hp,"controller":display.receipt.duplicate(true) if is_instance_valid(display) else {},"original_upper":str(host.hero_view.sample_report.get("upper","")) if is_instance_valid(host) and is_instance_valid(host.hero_view) else ""})
 return true

func _owners() -> bool:
 return is_instance_valid(entry) and is_instance_valid(host) and entry.active_room==host and is_instance_valid(sim) and host.sim==sim and host.shop_session==session and session._owner_intact() and session.ledger.model==model and sim.hero==hero

func _identity() -> bool:
 return _owners() and sim.room_id==room and sim.encounter_generation==generation and not hero.dead

func _event(event: Dictionary) -> void:
 if events.size()<256 and str(event.get("kind","")) in ["ink_basic_released","ink_q1_released","ink_q1_preview_cancelled","damage","encounter_finished"]: events.append(event.duplicate(true))

func _available(button: Variant) -> bool:
 return is_instance_valid(button) and button is Button and button.is_visible_in_tree() and not button.disabled

func _hex() -> bool:
 var view = host.initial_hud.hex_draft
 if not _identity() or view.cards.size()!=4 or not _available(view.cards[1].select): return false
 var before: Dictionary=model.snapshot()
 var milestone: int=int(host.initial_controller.active_milestone)
 var offered: String=before.offers[str(milestone)].slots[1]
 var count: int=host.initial_actions.size()
 var until: int=mini(deadline-10000,Time.get_ticks_msec()+3000)
 view.cards[1].select.pressed.emit()
 while _identity() and _budget() and Time.get_ticks_msec()<until and (host.initial_actions.size()==count or view.choosing):
  if not await _frame(): return false
 if not _budget() or Time.get_ticks_msec()>=until or not _identity() or host.initial_actions.size()!=count+1 or view.choosing: return false
 var receipt: Dictionary=host.initial_actions.back()
 var state: Dictionary=model.snapshot()
 return _budget() and Time.get_ticks_msec()<until and receipt.request.action=="hex_select" and receipt.request.get("slot",-1)==1 and receipt.result.get("accepted",false) and state.selected_hex==before.selected_hex+[offered] and not milestone in state.pending_milestones and state.points==before.points

func _learn_and_enter() -> bool:
 if not _identity() or not host._learning_panel_allowed(): return false
 if not host.initial_hud.growth_panel.is_visible_in_tree():
  if not _available(host.growth_toggle): return false
  host.growth_toggle.pressed.emit()
 var button: Button=host.initial_hud.q_choices.Q1.upgrade
 if not _available(button): return false
 var count: int=host.initial_actions.size()
 button.pressed.emit()
 if not _budget() or not _identity() or host.initial_actions.size()!=count+1: return false
 var learned: Dictionary=host.initial_actions.back()
 if learned.get("request",{}).get("action","")!="learn" or learned.request.get("candidate_id","")!="Q1" or learned.request.get("slot_id","")!="Q" or not learned.get("result",{}).get("accepted",false) or hero.loadout.q!="q1" or hero.ranks.q!=1: return false
 host._select_row(1,"r01a")
 if not session.last_receipt.get("accepted",false): return false
 host._request_next_room()
 if not _budget() or not _owners() or not session.last_receipt.get("accepted",false) or session.last_receipt.get("reason","")!="selected_node_entered" or str(session.last_receipt.get("entry",{}).get("payload",{}).get("room_id",""))!=str(sim.room_id) or session.status!="combat" or sim.encounter_generation!=generation+1: return false
 room=sim.room_id; generation=sim.encounter_generation
 coverage.original_entry_receipt=session.last_receipt.duplicate(true)
 return _identity()

func _advance(seconds: float) -> bool:
 var start: float=sim.hero_time
 while _budget() and _identity() and sim.hero_time-start<seconds:
  if not await _frame(): return false
 return _identity() and _budget() and sim.hero_time>start

func _wait_pose(expected: String, moving: bool = false) -> bool:
 var until: int=mini(deadline-10000,Time.get_ticks_msec()+2500)
 while _budget() and _identity() and Time.get_ticks_msec()<until:
  if is_instance_valid(display) and not display.fatal.is_empty(): reason="controller_fatal:"+display.fatal; return false
  if is_instance_valid(display) and display.receipt.get("accepted",false) and str(display.receipt.get("phase",""))==expected and bool(display.receipt.get("moving",false))==moving and display.renderer.is_visible_in_tree(): return true
  if not await _frame(): return false
 return false

func _skins(hidden: bool) -> bool:
 if not is_instance_valid(display) or display.skins.size()!=9 or host.hero_view!=actor or actor.player!=player or actor.skeleton!=skeleton: return false
 for binding: Dictionary in display.skins:
  if not display._same_skin(binding) or binding.node.layers!=(0 if hidden else binding.layers) or bool(binding.owned)!=hidden: return false
 return true

func _signature() -> Dictionary:
 var meshes: Array=[]
 for key: String in display.renderer.ORDER:
  var node: MeshInstance3D=display.renderer.layers_by_name[key]
  meshes.append({"name":key,"arrays_hash":hash(node.mesh.surface_get_arrays(0)),"transform":node.transform})
 return {"source_time":sim.hero_time,"actor_transform":actor.global_transform,"display_transform":display.renderer.global_transform,"receipt":display.receipt.duplicate(true),"meshes":meshes}

func _picture(name: String) -> bool:
 if not _budget() or images.size()>=12 or draw_count<1: return false
 var image: Image=root.get_texture().get_image()
 if image==null or image.is_empty(): return false
 raw_bytes+=image.get_data_size()
 if raw_bytes>64*1024*1024: return false
 images.append({"name":name,"image":image,"draw":draw_count,"source_time":sim.hero_time,"plan":display.receipt.duplicate(true),"skin_hidden":_skins(true),"skin_restored":_skins(false)})
 return true

func _space() -> void:
 # SPACE is an original Host shortcut before Router handling, not a Sim setter.
 var event: InputEventKey=InputEventKey.new()
 event.physical_keycode=KEY_SPACE; event.pressed=true; host._input(event)
 event=InputEventKey.new(); event.physical_keycode=KEY_SPACE; event.pressed=false; host._input(event)

func _pause_check() -> bool:
 _space()
 if not sim.paused: return false
 if not await _frame() or not _skins(true): return false
 var frozen: Dictionary=_signature()
 for index: int in range(3):
  if not await _frame() or not sim.paused or _signature()!=frozen: return false
 coverage.pause={"draws":3,"signature":frozen}
 _space()
 return not sim.paused

func _legal_line() -> Dictionary:
 var forward: Vector3=host.stage.camera.global_basis.z
 forward.y=0.0; forward=forward.normalized()
 for distance: float in [5.0,4.0,3.0]:
  var a: Vector3=hero.position+forward*distance
  var b: Vector3=a+forward*2.5
  if not driver._visible_ground(a).is_empty() and not driver._visible_ground(b).is_empty() and driver._ground_clear(hero.position,a,float(sim.hero_radius)) and driver._ground_clear(a,b,float(sim.hero_radius)):
   return {"a":a,"b":b,"direction":forward}
 return {}

func _combat() -> bool:
 display=entry.get("_front_hero")
 if not is_instance_valid(display):
  if not await _frame(): return false
  display=entry.get("_front_hero")
 if not is_instance_valid(display) or not display.attached: reason="front_attach_failed"; return false
 actor=host.hero_view; player=actor.player; skeleton=actor.skeleton
 driver=Driver.new(); driver.bind_existing(host,deadline-10000)
 sim.combat_event.connect(_event)
 # Ordinary retreat creates legal room to demonstrate moving forward while casting.
 phase="retreat_original_W"; driver._move(Vector3.FORWARD)
 if not await _advance(0.6): return false
 phase="front_walk"; driver._move(Vector3.BACK)
 if not await _wait_pose("idle",true) or not _skins(true) or not _picture("01_front_walk"): return false
 driver._move(Vector3.ZERO)
 phase="front_idle"
 if not await _wait_pose("idle") or not _skins(true) or not _picture("00_front_idle"): return false
 if not await _pause_check(): reason="pause_not_frozen"; return false
 var line: Dictionary=_legal_line()
 if line.is_empty(): reason="no_visible_legal_front_ground"; return false
 phase="ordinary_basic"
 var down: Dictionary=driver._mouse(line.a,true)
 driver._mouse(line.a,false)
 if not down.get("accepted",false): reason="basic_router_rejected"; return false
 coverage.basic_input=down.duplicate(true)
 if not await _wait_pose("basic") or not _skins(true) or not _picture("02_front_basic"): return false
 if not await _wait_pose("idle"): return false
 phase="moving_Q1"
 line=_legal_line()
 if line.is_empty(): reason="no_visible_legal_Q1_line"; return false
 var armed: Dictionary=driver._key(KEY_Q,true)
 driver._key(KEY_Q,false)
 if not armed.get("accepted",false): reason="Q_router_rejected"; return false
 var begun: Dictionary=driver._mouse(line.a,true)
 if not begun.get("accepted",false): reason="Q1_begin_rejected"; return false
 driver.gesture={"fixture_owned_preview":true}
 driver._move(Vector3.BACK)
 var start: float=sim.hero_time
 var draw_limit: float=float(sim.ink_presenter_snapshot().get("input",{}).get("draw_limit",0.0))
 if draw_limit<=0.0: reason="original_draw_limit_unavailable"; return false
 var start_position: Vector3=hero.position
 var captured_draw: bool=false
 while _budget() and _identity() and str(sim.ink_input.phase)=="drawing":
  var u: float=clampf((sim.hero_time-start)/draw_limit,0.0,1.0)
  var motion: Dictionary=driver._mouse(line.a.lerp(line.b,u),true,true)
  if not motion.get("accepted",false): reason="Q1_motion_rejected"; return false
  if not await _frame(): return false
  if not captured_draw and display.receipt.get("accepted",false) and display.receipt.get("phase","")=="draw" and float(display.receipt.progress)>=0.25:
   if not _skins(true) or not _picture("03_moving_Q1_draw"): return false
   captured_draw=true
 if not captured_draw or str(sim.ink_input.phase)!="frozen" or not await _wait_pose("hold",true) or not _picture("04_moving_Q1_hold"): reason="Q1_draw_hold_missing"; return false
 if not await _advance(0.10): return false
 var release: Dictionary=driver._mouse(line.b,false)
 coverage.Q1_release_input=release.duplicate(true)
 if not release.get("accepted",false): reason="Q1_release_rejected"; return false
 driver.gesture={}
 if not await _wait_pose("release",true) or not _skins(true) or not _picture("05_moving_Q1_release"): return false
 if not await _wait_pose("idle",true): return false
 coverage.moving_cast_displacement=hero.position.distance_to(start_position)
 if float(coverage.moving_cast_displacement)<=0.1: reason="moving_cast_no_actual_displacement"; return false
 driver._move(Vector3.ZERO)
 if not await _wait_pose("idle") or not _picture("06_front_return_idle"): return false
 phase="original_direction_fallback"
 driver._move(Vector3.FORWARD)
 var until: int=mini(deadline-10000,Time.get_ticks_msec()+1500)
 while _budget() and _identity() and Time.get_ticks_msec()<until and display.renderer.visible:
  if not await _frame(): return false
 driver._move(Vector3.ZERO)
 if display.renderer.visible or not _skins(false) or not _picture("07_original_direction_fallback"): reason="fallback_skin_restore_failed"; return false
 var basics: Array=[]; var waves: Array=[]
 for event: Dictionary in events:
  if event.get("kind","")=="ink_basic_released" and event.get("source","")=="attack": basics.append(event)
  if event.get("kind","")=="ink_q1_released": waves.append(event)
 coverage.basic_events=basics; coverage.Q1_events=waves
 if basics.size()!=1 or waves.size()!=1 or str(basics[0].get("wave_id",""))!=str(down.get("projectile_id","")) or str(waves[0].get("wave_id",""))!=str(release.get("wave_id","")): reason="source_release_identity_mismatch"; return false
 coverage.actor_id=actor.get_instance_id(); coverage.player_id=player.get_instance_id(); coverage.skeleton_id=skeleton.get_instance_id()
 return true

func _run() -> void:
 create_timer(89.0,true,false,true).timeout.connect(_hard_exit)
 root.size=Vector2i(1280,720)
 if DisplayServer.get_name()=="headless" or not evidence.is_absolute_path() or FileAccess.file_exists(evidence) or DirAccess.dir_exists_absolute(evidence): reason="fresh_absolute_normal_window_required"; quit(4); return
 if DirAccess.make_dir_recursive_absolute(evidence)!=OK: quit(4); return
 entry=load("res://scenes/hero_entry.tscn").instantiate(); root.add_child(entry)
 if not await _frame(): await _finish(); return
 entry.request_start("yanguizhou")
 while _budget() and not is_instance_valid(entry.active_room):
  if not await _frame(): await _finish(); return
 if not is_instance_valid(entry.active_room): reason="no_original_host"; await _finish(); return
 host=entry.active_room; phase="original_startup"
 while _budget() and (host._mainprep_required or not host.initial_started):
  if str(host._mainprep_receipt.get("status",""))=="HOLD" or not str(host.startup_session_error).is_empty() or not str(host.floor_error).is_empty(): reason="original_startup_HOLD"; await _finish(); return
  if not await _frame(): await _finish(); return
 sim=host.sim; session=host.shop_session; model=session.ledger.model; hero=sim.hero; room=sim.room_id; generation=sim.encounter_generation
 if not await _hex() or not await _learn_and_enter(): reason="original_initial_UI_or_entry_failed"; await _finish(); return
 if not await _frame(): await _finish(); return
 completed=await _combat()
 if not completed and reason.is_empty(): reason="original_hero_dead" if is_instance_valid(hero) and hero.dead else "required_combat_display_observation_missing"
 await _finish()

func _write(name: String, value: Variant) -> bool:
 var path: String=evidence.path_join(name)
 if FileAccess.file_exists(path) or not _budget(): return false
 var text: String=JSON.stringify(value,"  ")+"\n"
 var file: FileAccess=FileAccess.open(path,FileAccess.WRITE)
 if file==null: return false
 var stored: bool=file.store_string(text); file.flush()
 var ok: bool=stored and file.get_error()==OK
 file.close()
 return ok and FileAccess.get_file_as_string(path)==text and _budget()

func _finish() -> void:
 if finishing: return
 finishing=true
 if driver!=null and _owners(): driver.release_between_nodes()
 var original_host: bool=is_instance_valid(entry) and not entry.is_queued_for_deletion() and is_instance_valid(host) and not host.is_queued_for_deletion() and entry.active_room==host
 var can_close: bool=original_host and (_owners() if sim!=null else true)
 if is_instance_valid(display):
  var script: Script=display.get_script()
  if not can_close or display.is_queued_for_deletion() or display.get_parent()!=host or script==null or script.resource_path!="res://yan_front_hero_20261018/controller.gd":
   can_close=false; completed=false
   if reason.is_empty(): reason="exit_display_owner_mismatch"
  else:
   display.shutdown()
   if not display.receipt.get("restoration_complete",false):
    can_close=false; completed=false
    if reason.is_empty(): reason="exit_skin_restoration_incomplete"
 if not can_close:
  completed=false
  if reason.is_empty(): reason="exit_original_owner_mismatch"
 if can_close and not host._mainprep_pending and host.frontdoor_can_suspend():
  var closed: bool=host.frontdoor_close_run("front_combat_probe")
  coverage.original_close={"accepted":closed,"receipt":host.frontdoor_last_close.duplicate(true)}
  if closed:
   entry.queue_free()
   await _frame(); await _frame()
   released=not is_instance_valid(entry)
 var saved: Array=[]
 var io_ok: bool=released and _budget()
 if io_ok:
  for item: Dictionary in images:
   var path: String=evidence.path_join(item.name+".png")
   if FileAccess.file_exists(path) or item.image.save_png(path)!=OK or FileAccess.get_file_as_bytes(path).is_empty() or not _budget(): io_ok=false; break
   saved.append({"name":item.name,"sha256":FileAccess.get_sha256(path),"draw":item.draw,"source_time":item.source_time,"plan":item.plan,"skin_hidden":item.skin_hidden,"skin_restored":item.skin_restored})
 var report: Dictionary={"accepted":completed and released and io_ok,"reason":reason,"synthetic_input":true,"native_OS_input":false,"source_released":released,"draw_count":draw_count,"elapsed_ms":Time.get_ticks_msec()-started,"coverage":coverage,"screenshots":saved,"raw_bytes":raw_bytes,"scope":"front_idle_walk_basic_Q1_partial_world_sample"}
 io_ok=_write("draws.json",rows) and io_ok
 io_ok=_write("inputs.json",driver.receipts if driver!=null else []) and io_ok
 io_ok=_write("events.json",events) and io_ok
 io_ok=_write("report.json",report) and io_ok
 print("FRONT_COMBAT_FINAL ",JSON.stringify(report)," IO_OK=",io_ok)
 quit(0 if report.accepted and io_ok and _budget() else 4)
