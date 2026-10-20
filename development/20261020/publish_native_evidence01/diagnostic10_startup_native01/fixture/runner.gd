extends SceneTree
var construction_profile: Dictionary={}
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
 if images.size()>=1 or img==null or img.is_empty() or img.get_data().size()>16*1024*1024 or img.save_png(path)!=OK:failure="image_io";return
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
 construction_profile=room.startup_construction_profile()
 if not bool(construction_profile.get("enabled",false)) or not bool(construction_profile.get("closed",false)) or int(construction_profile.get("dropped",-1))!=0:failure="profile_not_complete";return
 var expected: Array=["base_stage_effect_audio_hud", "base_startup_report", "runtime_sim_router", "runtime_initial_actor", "runtime_other_views", "authority_session_constructor", "authority_reward_configure", "authority_definition_load", "authority_initialize_floor", "runtime_initial_refresh", "outer_ancestor_encounter", "outer_final_actor", "outer_final_effect_views", "outer_final_refresh", "outer_final_identity", "outer_ready_total"]
 var seen: Dictionary={}
 var rows: Array=construction_profile.get("rows",[])
 if rows.size()!=expected.size():failure="profile_label_count";return
 for row: Dictionary in rows:
  var label: String=str(row.get("label",""))
  if label not in expected or seen.has(label):failure="profile_label_unknown_or_duplicate";return
  seen[label]=true
  var began: int=int(row.get("begin_usec",0))
  var ended: int=int(row.get("end_usec",0))
  if began<=0 or ended<began or int(row.get("elapsed_usec",-1))!=ended-began:failure="profile_interval_invalid";return
  if began<int(loading_report.host_add_child_begin_usec) or ended>int(loading_report.host_add_child_ready_return_usec):failure="profile_outside_host_ready";return
 var timing_keys: Array=["click_usec","launch_begin_usec","resource_request_begin_usec","resource_request_return_usec","resource_loaded_observed_usec","resource_get_return_usec","instantiate_begin_usec","instantiate_return_usec","host_add_child_begin_usec","host_add_child_ready_return_usec","first_usable_admitted_usec","first_usable_postdraw_usec"]
 var previous: int=0
 for key: String in timing_keys:
  var stamp: int=int(loading_report.get(key,0))
  if stamp<=0 or stamp<previous:failure="loading_time_order:"+key;return
  previous=stamp
 if initial.gold!=0 or int(room.session_input_serial)!=0:failure="original_initial_gold_or_serial";return
 await shot("first_usable_hex")
func run() -> void:
 if DisplayServer.get_name()=="headless" or not evidence.is_absolute_path() or DirAccess.dir_exists_absolute(evidence):quit(4);return
 if DirAccess.make_dir_recursive_absolute(evidence)!=OK:quit(4);return
 await exercise()
 var report: Dictionary={"scope":"DIAGNOSTIC10_REAL_STARTUP_INTERVALS","accepted":failure.is_empty(),"reason":failure,"observations":observations,"images":images,"draws":draws,"elapsed_ms":Time.get_ticks_msec()-started,"loading":loading_report,"construction_profile":construction_profile,"performance_improved":false,"test_environment":{"LP_NUM_THREADS":OS.get_environment("LP_NUM_THREADS"),"scope":"TEST_PROCESS_ONLY"}}
 var bytes: PackedByteArray=(JSON.stringify(report,"  ")+"\n").to_utf8_buffer()
 if bytes.size()>128*1024:quit(4);return
 var f: FileAccess=FileAccess.open(evidence.path_join("report.json"),FileAccess.WRITE)
 if f==null:quit(4);return
 f.store_buffer(bytes);f.flush();var error: Error=f.get_error();f.close()
 var valid: bool=error==OK and FileAccess.get_file_as_bytes(evidence.path_join("report.json"))==bytes
 print("DIAGNOSTIC10_STARTUP_FINAL accepted=",report.accepted," io=",valid)
 quit(0 if report.accepted and valid else 4)
