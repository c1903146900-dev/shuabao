extends SceneTree
# Script-assisted NORMAL boot, route, combat inputs and UI actions.
# Reads accepted runtime state. Never writes hero/enemy/HP/camera/viewport state.
# Not manual/OS-input, full-floor, or Windows acceptance.
# Launch only under the parent's unchanged guard. No upload/network code.
# Required private output: -- --observer-output=/absolute/path/private_captures/run_name
const CAPTURE_LIMIT:int=40
const SAMPLE_INTERVAL:float=0.6
const OBSERVATION_SECONDS:float=24.0
const ROUTE_TIMEOUT:float=550.0
var elapsed:float=0.0
var tick:float=0.0
var entry:Node
var host:Node
var started:bool=false
var shops:Dictionary={}
var route:Array=[]
var purchases:int=0
var used:int=0
var logged:float=0.0
var watching:bool=false
var counts:Dictionary={}
var sample_at:float=0.0
var combat_started:float=-1.0
var output_dir:String=""
var output_file:FileAccess
var capture_pending:bool=false
var captures:int=0
var stopping:bool=false
var pass_stage:String="combat"
var north_pass_started:bool=false
var north_pass_completed:bool=false
var support_zone_sampled:bool=false
var seen_support:bool=false
var seen_zone:bool=false
var observed_errors:Array=[]

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
 print("HUD_VIS_",kind.to_upper()," ",line)

func _setup_output()->bool:
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--observer-output="):output_dir=arg.trim_prefix("--observer-output=").simplify_path()
 # Require deliberately private local evidence storage, never res:// or a URL.
 if not output_dir.is_absolute_path() or not "/private_captures/" in output_dir or "://" in output_dir:
  print("FINAL HUD_VIS_FAIL required_absolute_private_captures_output");quit(9);return false
 if DirAccess.make_dir_recursive_absolute(output_dir)!=OK:
  print("FINAL HUD_VIS_FAIL output_directory_unwritable");quit(9);return false
 var receipt_path:String=output_dir.path_join("observations.jsonl")
 if FileAccess.file_exists(receipt_path):
  print("FINAL HUD_VIS_FAIL fresh_output_directory_required");quit(9);return false
 output_file=FileAccess.open(receipt_path,FileAccess.WRITE)
 if output_file==null:
  print("FINAL HUD_VIS_FAIL observations_unwritable");quit(9);return false
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

func _overlap(rect:Rect2,control:Control)->Dictionary:
 if not is_instance_valid(control) or not control.is_visible_in_tree():return {"area":0.0,"fraction":0.0}
 var ui:Rect2=_bounds(_corners(Rect2(Vector2.ZERO,control.size),control.get_global_transform_with_canvas()))
 var area:float=rect.intersection(ui).get_area() if rect.intersects(ui) else 0.0
 return {"area":area,"fraction":area/maxf(0.000001,rect.get_area())}

func _potion_buttons()->Array:
 var rows:Array=[]
 for child:Node in host.ordinary_potion_controls.get_children():
  if child is Button:rows.append(_control(child))
 return rows

func _enemy_rows()->Array:
 var rows:Array=[]
 var body_regions:Array=host.presentation.body_pick_regions
 var canvas:Transform2D=host.presentation.get_global_transform_with_canvas()
 for enemy:Dictionary in host.sim.living():
  var row:Dictionary={"id":enemy.actor_id,"kind":enemy.kind,"position":enemy.position,"state":enemy.state,"hp":enemy.hp,"foot_projection":host.camera.unproject_position(enemy.position),"body_regions":[]}
  for region:Dictionary in body_regions:
   if str(region.get("actor_id",""))!=str(enemy.actor_id):continue
   if not region.has_all(["transform","destination"]):continue
   var transform:Transform2D=canvas*Transform2D(region.transform)
   var points:Array=_corners(Rect2(region.destination),transform)
   var rect:Rect2=_bounds(points)
   row.body_regions.append({"texture_key":str(region.get("texture","")),"source":region.get("source",Rect2()),"destination":region.destination,"transform":transform,"corners":points,"rect":rect,"hud_overlap":_overlap(rect,host.initial_hud.bottom_bar),"potion_overlap":_overlap(rect,host.ordinary_potion_controls),"bounds_kind":"Drawn texture quad AABB; transparent pixels are not an occlusion verdict."})
  rows.append(row)
 return rows

func _zone_rows()->Array:
 var rows:Array=[]
 for zone:Dictionary in host.sim.zones:
  var row:Dictionary=zone.duplicate(true)
  if zone.get("position") is Vector3 and zone.has("radius"):
   var boundary:Array=[]
   for index:int in range(32):
    var angle:float=TAU*float(index)/32.0
    boundary.append(host.camera.unproject_position(zone.position+Vector3(cos(angle),0,sin(angle))*float(zone.radius)))
   var rect:Rect2=_bounds(boundary)
   row.merge({"center_projection":host.camera.unproject_position(zone.position),"projected_boundary":boundary,"projected_rect":rect,"hud_overlap":_overlap(rect,host.initial_hud.bottom_bar),"potion_overlap":_overlap(rect,host.ordinary_potion_controls),"bounds_kind":"Projected source disc AABB; screenshot is needed for actual pixel visibility."})
  rows.append(row)
 return rows

func watch(event:Dictionary)->void:
 if stopping:return
 var kind:String=str(event.get("kind",""))
 counts[kind]=int(counts.get(kind,0))+1
 # Keep event detail private and small. Runtime telemetry is not public backup.
 if combat_started>=0 and kind in ["enemy_zone_landed","enemy_shot","enemy_warning","damage","encounter_finished"]:_record("event",event.duplicate(true))

func _capture_completed_draw()->void:
 capture_pending=true
 await RenderingServer.frame_post_draw
 if stopping or not is_instance_valid(host):capture_pending=false;return
 if str(host.sim.room_id).ends_with("r08a") and host.sim.phase=="combat":
  var enemies:Array=_enemy_rows()
  var zones:Array=_zone_rows()
  var support_alive:bool=false
  for enemy:Dictionary in enemies:
   if enemy.kind=="support":support_alive=true
  seen_support=seen_support or support_alive
  seen_zone=seen_zone or not zones.is_empty()
  if north_pass_started and support_alive and not zones.is_empty():support_zone_sampled=true
  var errors:Array=host.presentation.receipt.get("errors",[])
  for error:Variant in errors:
   if not observed_errors.has(error):observed_errors.append(error)
  var row:Dictionary={"index":captures,"elapsed":elapsed,"observation_elapsed":elapsed-combat_started,"completed_draw":true,"draw_frame":Engine.get_frames_drawn(),"process_frame":Engine.get_process_frames(),"room":host.sim.room_id,"phase":host.sim.phase,"world_time":host.sim.clock.world_time,"receipt_source_time":host.presentation.receipt.get("source_time",-1),"hero":host.sim.hero.position,"hp":host.sim.hero.hp,"pass_stage":pass_stage,"camera_target":host.camera_target,"camera_position":host.camera.global_position,"camera_size":host.camera.size,"camera_projection":host.camera.projection,"viewport":_viewport(),"hud":_control(host.initial_hud.bottom_bar),"potions":_control(host.ordinary_potion_controls),"potion_buttons":_potion_buttons(),"enemies":enemies,"zones":zones,"visual_errors":errors,"body_pick_scope":host.presentation.body_pick_scope}
  var image:Image=root.get_texture().get_image()
  if image==null or image.is_empty():capture_pending=false;fail("empty_completed_draw_image");return
  var filename:String="frame_%03d.png"%captures
  if image.save_png(output_dir.path_join(filename))!=OK:capture_pending=false;fail("screenshot_write_failed");return
  row["image"]=filename;row["image_size"]=image.get_size()
  captures+=1
  _record("sample",row)
 capture_pending=false

func sample_battle()->void:
 if not is_instance_valid(host) or host.sim==null:return
 if host.sim.phase=="combat" and str(host.sim.room_id).ends_with("r08a") and combat_started<0:
  combat_started=elapsed;sample_at=elapsed
  _record("observation_started",{"elapsed":elapsed,"route":route,"room":host.sim.room_id,"max_frames":CAPTURE_LIMIT,"interval":SAMPLE_INTERVAL,"seconds":OBSERVATION_SECONDS})
 if combat_started<0 or capture_pending or captures>=CAPTURE_LIMIT or elapsed<sample_at:return
 sample_at=elapsed+SAMPLE_INTERVAL
 _capture_completed_draw()

func finish_review()->void:
 if capture_pending:return
 var attained:bool=captures>=30 and north_pass_started and north_pass_completed and support_zone_sampled and observed_errors.is_empty()
 _end("observed_normal_camera_north_pass" if attained else "observation_nonattainment",0 if attained else 9)

func _end(reason:String,code:int)->void:
 if stopping:return
 stopping=true
 if is_instance_valid(host) and host.input_router!=null:release()
 _record("final",{"accepted":code==0,"reason":reason,"elapsed":elapsed,"observation_elapsed":elapsed-combat_started if combat_started>=0 else -1.0,"captures":captures,"route":route,"north_pass_started":north_pass_started,"north_pass_completed":north_pass_completed,"support_zone_sampled":support_zone_sampled,"seen_support":seen_support,"seen_zone":seen_zone,"visual_errors":observed_errors,"event_counts":counts,"limits":"Normal script-assisted route, not human/full-floor acceptance. Pixel occlusion requires screenshot review; guard result is separate."})
 if output_file!=null:output_file.close();output_file=null
 print("FINAL HUD_VIS_", "PASS" if code==0 else "FAIL", " ",reason)
 if is_instance_valid(host):host.frontdoor_close_run("compact_hud_visibility_observer")
 quit(code)

func fail(reason:String)->void:_end(reason,9)

func key(k:int,on:bool,aim:Vector3=Vector3.INF)->void:
 var e:=InputEventKey.new();e.physical_keycode=k;e.keycode=k;e.pressed=on;host.input_router.handle_event(e,aim,host._blocked())
func press(k:int,aim:Vector3)->void:key(k,true,aim);key(k,false,aim)
func release()->void:
 for k in [KEY_W,KEY_A,KEY_S,KEY_D]:key(k,false)
 var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=false;host.input_router.handle_event(e)
func walk(target:Vector3,stop:float=.15)->void:
 var p:Vector3=host.sim.hero.position
 if p.distance_to(target)<stop:
  for k in [KEY_W,KEY_A,KEY_S,KEY_D]:key(k,false)
  return
 var best:=Vector3.ZERO;var score:float=-INF
 for v in [Vector3(0,0,-1),Vector3(1,0,-1).normalized(),Vector3(1,0,0),Vector3(1,0,1).normalized(),Vector3(0,0,1),Vector3(-1,0,1).normalized(),Vector3(-1,0,0),Vector3(-1,0,-1).normalized()]:
  var at:Vector3=host.sim._move_clipped(p,p+v*.7,host.sim.hero_radius)
  var value:float=p.distance_to(target)-at.distance_to(target)
  if at.distance_to(p)<.05:value-=10
  if value>score:score=value;best=v
 key(KEY_W,best.z<-.2,target);key(KEY_S,best.z>.2,target);key(KEY_A,best.x<-.2,target);key(KEY_D,best.x>.2,target)
func learn()->void:
 var s:Dictionary=host.shop_session.ledger.model.state
 if int(s.points)<=0:return
 var choices:Array=[]
 if int(s.level)>=7 and int(s.skills.R.rank)==0:choices.append(["R","R1"])
 if int(s.skills.E.rank)==0:choices.append(["E","E2"])
 if int(s.skills.Q.rank)==0:choices.append(["Q","Q2"])
 if int(s.skills.P.rank)==0:choices.append(["P","P2"])
 choices.append_array([["E","E2"],["Q","Q2"],["P","P2"]])
 for c in choices:
  var rank:int=s.skills[c[0]].rank
  host.initial_hud.adapter.request("learn",{"slot_id":c[0],"candidate_id":c[1],"expected_rank":rank})
  if int(host.shop_session.ledger.model.state.skills[c[0]].rank)>rank:print("LEARN ",c);break
func shop()->void:
 var s=host.shop_session
 if shops.has(s.active_node_room) or s.shop_location_reason()!="":return
 shops[s.active_node_room]=true
 if int(s.ledger.model.state.gold)<200:return
 release();host._shop(true)
 if not s.panel_open:return
 host.shop_panel._select("potion:1")
 for n in range(2):
  if host.shop_panel._buy.disabled:break
  host.shop_panel._buy.pressed.emit();purchases+=1
 host._shop(false)
func _initialize()->void:
 if not _setup_output():return
 _record("configuration",{"max_frames":CAPTURE_LIMIT,"sample_interval":SAMPLE_INTERVAL,"observation_seconds":OBSERVATION_SECONDS,"route_timeout":ROUTE_TIMEOUT,"script_assisted":true,"state_injection":false,"viewport_mutation":false})
 root.add_child(load("res://boot.tscn").instantiate())
func _process(dt:float)->bool:
 if stopping:return false
 elapsed+=dt;tick+=dt
 sample_battle()
 if combat_started>=0 and elapsed-combat_started>=OBSERVATION_SECONDS:
  finish_review();return false
 if elapsed>ROUTE_TIMEOUT:fail("timeout");return false
 if combat_started>=0 and (not str(host.sim.room_id).ends_with("r08a") or host.sim.phase!="combat"):
  fail("target_encounter_ended_before_observation");return false
 if tick<.12:return false
 tick=0
 if entry==null:
  var boot=root.get_node_or_null("Boot")
  if boot!=null:
   for c in boot.get_children():
    if c.get("screen")!=null:entry=c
  return false
 if not started:started=true;entry._start.pressed.emit();return false
 host=entry.active_room
 if host==null:return false
 if not watching:host.sim.combat_event.connect(watch);watching=true
 if not host.floor_error.is_empty() or not host.startup_session_error.is_empty():fail("host_fault");return false
 var s=host.shop_session;var sim=host.sim
 if s.status in ["faulted","defeated"]:fail(s.status);return false
 if s.status=="completed":
  fail("route_completed_without_target_observation");return false
 if elapsed-logged>5:logged=elapsed;print("PROGRESS ",elapsed," ",s.active_node_room," HP=",sim.hero.hp," enemies=",sim.living().size())
 if s.initial_modal_open:
  release()
  if host.initial_hud.hex_draft.visible:host.initial_hud.hex_draft.selected.emit(0)
  return false
 learn()
 if s.status=="service":release();shop();host.service_continue.pressed.emit();return false
 if s.exit_map_open:
  release();var choices:Array=s.available_choices()
  if choices.is_empty():fail("no_choices");return false
  var id:String=str(choices[0].node_id)
  for c in choices:
   if str(c.node_id).ends_with("a") or str(c.node_id)=="r12boss":id=str(c.node_id)
  if host.route_map.buttons[id].disabled:fail("disabled_choice");return false
  host.route_map.buttons[id].pressed.emit();route.append(id);return false
 if sim.phase in ["preparation","victory"]:shop();walk(Vector3(0,0,-11));return false
 if sim.phase!="combat":return false
 # Reproduce the specific south-to-north camera travel through NORMAL movement.
 # Stop attacking during this final pass; never relocate or keep enemies alive by writes.
 if combat_started>=0 and elapsed-combat_started>=18.0:
  if pass_stage=="combat":pass_stage="approach_south"
  if pass_stage=="approach_south":
   walk(Vector3(-4.95,0,3.34),.65)
   if sim.hero.position.distance_to(Vector3(-4.95,0,3.34))<.85:
    north_pass_started=true;pass_stage="north_pass"
    _record("north_pass_started",{"elapsed":elapsed,"hero":sim.hero.position})
  elif pass_stage=="north_pass":
   walk(Vector3(-4.23,0,-3.34),.65)
   if sim.hero.position.distance_to(Vector3(-4.23,0,-3.34))<.85:
    north_pass_completed=true;pass_stage="north_hold";release()
    _record("north_pass_completed",{"elapsed":elapsed,"hero":sim.hero.position})
  else:release()
  return false
 var live:Array=sim.living()
 if live.is_empty():release();return false
 var target:Dictionary=live[0]
 for e in live:
  if sim.hero.position.distance_to(e.position)<sim.hero.position.distance_to(target.position):target=e
 var aim:Vector3=target.position;var distance:float=sim.hero.position.distance_to(aim);var evade:bool=false
 for threat in live:
  if str(threat.state)=="warning" and float(threat.warning_progress)>.20 and sim.hero.position.distance_to(threat.position)<float(threat.attack_range)+2:
   var side:=Vector3(-float(threat.aim.z),0,float(threat.aim.x));var a:Vector3=sim._move_clipped(sim.hero.position,sim.hero.position+side*2.2,sim.hero_radius);var b:Vector3=sim._move_clipped(sim.hero.position,sim.hero.position-side*2.2,sim.hero_radius)
   walk(a if a.distance_to(sim.hero.position)>=b.distance_to(sim.hero.position) else b)
   if float(threat.timer)<.25 and float(sim.hero.cooldowns.shift)<=0:press(KEY_SHIFT,aim)
   evade=true;break
 if not evade:walk(aim,1.45)
 if sim.hero.hp<sim.hero.stats.max_hp*.7:
  for button in host.ordinary_potion_controls.get_children():
   if button is Button and not button.disabled and host.ordinary_potion_controls.visible:
    button.pressed.emit()
    if s.last_receipt.get("accepted",false):used+=1
    break
 if not str(sim.room_id).ends_with("r08a") and distance<7 and float(sim.hero.cooldowns.e)<=0 and not sim.hero.cast_state.has("e2_shadow"):press(KEY_E,aim)
 if not str(sim.room_id).ends_with("r08a") and distance<9 and float(sim.hero.cooldowns.q)<=0:press(KEY_Q,aim)
 if not str(sim.room_id).ends_with("r08a") and distance<7 and float(sim.hero.cooldowns.r)<=0:press(KEY_R,aim)
 var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
 if distance<2.4:host.input_router.handle_event(event,aim,false)
 event.pressed=false;host.input_router.handle_event(event,aim,false)
 return false
