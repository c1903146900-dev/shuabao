extends RefCounted
## Synthetic player input only. Never a Sim owner and never native-device proof.
## Host performs its unchanged held-basic update and its one original source tick.
const ROOM_LAYOUT := "res://tests/ink_first_floor_room_art_20261004/room_layout.json"
const INPUT_INTERVAL_MS := 120
var host
var deadline_ms: int=0
var next_input_ms: int=0
var receipts: Array=[]
var visibility_log: Array=[]
var failure: String=""
var pressed_keys: Dictionary={}
var left_held: bool=false
var orbit_sign: float=1.0
var gesture: Dictionary={}
var wall_boxes: Array=[]

func bind_existing(actual_host, absolute_deadline_ms: int) -> void:
 host=actual_host;deadline_ms=absolute_deadline_ms
 var layout: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOM_LAYOUT))
 # Conservative camera occlusion uses authored solids' maximum visible height.
 # All gameplay collision remains the original source's responsibility.
 for row: Dictionary in layout.get("obstacles",[]):
  var at: Vector3=Vector3(row.position[0],0.0,row.position[2])
  var half: Vector3=Vector3(row.half[0],0.0,row.half[2])
  wall_boxes.append({"min":at-half,"max":at+half+Vector3.UP*float(row.height_range[1])})
 for row: Dictionary in layout.get("closed_boundary_gates",[]):
  var size: Vector3=Vector3(row.size[0],row.size[1],row.size[2])
  var at: Vector3=Vector3(row.center[0],0.0,row.center[2])
  wall_boxes.append({"min":at-Vector3(size.x/2.0,0.0,size.z/2.0),"max":at+Vector3(size.x/2.0,size.y,size.z/2.0)})

func _record(action: String, details: Dictionary, result: Dictionary) -> void:
 receipts.append({"wall_ms":Time.get_ticks_msec(),"hero_time":host.sim.hero_time,"action":action,"details":details.duplicate(true),"result":result.duplicate(true),"synthetic_player_input":true})
 if receipts.size()>12000:failure="input_receipt_capacity_exceeded"

func _hud_request(action: String, payload: Dictionary) -> Dictionary:
 var count: int=host.initial_actions.size()
 host.initial_hud.adapter.request(action,payload)
 if host.initial_actions.size()<=count:return {"accepted":false,"reason":"original_controller_receipt_missing"}
 var row: Dictionary=host.initial_actions.back()
 var result: Dictionary=row.get("result",{}).duplicate(true)
 if str(row.get("request",{}).get("action",""))!=action:return {"accepted":false,"reason":"unexpected_controller_receipt"}
 _record("HUD:"+action,payload,result)
 return result

func prepare_first_room() -> Dictionary:
 while Time.get_ticks_msec()<deadline_ms:
  if not is_instance_valid(host) or host.finished:return {"accepted":false,"reason":"actual_host_unavailable"}
  if not host._mainprep_required and is_instance_valid(host.initial_hud) and host.initial_hud.hex_draft.is_visible_in_tree() and host.initial_hud.projection.get("choices",[]).size()==4:break
  await host.get_tree().process_frame
 if Time.get_ticks_msec()>=deadline_ms:return {"accepted":false,"reason":"original_visible_hex_not_ready_before_deadline"}
 var shown: Dictionary=host.initial_hud.projection.duplicate(true)
 if int(shown.get("active_milestone",0))!=1:return {"accepted":false,"reason":"initial_visible_milestone_required"}
 # Fixed visible second offered card; no offer refresh, RNG or forced Hex ID.
 var choice: Dictionary=shown.choices[1].duplicate(true)
 var selected: Dictionary=_hud_request("hex_select",{"milestone":1,"slot":1})
 if not selected.get("accepted",false):return selected
 await host.get_tree().process_frame
 var state: Dictionary=host.shop_session.ledger.model.snapshot()
 if state.selected_hex!=[choice.id] or int(state.points)!=1:return {"accepted":false,"reason":"original_selected_hex_or_one_SP_mismatch"}
 var button: Button=host.initial_hud.q_choices.Q1.upgrade
 if not button.is_visible_in_tree() or button.disabled:return {"accepted":false,"reason":"actual_Q1_learning_button_unavailable"}
 var learned: Dictionary=_hud_request("learn",{"slot_id":"Q","candidate_id":"Q1","expected_rank":0})
 if not learned.get("accepted",false):return learned
 await host.get_tree().process_frame
 state=host.shop_session.ledger.model.snapshot()
 if int(state.gold)!=0 or int(state.xp)!=0 or int(state.level)!=1 or int(state.points)!=0 or int(state.skills.Q.rank)!=1 or state.skills.Q.candidate!="Q1" or not state.inventory.is_empty() or not state.body.is_empty():
  return {"accepted":false,"reason":"original_zero_resource_Q1_learning_contract_failed"}
 host._select_row(1,"r01a")
 _record("Host:_select_row",{"row":1,"node":"r01a"},host.shop_session.last_receipt)
 if not host.shop_session.last_receipt.get("accepted",false):return host.shop_session.last_receipt.duplicate(true)
 host._request_next_room()
 _record("Host:_request_next_room",{},host.shop_session.last_receipt)
 if host.shop_session.status!="combat":return {"accepted":false,"reason":"original_r01a_entry_failed","receipt":host.shop_session.last_receipt.duplicate(true)}
 return {"accepted":true,"selected_visible_choice":choice,"original_learning_state":state,"input_replay":true,"native_input":false,"deadline_ms":deadline_ms}

func _segment_hits_box(a: Vector3, b: Vector3, low: Vector3, high: Vector3) -> bool:
 var t_min: float=0.0
 var t_max: float=1.0
 var delta: Vector3=b-a
 for axis in range(3):
  if absf(delta[axis])<0.00001:
   if a[axis]<low[axis] or a[axis]>high[axis]:return false
  else:
   var first: float=(low[axis]-a[axis])/delta[axis]
   var last: float=(high[axis]-a[axis])/delta[axis]
   t_min=maxf(t_min,minf(first,last));t_max=minf(t_max,maxf(first,last))
   if t_min>t_max:return false
 return true

func _unoccluded(a: Vector3, b: Vector3) -> bool:
 for box: Dictionary in wall_boxes:
  if _segment_hits_box(a,b,box.min,box.max):return false
 return true

func _ground_clear(a: Vector3, b: Vector3, margin: float=0.0) -> bool:
 var edge: float=float(host.sim.arena_half_extent)-margin
 if absf(b.x)>=edge or absf(b.z)>=edge:return false
 for obstacle: Dictionary in host.sim.obstacles:
  var half: Vector3=obstacle.half+Vector3(margin,1.0,margin)
  if _segment_hits_box(a,b,obstacle.position-half,obstacle.position+half):return false
 return true

func _visible_ground(point: Vector3) -> Dictionary:
 var camera: Camera3D=host.stage.camera
 if not point.is_finite() or camera.is_position_behind(point) or not camera.is_position_in_frustum(point):return {}
 var pixel: Vector2=camera.unproject_position(point)
 if not host.get_viewport().get_visible_rect().grow(-24.0).has_point(pixel) or host._gui_blocks_pointer_at(pixel):return {}
 var projected: Vector3=host.stage.ground_point(pixel)
 if not projected.is_finite() or projected.distance_to(point)>0.03:return {}
 if not _ground_clear(point,point) or not _unoccluded(camera.project_ray_origin(pixel),point+Vector3.UP*0.03):return {}
 return {"point":point,"pixel":pixel}

func _visible_enemies() -> Array:
 var visible: Array=[]
 var camera: Camera3D=host.stage.camera
 # Only rendered actor views are inspected. No sim.enemies/living()/enemy_by_id.
 var views: Dictionary=host.enemy_layer.roster.actor_view_map()
 for id: String in views:
  var view: Node3D=views[id]
  if not is_instance_valid(view) or not view.is_visible_in_tree():continue
  var at: Vector3=view.global_position
  var ground: Dictionary=_visible_ground(at)
  if ground.is_empty():continue
  var torso: Vector3=at+Vector3.UP*0.65
  if not camera.is_position_in_frustum(torso) or not _unoccluded(camera.project_ray_origin(camera.unproject_position(torso)),torso):continue
  if not _ground_clear(host.sim.hero.position,at):continue
  # Read displayed alive/animation information only after the visual gate.
  var shown: Dictionary=view.sample_report
  if bool(shown.get("dead",true)) or bool(shown.get("cleanup",true)) or shown.get("status","")!="ready":continue
  visible.append({"id":id,"position":at,"pixel":ground.pixel,"clip":shown.get("clip",""),"distance":host.sim.hero.position.distance_to(at)})
 visible.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:return float(a.distance)<float(b.distance))
 return visible

func _route(event: InputEvent, action: String) -> Dictionary:
 var pixel: Variant=null
 if event is InputEventMouse:
  pixel=event.position
  # This is the same public pointer-observer call as the original Host _input.
  # It supplies current-camera held aim without an extra update_held_basic call.
  host.mouse_aim.observe(event,host.get_viewport().get_visible_rect().size)
 var blocked: bool=event is InputEventMouse and (not host.mouse_aim.accepts(event.position) or host._gui_blocks_pointer_at(event.position))
 var result: Dictionary=host.input_router.route_event(event,host.stage.ground_point,host._current_pointer_ground(),blocked)
 _record(action,{"event":event.as_text(),"pixel":pixel,"ground":host._current_pointer_ground(),"gui_blocked":blocked},result)
 return result

func _key(code: Key, down: bool) -> Dictionary:
 var event: InputEventKey=InputEventKey.new()
 event.physical_keycode=code;event.pressed=down
 return _route(event,"key:"+OS.get_keycode_string(code)+(":down" if down else ":up"))

func _mouse(point: Vector3, down: bool, motion: bool=false) -> Dictionary:
 var ground: Dictionary=_visible_ground(point)
 # An up outside the ground may still drain a held pair through the original
 # router, but the replay cancels any Q preview before using that fallback.
 if ground.is_empty():return {"accepted":false,"reason":"replay_point_not_visible"}
 var event: InputEventMouse
 if motion:
  event=InputEventMouseMotion.new()
  event.button_mask=MOUSE_BUTTON_MASK_LEFT if left_held else 0
 else:
  var button: InputEventMouseButton=InputEventMouseButton.new()
  button.button_index=MOUSE_BUTTON_LEFT;button.pressed=down;event=button
  left_held=down
 event.position=ground.pixel
 return _route(event,"mouse:motion" if motion else ("mouse:left_down" if down else "mouse:left_up"))

func _release_left() -> void:
 if not left_held:return
 var event: InputEventMouseButton=InputEventMouseButton.new()
 event.button_index=MOUSE_BUTTON_LEFT;event.pressed=false
 event.position=host.mouse_aim.position
 left_held=false
 _route(event,"mouse:left_up")

func _move(direction: Vector3) -> void:
 var wanted: Dictionary={KEY_W:direction.z < -0.30,KEY_S:direction.z > 0.30,KEY_A:direction.x < -0.30,KEY_D:direction.x > 0.30}
 for code: Key in [KEY_W,KEY_A,KEY_S,KEY_D]:
  if bool(pressed_keys.get(code,false))==bool(wanted[code]):continue
  _key(code,wanted[code]);pressed_keys[code]=wanted[code]

func _cancel_gesture() -> void:
 _key(KEY_ESCAPE,true);_key(KEY_ESCAPE,false)
 _release_left();_key(KEY_Q,false);gesture={}

func _plan_q1(visible: Array) -> Dictionary:
 var first: Vector3=visible[0].position
 var direction: Vector3=(first-host.sim.hero.position).normalized()
 var finish: Vector3=first+direction*1.2
 var ids: Array=[visible[0].id]
 if visible.size()>1 and first.distance_to(visible[1].position)>0.5:
  direction=(Vector3(visible[1].position)-first).normalized()
  finish=Vector3(visible[1].position)+direction*0.6
  ids.append(visible[1].id)
 var start: Vector3=first-direction*0.6
 if start.distance_to(host.sim.hero.position)>float(host.sim.tuning.q1_initial_placement_range_m)-0.1:return {}
 if start.distance_to(finish)>float(host.sim.v("Q1-4",1)):return {}
 if _visible_ground(start).is_empty() or _visible_ground(finish).is_empty() or not _ground_clear(start,finish):return {}
 return {"start":start,"finish":finish,"visible_ids":ids,"stage":0}

func advance_inputs() -> void:
 if Time.get_ticks_msec()>=deadline_ms or Time.get_ticks_msec()<next_input_ms:return
 next_input_ms=Time.get_ticks_msec()+INPUT_INTERVAL_MS
 if host.finished or host._mainprep_required or host.sim.phase!="combat" or host.sim.paused or host.sim.hero.dead or host.shop_session.panel_open or host.initial_hud.blocks_gameplay_input():return
 var visible: Array=_visible_enemies()
 visibility_log.append({"wall_ms":Time.get_ticks_msec(),"hero_time":host.sim.hero_time,"camera_transform":str(host.stage.camera.global_transform),"viewport_size":host.get_viewport().get_visible_rect().size,"visible_targets":visible.duplicate(true)})
 if not gesture.is_empty():
  var ids: Array=[]
  for enemy: Dictionary in visible:ids.append(enemy.id)
  for id: String in gesture.visible_ids:
   if id not in ids:_cancel_gesture();return
  if _visible_ground(gesture.start).is_empty() or _visible_ground(gesture.finish).is_empty():_cancel_gesture();return
  if int(gesture.stage)==0:
   var started: Dictionary=_mouse(gesture.start,true)
   if not started.get("accepted",false):_cancel_gesture();return
   gesture.stage=1
  elif int(gesture.stage)==1:
   _mouse(gesture.finish,false,true);gesture.stage=2
  else:
   _mouse(gesture.finish,false);_key(KEY_Q,false);gesture={}
  return
 if visible.is_empty():_release_left();_move(Vector3.ZERO);return
 var target: Dictionary=visible[0]
 var away: Vector3=(host.sim.hero.position-Vector3(target.position)).normalized()
 var desired: float=clampf(float(host.sim.hero.stats.attack_range)*0.60,3.5,6.5)
 var direction: Vector3=(Vector3(-away.z,0.0,away.x)*orbit_sign+away*clampf((desired-float(target.distance))/2.0,-1.0,1.0)).normalized()
 # One local step check and one tangent reversal, never global path planning.
 if not _ground_clear(host.sim.hero.position,host.sim.hero.position+direction,0.75) or _visible_ground(host.sim.hero.position+direction).is_empty():
  orbit_sign=-orbit_sign
  direction=Vector3(-away.z,0.0,away.x)*orbit_sign
  if not _ground_clear(host.sim.hero.position,host.sim.hero.position+direction,0.75) or _visible_ground(host.sim.hero.position+direction).is_empty():direction=Vector3.ZERO
 _move(direction)
 if float(host.sim.hero.cooldowns.q)<=0.00001 and float(host.sim.hero.lock_time)<=0.00001:
  var plan: Dictionary=_plan_q1(visible)
  if not plan.is_empty():
   _release_left()
   _mouse(plan.start,false,true)
   var armed: Dictionary=_key(KEY_Q,true)
   if armed.get("accepted",false):gesture=plan;return
   _key(KEY_Q,false)
 _mouse(target.position,false,true)
 if not left_held:_mouse(target.position,true)
