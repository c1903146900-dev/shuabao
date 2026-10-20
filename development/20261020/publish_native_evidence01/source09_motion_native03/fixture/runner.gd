extends SceneTree
const MotionObserver=preload("observer.gd")
const RigObserver=preload("rig_observer.gd")
var rig_observer=RigObserver.new()
var motion_observer=MotionObserver.new()
var motion_active: bool=false
var motion_stage: String=""
var motion_rows: Array=[]
var entry: Variant
var room: Variant
var pages: Variant
var evidence: String=""
var started: int=0
var draws: int=0
var failure: String=""
var loading_report: Dictionary={}
var observations: Array=[]
var images: Array=[]
func _initialize() -> void:
 print("TEST_LP_NUM_THREADS=",OS.get_environment("LP_NUM_THREADS"))
 if OS.get_environment("LP_NUM_THREADS")!="2":
  quit(4)
  return
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--baseline-evidence="): evidence=arg.trim_prefix("--baseline-evidence=")
 started=Time.get_ticks_msec()
 call_deferred("run")
func frame() -> void:
 await process_frame
 await RenderingServer.frame_post_draw
 draws+=1
 if motion_active and failure.is_empty():
  if motion_rows.size()>=128:failure="sample_budget_128"
  else:
   var mesh_row: Dictionary=motion_observer.observe(entry)
   var rig_row: Dictionary=rig_observer.observe(entry,motion_stage)
   motion_rows.append({"stage":motion_stage,"wall_ms":Time.get_ticks_msec()-started,"mesh":mesh_row,"rig":rig_row})
   if not motion_observer.failure.is_empty():failure=motion_observer.failure
   elif not bool(rig_row.get("accepted",false)):failure=str(rig_row.get("reason","rig_failure"))
   elif not bool(mesh_row.get("same_source_clock",false)):failure="actual_source_clock_mismatch"
   elif bool(rig_row.controlled):failure="real_control_or_dead_during_motion"
   elif not bool(mesh_row.get("controller_accepted",false)) or not bool(mesh_row.get("renderer_accepted",false)) or not str(mesh_row.get("controller_fatal","")).is_empty():failure="actual_cartoon_display_rejected"

 if Time.get_ticks_msec()-started>90000 and failure.is_empty(): failure="fixture_90s_deadline"
func state() -> Dictionary:
 if not is_instance_valid(room): return {}
 var s: Dictionary=room.shop_session.ledger.model.state
 return {"level":s.level,"points":s.points,"xp":s.xp,"gold":s.gold,"skills":s.skills.duplicate(true),"selected_hex":s.selected_hex.duplicate(true),"status":room.shop_session.status,"source_time":room.sim.hero_time,"serial":room.session_input_serial}
func record(label: String) -> void:
 var row: Dictionary={"stage":label,"wall_ms":Time.get_ticks_msec()-started,"draw":draws,"state":state()}
 if is_instance_valid(pages):
  row["page"]=pages.page
  row["skills_visible"]=room.initial_hud.growth_panel.is_visible_in_tree()
  row["map_visible"]=room.route_map.is_visible_in_tree()
  if row.skills_visible and row.map_visible: failure="page_overlap"
 observations.append(row)
func click(value: Variant,label: String,transaction: bool=false) -> bool:
 var b: Button=value as Button
 if b==null or not b.is_visible_in_tree() or b.disabled: failure="button_unavailable:"+label;return false
 var rect: Rect2=b.get_global_rect().intersection(root.get_visible_rect())
 if rect.size.x<2 or rect.size.y<2: failure="button_offscreen:"+label;return false
 var count: Dictionary={"pressed":0}
 var listener: Callable=func():count.pressed+=1
 b.pressed.connect(listener)
 var before: int=room.inputs.size() if is_instance_valid(room) else 0
 var serial: int=room.session_input_serial if is_instance_valid(room) else 0
 var pre_state: Dictionary=state()
 var completions: Array=[]
 var completed_listener: Callable=func(request: Dictionary,result: Dictionary):completions.append({"request":request.duplicate(true),"result":result.duplicate(true)})
 var controller_transaction: bool=transaction and label in ["select_hex","learn_Q1"]
 if controller_transaction:room.initial_controller.command_completed.connect(completed_listener)
 var pos: Vector2=rect.get_center()
 var motion:=InputEventMouseMotion.new();motion.position=pos;motion.global_position=pos;root.push_input(motion,true)
 await frame()
 var down:=InputEventMouseButton.new();down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;down.position=pos;down.global_position=pos;root.push_input(down,true)
 await frame()
 var up:=InputEventMouseButton.new();up.button_index=MOUSE_BUTTON_LEFT;up.pressed=false;up.position=pos;up.global_position=pos;root.push_input(up,true)
 await frame()
 if is_instance_valid(b):b.pressed.disconnect(listener)
 var wait_started: int=Time.get_ticks_msec()
 if transaction:
  while room.session_input_serial==serial and Time.get_ticks_msec()-wait_started<3000 and failure.is_empty():
   await frame()
 if controller_transaction:room.initial_controller.command_completed.disconnect(completed_listener)
 var receipts: Array=[]
 if is_instance_valid(room):
  for item: Dictionary in room.inputs:
   if item.get("category","")=="normal_floor_ui" and int(item.get("serial",-1))>serial:receipts.append(item.duplicate(true))
 var tail: Array=[]
 if is_instance_valid(room):
  for i in range(maxi(0,room.inputs.size()-6),room.inputs.size()):tail.append(room.inputs[i].duplicate(true))
 observations.append({"stage":"click","label":label,"position":[pos.x,pos.y],"pressed":count.pressed,"receipts":receipts,"command_completed":completions,"before_state":pre_state,"after_state":state(),"input_tail":tail,"transaction_wait_ms":Time.get_ticks_msec()-wait_started})
 if count.pressed!=1:failure="pressed_count:"+label
 var expected_action: String={"select_hex":"hex_select","learn_Q1":"learn","select_r01a":"select_node","enter_r01a":"enter_selected_node"}.get(label,"")
 if transaction and (receipts.size()!=1 or not bool(receipts[0].receipt.get("accepted",false)) or str(receipts[0].action)!=expected_action or room.session_input_serial!=serial+1):failure="unique_accepted_transaction:"+label
 if controller_transaction and (completions.size()!=1 or str(completions[0].request.action)!=expected_action or not bool(completions[0].result.get("accepted",false))):failure="unique_command_completed:"+label

 return failure.is_empty()
func wait_page(wanted: String) -> bool:
 for i in range(90):
  await frame()
  if not failure.is_empty():return false
  if str(pages.page)==wanted:
   record(wanted)
   return failure.is_empty()
 failure="page_timeout:"+wanted
 return false
func key(code: Key) -> void:
 var d:=InputEventKey.new();d.keycode=code;d.physical_keycode=code;d.pressed=true;root.push_input(d,true)
 await frame()
 var u:=InputEventKey.new();u.keycode=code;u.physical_keycode=code;u.pressed=false;root.push_input(u,true)
 await frame()
func shot(label: String) -> void:
 await frame()
 var img: Image=root.get_texture().get_image()
 var path: String=evidence.path_join(label+".png")
 if images.size()>=3 or img==null or img.is_empty() or img.get_data().size()>16*1024*1024 or img.save_png(path)!=OK:failure="image_io";return
 images.append({"name":label,"sha256":FileAccess.get_sha256(path),"draw":draws,"wall_ms":Time.get_ticks_msec()-started})
func exercise() -> void:
 var packed: PackedScene=load("res://scenes/hero_entry.tscn") as PackedScene
 if packed==null:failure="missing_entry";return
 entry=packed.instantiate();root.add_child(entry)
 await frame();await frame()
 if str(entry.chooser.selected_id)!="yanguizhou":failure="default_hero_changed";return
 if not await click(entry.chooser.enter_button,"enter_hero"):return
 while Time.get_ticks_msec()-started<70000:
  await frame()
  if not failure.is_empty():return
  if is_instance_valid(entry.active_room):
   room=entry.active_room
   if not room._mainprep_required and not room._mainprep_pending:break
 if not is_instance_valid(room) or room._mainprep_required or room._mainprep_pending:failure="startup_timeout";return
 pages=entry._trial_ui._pages
 if not is_instance_valid(pages):failure="coordinator_missing";return
 for i in range(10):
  await frame()
  if str(entry._loading_status.report.get("status",""))=="ready_observed":break
 loading_report=entry._loading_status.report.duplicate(true)
 if str(loading_report.get("status",""))!="ready_observed" or bool(entry._load_in_flight):failure="loading_not_ready_observed";return
 record("initial_hex")
 var initial: Dictionary=state()
 if initial.level!=1 or initial.points!=1 or initial.xp!=0 or not initial.selected_hex.is_empty():failure="original_initial_values";return
 if room.initial_hud.hex_draft.cards.is_empty():failure="no_hex_cards";return
 if not await click(room.initial_hud.hex_draft.cards[0].select,"select_hex",true):return
 if not await wait_page("skills"):return
 if state().selected_hex.size()!=1:failure="hex_selection_missing";return
 if not await click(room.initial_hud.q_choices["Q1"].upgrade,"learn_Q1",true):return
 if state().points!=0 or int(room.sim.hero.ranks.q)!=1:failure="original_learning_result";return
 if not await click(pages.done,"skills_done"):return
 if not await wait_page("map"):return
 if not room.route_map.buttons.has("r01a"):failure="r01a_missing";return
 if not await click(room.route_map.buttons["r01a"],"select_r01a",true):return
 if not await click(room.session_next,"enter_r01a",true):return
 if not await wait_page("room"):return
 if str(room.shop_session.status)!="combat":failure="combat_not_entered";return
 record("first_combat")
 await exercise_motion()
func held_key(code: Key,pressed: bool) -> void:
 var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed;root.push_input(event,true)
func exercise_motion() -> void:
 motion_active=true;motion_stage="turn_front"
 var aligned_draws: int=0
 held_key(KEY_S,true)
 for i in range(20):
  await frame()
  if not failure.is_empty():break
  var actual: Dictionary=motion_rows.back().rig
  var dot_value: Variant=actual.get("actual_forward_dot_movement")
  var aligned: bool=dot_value!=null and float(dot_value)>=0.9999 and str(actual.get("upper",""))=="" and str(actual.get("view",""))=="front"
  aligned_draws=aligned_draws+1 if aligned else 0
  if aligned_draws>=2:break
 if failure.is_empty() and aligned_draws<2:failure="turn_actual_heading_not_settled"
 held_key(KEY_S,false)
 if not failure.is_empty():motion_active=false;return
 motion_stage="calibrate_idle"
 for i in range(40):
  await frame()
  if not failure.is_empty() or not rig_observer.neutral.is_empty():break
 if failure.is_empty() and rig_observer.neutral.is_empty():failure="front_neutral_not_observed"
 if not failure.is_empty():motion_active=false;return
 await shot("front_neutral")
 motion_stage="walk_front"
 var walk_start: float=room.sim.hero_time
 var gait_start: float=float(room.hero_view.sample_report.gait_elapsed_absolute)
 var wall_start: int=Time.get_ticks_msec()
 var walk_picture: bool=false
 held_key(KEY_S,true)
 while float(room.hero_view.sample_report.gait_elapsed_absolute)-gait_start<0.5 and Time.get_ticks_msec()-wall_start<3500 and failure.is_empty():
  await frame()
  if str(motion_rows.back().mesh.get("view",""))!="front":failure="walk_view_changed"
  if not walk_picture and float(room.sim.hero_time)-walk_start>=0.25 and failure.is_empty():
   await shot("front_walk")
   walk_picture=true
 held_key(KEY_S,false)
 observations.append({"stage":"walk_cycle","source_start":walk_start,"source_end":room.sim.hero_time,"gait_start":gait_start,"gait_end":room.hero_view.sample_report.gait_elapsed_absolute})
 if failure.is_empty() and float(room.hero_view.sample_report.gait_elapsed_absolute)-gait_start<0.5:failure="actual_gait_cycle_not_covered"
 if not failure.is_empty():motion_active=false;return
 motion_stage="stop"
 var idle_count: int=0
 for i in range(30):
  await frame()
  if not failure.is_empty():break
  idle_count=idle_count+1 if str(motion_rows.back().rig.get("base",""))=="idle" else 0
  if idle_count>=3:break
 if failure.is_empty() and idle_count<3:failure="stop_idle_not_observed"
 if failure.is_empty():await shot("front_stop")
 motion_active=false
func run() -> void:
 if DisplayServer.get_name()=="headless" or not evidence.is_absolute_path() or DirAccess.dir_exists_absolute(evidence):quit(4);return
 if DirAccess.make_dir_recursive_absolute(evidence)!=OK:quit(4);return
 await exercise()
 var report: Dictionary={"scope":"SOURCE09_CONVERGED_ORIGINAL_FRONT_MOTION_DIAGNOSTIC","accepted":failure.is_empty(),"reason":failure,"observations":observations,"images":images,"draws":draws,"elapsed_ms":Time.get_ticks_msec()-started,"full_floor_tested":false,"motion":motion_rows,"sampler_failure":motion_observer.failure,"neutral":rig_observer.neutral,"motion_repaired":false,"loading":loading_report,"test_environment":{"LP_NUM_THREADS":OS.get_environment("LP_NUM_THREADS"),"scope":"TEST_PROCESS_ONLY_NOT_GAME_OPTIMIZATION"}}
 var bytes: PackedByteArray=(JSON.stringify(report,"  ")+"\n").to_utf8_buffer()
 if bytes.size()>8*1024*1024:quit(4);return
 var f: FileAccess=FileAccess.open(evidence.path_join("report.json"),FileAccess.WRITE)
 if f==null:quit(4);return
 f.store_buffer(bytes);f.flush();var error: Error=f.get_error();f.close()
 var valid: bool=error==OK and FileAccess.get_file_as_bytes(evidence.path_join("report.json"))==bytes
 print("SOURCE09_MOTION_FINAL accepted=",report.accepted," io=",valid)
 quit(0 if report.accepted and valid else 4)
