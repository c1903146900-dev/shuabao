extends SceneTree
# Short actual rendered UI check through normal Boot and existing Button signals.
# No combat state, viewport, scale, project, HUD layout or production writes.
# Not manual/OS-click acceptance. Parent owns physical resolutions and guard runs.
# Required fresh private output: -- --observer-output=/absolute/path/private_captures/run_name
const TIMEOUT_SECONDS:float=30.0
const CAPTURE_LIMIT:int=5
var elapsed:float=0.0
var tick:float=0.0
var entry:Node
var host:Node
var state:int=0
var state_since:float=0.0
var output_dir:String=""
var output_file:FileAccess
var capture_pending:bool=false
var captures:int=0
var stopping:bool=false
var checks:int=0
var points_before:int=-1
var rank_before:int=-1
var learn_clicked:bool=false

func _json_value(value:Variant)->Variant:
 if value is Resource:return {"resource_path":value.resource_path}
 if value is Object:return {"omitted_object_class":value.get_class()}
 if value is Vector2 or value is Vector2i:return [value.x,value.y]
 if value is Vector3 or value is Vector3i:return [value.x,value.y,value.z]
 if value is Rect2 or value is Rect2i:return [value.position.x,value.position.y,value.size.x,value.size.y]
 if value is Transform2D:return {"x":_json_value(value.x),"y":_json_value(value.y),"origin":_json_value(value.origin)}
 if value is Array or value is PackedVector2Array:
  var result:Array=[]
  for item:Variant in value:result.append(_json_value(item))
  return result
 if value is Dictionary:
  var result:Dictionary={}
  for key:Variant in value:result[str(key)]=_json_value(value[key])
  return result
 return value

func _record(kind:String,data:Dictionary)->void:
 var line:String=JSON.stringify(_json_value(data.merged({"record":kind},true)))
 if output_file!=null:output_file.store_line(line);output_file.flush()
 print("HUD_LAYOUT_",kind.to_upper()," ",line)

func _setup_output()->bool:
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--observer-output="):output_dir=arg.trim_prefix("--observer-output=").simplify_path()
 # Require deliberately private local evidence storage, never res:// or a URL.
 if not output_dir.is_absolute_path() or not "/private_captures/" in output_dir or "://" in output_dir:
  print("FINAL HUD_LAYOUT_FAIL required_absolute_private_captures_output");quit(9);return false
 if DirAccess.make_dir_recursive_absolute(output_dir)!=OK:
  print("FINAL HUD_LAYOUT_FAIL output_directory_unwritable");quit(9);return false
 var receipt_path:String=output_dir.path_join("observations.jsonl")
 if FileAccess.file_exists(receipt_path):
  print("FINAL HUD_LAYOUT_FAIL fresh_output_directory_required");quit(9);return false
 output_file=FileAccess.open(receipt_path,FileAccess.WRITE)
 if output_file==null:
  print("FINAL HUD_LAYOUT_FAIL observations_unwritable");quit(9);return false
 return true

func _bounds(points:Array)->Rect2:
 if points.is_empty():return Rect2()
 var rect:=Rect2(points[0],Vector2.ZERO)
 for point:Vector2 in points:rect=rect.expand(point)
 return rect

func _corners(rect:Rect2,transform:Transform2D)->Array:
 return [transform*rect.position,transform*Vector2(rect.end.x,rect.position.y),transform*rect.end,transform*Vector2(rect.position.x,rect.end.y)]

func _control(control:Control)->Dictionary:
 if not is_instance_valid(control):return {"valid":false}
 var points:Array=_corners(Rect2(Vector2.ZERO,control.size),control.get_global_transform_with_canvas())
 var physical:Array=_corners(Rect2(Vector2.ZERO,control.size),control.get_screen_transform())
 var result:Dictionary={"valid":true,"name":str(control.name),"class":control.get_class(),"visible":control.is_visible_in_tree(),"global_rect":control.get_global_rect(),"viewport_rect":_bounds(points),"screen_rect":_bounds(physical),"minimum_size":control.get_combined_minimum_size(),"mouse_filter":control.mouse_filter,"clip_contents":control.clip_contents}
 if control is Button:result.merge({"text":control.text,"disabled":control.disabled,"tooltip":control.tooltip_text})
 elif control is Label:result.merge({"text":control.text,"tooltip":control.tooltip_text,"font_size":control.get_theme_font_size("font_size"),"clip_text":control.clip_text})
 return result

func _viewport()->Dictionary:
 return {"visible_rect":root.get_visible_rect(),"texture_size":root.get_texture().get_size(),"window_size":root.size,"physical_window_size":DisplayServer.window_get_size(),"stretch_transform":root.get_stretch_transform(),"screen_transform":root.get_screen_transform(),"content_scale_size":root.content_scale_size,"content_scale_factor":root.content_scale_factor,"content_scale_mode":root.content_scale_mode,"note":"Actual launch viewport; observer does not resize or change stretch/project settings."}

func _effective_rect(control:Control)->Rect2:
 var rect:Rect2=_bounds(_corners(Rect2(Vector2.ZERO,control.size),control.get_global_transform_with_canvas()))
 rect=rect.intersection(root.get_visible_rect())
 var ancestor:Node=control.get_parent()
 while ancestor!=null:
  if ancestor is Control and ancestor.clip_contents:
   var clipped:Rect2=_bounds(_corners(Rect2(Vector2.ZERO,ancestor.size),ancestor.get_global_transform_with_canvas()))
   rect=rect.intersection(clipped)
  ancestor=ancestor.get_parent()
 return rect

func _collect_controls(node:Node,rows:Array)->void:
 if node is Control and node.is_visible_in_tree():
  if node is Label or node is Button or node is PanelContainer or node is ScrollContainer or node is ProgressBar:
   var row:Dictionary=_control(node)
   row["path"]=str(host.get_path_to(node))
   row["clipped_viewport_rect"]=_effective_rect(node)
   if node is Button:row["font_size"]=node.get_theme_font_size("font_size")
   rows.append(row)
 for child:Node in node.get_children():_collect_controls(child,rows)

func _capture(name:String)->void:
 capture_pending=true
 await RenderingServer.frame_post_draw
 if stopping:capture_pending=false;return
 if captures>=CAPTURE_LIMIT:capture_pending=false;_end("capture_limit",9);return
 var rows:Array=[]
 _collect_controls(host.initial_hud,rows)
 _collect_controls(host.ordinary_potion_controls,rows)
 var image:Image=root.get_texture().get_image()
 if image==null or image.is_empty():capture_pending=false;_end("empty_completed_draw_image",9);return
 var filename:String="%02d_%s.png"%[captures,name]
 if image.save_png(output_dir.path_join(filename))!=OK:capture_pending=false;_end("screenshot_write_failed",9);return
 captures+=1
 var model:Dictionary=host.shop_session.ledger.model.state
 _record("layout",{"stage":name,"elapsed":elapsed,"completed_draw":true,"draw_frame":Engine.get_frames_drawn(),"image":filename,"image_size":image.get_size(),"viewport":_viewport(),"phase":host.sim.phase,"hero_position":host.sim.hero.position,"initial_modal_open":host.shop_session.initial_modal_open,"bottom_popup_visible":host.initial_hud.bottom_popup.is_visible_in_tree(),"points":model.points,"skills":model.skills.duplicate(true),"controls":rows,"objective":_control(host.objective_label),"hud_receipt":host.initial_hud.receipt,"visual_errors":host.presentation.receipt.get("errors",[])})
 capture_pending=false

func _check(value:bool,label:String)->bool:
 checks+=1
 _record("check",{"label":label,"passed":value,"elapsed":elapsed})
 if not value:_end(label,9)
 return value

func _button_action(button:Button,label:String)->bool:
 if not _check(is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled,label+"_enabled"):return false
 var rect:Rect2=_effective_rect(button)
 # This observer does not bypass an offscreen/clipped action to claim clickability.
 if not _check(rect.get_area()>0.0,label+"_has_visible_clickrect"):return false
 _record("button_action",{"label":label,"action_kind":"existing_Button.pressed_signal_not_OS_click","control":_control(button),"clipped_viewport_rect":rect})
 button.pressed.emit()
 return true

func _next(next:int)->void:
 state=next;state_since=elapsed

func _end(reason:String,code:int)->void:
 if stopping:return
 stopping=true
 _record("final",{"accepted":code==0,"reason":reason,"elapsed":elapsed,"checks":checks,"captures":captures,"learn_clicked":learn_clicked,"limits":"Five completed-draw UI frames, current actual viewport, existing Button signals, no full-floor or manual-click verdict. Review rendered text and clipping in images."})
 if output_file!=null:output_file.close();output_file=null
 print("FINAL HUD_LAYOUT_", "PASS" if code==0 else "FAIL", " ",reason)
 if is_instance_valid(host):host.frontdoor_close_run("compact_hud_layout_observer")
 quit(code)

func _initialize()->void:
 if not _setup_output():return
 _record("configuration",{"max_frames":CAPTURE_LIMIT,"timeout_seconds":TIMEOUT_SECONDS,"state_injection":false,"viewport_mutation":false,"script_assisted_ui":true})
 root.add_child(load("res://boot.tscn").instantiate())

func _process(dt:float)->bool:
 if stopping:return false
 elapsed+=dt;tick+=dt
 if elapsed>TIMEOUT_SECONDS:_end("timeout",9);return false
 if capture_pending or tick<.12:return false
 tick=0.0
 if entry==null:
  var boot:Node=root.get_node_or_null("Boot")
  if boot!=null:
   for child:Node in boot.get_children():
    if child.get("screen")!=null:entry=child
  return false
 if state==0:
  if not _button_action(entry._start,"start_normal_run"):return false
  _next(1);return false
 host=entry.active_room
 if host==null:return false
 if not host.floor_error.is_empty() or not host.startup_session_error.is_empty():_end("host_fault",9);return false
 if host.shop_session.status in ["faulted","defeated"]:_end(str(host.shop_session.status),9);return false
 var hud:Control=host.initial_hud
 var session=host.shop_session
 var model:Dictionary=session.ledger.model.state
 if elapsed-state_since<.6:return false
 match state:
  1:
   if not session.initial_modal_open or not hud.hex_draft.is_visible_in_tree():return false
   _capture("initial_hex");_next(2)
  2:
   if not _check(hud.hex_draft.cards.size()==4,"four_initial_hex_choices"):return false
   if not _button_action(hud.hex_draft.cards[0].select,"select_initial_hex"):return false
   _next(3)
  3:
   if session.initial_modal_open:return false
   if not _check(host.sim.phase=="preparation","normal_preparation_after_hex"):return false
   points_before=int(model.points);rank_before=int(model.skills.E.rank)
   if not _check(points_before>0 and rank_before==0,"initial_learning_budget"):return false
   _capture("preparation");_next(4)
  4:
   if not _button_action(hud.bottom_actions.E,"open_E_learning"):return false
   _next(5)
  5:
   if not _check(hud.bottom_popup.is_visible_in_tree() and hud.bottom_candidate_buttons.has("E2"),"skill_candidates_open"):return false
   _capture("skill_candidates");_next(6)
  6:
   if not _button_action(hud.bottom_candidate_buttons.E2,"learn_E2_once"):return false
   learn_clicked=true;_next(7)
  7:
   if not _check(int(model.skills.E.rank)==rank_before+1 and str(model.skills.E.candidate)=="E2" and int(model.points)==points_before-1,"E2_learned_once_exact_point_cost"):return false
   if not _check(int(model.points)!=0 or hud.bottom_candidate_buttons.E2.disabled,"no_points_learning_disabled"):return false
   _capture("learned_skill");_next(8)
  8:
   var close:Button=hud.bottom_popup.get_child(0).get_child(0) as Button
   if not _button_action(close,"close_skill_details"):return false
   _next(9)
  9:
   if not _check(not hud.bottom_popup.is_visible_in_tree(),"skill_details_closed"):return false
   if not _check(int(model.skills.E.rank)==rank_before+1 and int(model.points)==points_before-1,"learning_not_repeated"):return false
   if not _check(host.sim.phase=="preparation","no_combat_or_room_skip"):return false
   _capture("closed_details");_next(10)
  10:
   if not _check(captures==CAPTURE_LIMIT,"five_completed_draw_views"):return false
   _end("normal_hex_and_learning_layout_observed",0)
 return false
