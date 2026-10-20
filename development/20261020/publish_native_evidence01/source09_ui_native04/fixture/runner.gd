extends SceneTree
var entry: Variant
var room: Variant
var pages: Variant
var evidence: String=""
var started: int=0
var draws: int=0
var failure: String=""
var loading_report: Dictionary={}
var tooltip_observation: Dictionary={}
var observations: Array=[]
var images: Array=[]
func _initialize() -> void:
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
  var backing: Control=room.session_hint.get_parent().get_node_or_null("TrialLiveHintBacking") as Control
  row["hint_backing"]={"found":is_instance_valid(backing)}
  if is_instance_valid(backing):
   var br: Rect2=backing.get_global_rect()
   row.hint_backing.merge({"visible":backing.is_visible_in_tree(),"rect":[br.position.x,br.position.y,br.size.x,br.size.y]})
   if pages.page=="map":
    var overlaps: Array=[]
    for id: String in room.route_map.buttons:
     var button: Button=room.route_map.buttons[id]
     if button.is_visible_in_tree() and br.intersects(button.get_global_rect()):overlaps.append(id)
    row.hint_backing["node_overlaps"]=overlaps
    if not overlaps.is_empty():failure="map_hint_backing_overlaps_nodes"
  row["equipment_text"]=room.session_equipment.text
  row["equipment_tooltip"]=room.session_equipment.tooltip_text
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
func shot(label: String,viewport: Viewport=null) -> void:
 await frame()
 if viewport==null:viewport=root
 var img: Image=viewport.get_texture().get_image()
 var path: String=evidence.path_join(label+".png")
 if images.size()>=4 or img==null or img.is_empty() or img.get_data().size()>16*1024*1024 or img.save_png(path)!=OK:failure="image_io";return
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
 var expected_phases: Array=["resource_request","instantiate","host_ready","first_display"]
 if loading_report.get("phases",[])!=expected_phases:failure="loading_phase_order";return
 if int(loading_report.get("resource_loaded_observed_usec",0))>int(loading_report.get("resource_get_return_usec",0)):failure="loading_get_order";return
 if not loading_report.has("first_usable_postdraw_usec") or room._mainprep_required or room._mainprep_pending:failure="first_usable_not_admitted";return
 record("initial_hex")
 var initial: Dictionary=state()
 if initial.level!=1 or initial.points!=1 or initial.xp!=0 or not initial.selected_hex.is_empty():failure="original_initial_values";return
 if room.initial_hud.hex_draft.cards.is_empty():failure="no_hex_cards";return
 if not await click(room.initial_hud.hex_draft.cards[0].select,"select_hex",true):return
 if not await wait_page("skills"):return
 if state().selected_hex.size()!=1:failure="hex_selection_missing";return
 await shot("skills")
 if not await click(room.initial_hud.q_choices["Q1"].upgrade,"learn_Q1",true):return
 if state().points!=0 or int(room.sim.hero.ranks.q)!=1:failure="original_learning_result";return
 if not await click(pages.done,"skills_done"):return
 if not await wait_page("map"):return
 await shot("map")
 if not await click(pages.done,"map_done"):return
 if not await wait_page("room"):return
 await key(KEY_K)
 if not await wait_page("skills"):return
 await key(KEY_M)
 if not await wait_page("map"):return
 if not room.route_map.buttons.has("r01a"):failure="r01a_missing";return
 if not await click(room.route_map.buttons["r01a"],"select_r01a",true):return
 if not await click(room.session_next,"enter_r01a",true):return
 if not await wait_page("room"):return
 if str(room.shop_session.status)!="combat":failure="combat_not_entered";return
 record("first_combat")
 await shot("first_combat")
 if room.session_equipment.text.contains("\n") or not room.session_equipment.text.begins_with("装备 "):failure="equipment_not_single_line";return
 await equipment_tooltip()
func equipment_tooltip() -> void:
 var target: Control=room.session_equipment as Control
 var rect: Rect2=target.get_global_rect().intersection(root.get_visible_rect())
 if rect.size.x<2 or rect.size.y<2 or not target.is_visible_in_tree() or target.tooltip_text.is_empty():failure="equipment_tooltip_target";return
 var pos: Vector2=rect.get_center()
 var move:=InputEventMouseMotion.new();move.position=pos;move.global_position=pos;root.push_input(move,true)
 var begun: int=Time.get_ticks_msec()
 var texts: Array=[]
 var hover: Control
 var popup: Window
 var scanned: int=0
 var window_rows: Array=[]
 while Time.get_ticks_msec()-begun<1000 and failure.is_empty():
  await frame()
  hover=root.gui_get_hovered_control()
  texts.clear()
  var queue: Array[Node]=[root]
  scanned=0;window_rows.clear()
  while not queue.is_empty() and scanned<4096:
   var node: Node=queue.pop_front()
   scanned+=1
   for child: Node in node.get_children(true):queue.append(child)
   if node is Window and node!=root:
    var window: Window=node as Window
    if window.visible and window_rows.size()<32:window_rows.append({"path":str(window.get_path()),"position":[window.position.x,window.position.y],"size":[window.size.x,window.size.y]})
   if node is Label:
    var label: Label=node as Label
    var owner_window: Window=label.get_window()
    if owner_window!=root and owner_window.visible and label.is_visible_in_tree():
     texts.append(label.text)
     if label.text==target.tooltip_text:popup=owner_window
  if not queue.is_empty():failure="tooltip_tree_scan_budget";break
  if hover==target and target.tooltip_text in texts:break
 tooltip_observation={"target_path":str(target.get_path()),"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"mouse":[pos.x,pos.y],"hover_path":str(hover.get_path()) if is_instance_valid(hover) else "","tooltip_text":target.tooltip_text,"visible_popup_texts":texts.duplicate(),"wait_ms":Time.get_ticks_msec()-begun,"mouse_filter":target.mouse_filter,"include_internal":true,"scanned_nodes":scanned,"visible_windows":window_rows,"popup_path":str(popup.get_path()) if is_instance_valid(popup) else ""}
 if hover!=target or target.tooltip_text not in texts:failure="actual_equipment_tooltip_not_observed"
 elif failure.is_empty() and is_instance_valid(popup):await shot("equipment_tooltip",popup)
func run() -> void:
 if DisplayServer.get_name()=="headless" or not evidence.is_absolute_path() or DirAccess.dir_exists_absolute(evidence):quit(4);return
 if DirAccess.make_dir_recursive_absolute(evidence)!=OK:quit(4);return
 await exercise()
 var report: Dictionary={"scope":"SOURCE09_UI_LOADING_ROUTE_ONLY","accepted":failure.is_empty(),"reason":failure,"observations":observations,"images":images,"draws":draws,"elapsed_ms":Time.get_ticks_msec()-started,"full_floor_tested":false,"loading":loading_report,"equipment_tooltip":tooltip_observation}
 var bytes: PackedByteArray=(JSON.stringify(report,"  ")+"\n").to_utf8_buffer()
 print("UI_REPORT_BYTES ",bytes.size()," cap=131072")
 if bytes.size()>131072:print("UI_REPORT_CAP_REJECT ",bytes.size());quit(4);return
 var f: FileAccess=FileAccess.open(evidence.path_join("report.json"),FileAccess.WRITE)
 if f==null:print("UI_REPORT_OPEN_FAILED ",FileAccess.get_open_error());quit(4);return
 f.store_buffer(bytes);f.flush();var error: Error=f.get_error();f.close()
 var valid: bool=error==OK and FileAccess.get_file_as_bytes(evidence.path_join("report.json"))==bytes
 print("UI_REPORT_WRITE_ERROR ",error," readback_equal=",valid)
 print("SOURCE09_UI_LOADING_FINAL accepted=",report.accepted," io=",valid)
 quit(0 if report.accepted and valid else 4)
