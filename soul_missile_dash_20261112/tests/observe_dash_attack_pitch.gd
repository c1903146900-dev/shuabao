extends SceneTree
# Native mouse/keyboard inspection window after ordinary first-room setup.
# No source-state injection, automatic combat, or synthetic pointer events.
var elapsed:float=0
var entry:Node
var host:Node
var state:int=0
var ready_at:float=-1
var attacks:int=0
var dashes:int=0
var traced_cast:int=-1
var traced_until:float=-1
var boundary_captured:Dictionary={}
var combat_setup_at:float=-1
var busy:bool=false
var serial:int=0
class PointerAudit extends Node:
 var owner_tree
 func _input(event:InputEvent)->void:
  if event is InputEventMouseButton or (event is InputEventKey and not event.echo):
   owner_tree.record_input(event)
func record_input(event:InputEvent)->void:
 if host==null:return
 if event is InputEventKey and event.physical_keycode==KEY_F8 and event.pressed:
  print("NATIVE_REVIEW_COMPLETE manual_observation_only");host.frontdoor_close_run("native_review_complete");quit();return
 print("NATIVE_HUD_INPUT ",JSON.stringify({"event":event.as_text(),"mouse":root.get_mouse_position(),"hovered":str(root.gui_get_hovered_control()),"attacks":attacks,"move":host.input_router.movement(),"points":host.shop_session.ledger.model.state.points,"phase":host.sim.phase,"popup":host.initial_hud.bottom_popup.visible}))
 if event is InputEventMouseButton and not event.pressed:capture.call_deferred("pointer_release")
func capture(label:String)->void:
 if busy or host==null:return
 busy=true
 await RenderingServer.frame_post_draw
 if not is_instance_valid(host):busy=false;return
 var hud:Node=host.initial_hud
 var rects:Dictionary={}
 for slot in hud.bottom_slots:rects[slot]={"tile":hud.bottom_slots[slot].get_global_rect(),"action":hud.bottom_actions[slot].get_global_rect(),"action_visible":hud.bottom_actions[slot].is_visible_in_tree(),"label":hud.bottom_labels[slot].text}
 var row:Dictionary={"label":label,"serial":serial,"elapsed":elapsed,"phase":host.sim.phase,"camera":host.camera.position,"viewport":root.get_visible_rect(),"physical_window":DisplayServer.window_get_size(),"screen_transform":root.get_screen_transform(),"image_size":root.get_texture().get_size(),"bar":hud.bottom_bar.get_global_rect(),"popup":hud.bottom_popup.get_global_rect(),"popup_visible":hud.bottom_popup.visible,"slots":rects,"potions":host.ordinary_potion_controls.get_children().filter(func(c):return c is Button).map(func(c):return {"text":c.text,"rect":c.get_global_rect(),"visible":c.is_visible_in_tree(),"disabled":c.disabled}),"attacks":attacks,"move":host.input_router.movement(),"last_receipt":host.input_router.last_receipt,"visual_event":host.presentation.animation,"puppet_receipt":host.presentation.receipt.get("puppet_motion",{}).duplicate(true),"dash_trail":host.presentation.dash_trail,"mirror":host.presentation._mirror,"hp":host.sim.hero.hp,"actor":host.sim.hero.snapshot(),"pointer":root.get_mouse_position(),"living":host.sim.living().map(func(e):return {"actor_id":e.actor_id,"hp":e.hp,"position":e.position})}
 root.get_texture().get_image().save_png("user://dash_contact_frame_%03d.png"%serial)
 print("NATIVE_HUD_FRAME ",JSON.stringify(row));serial+=1;busy=false
func contact_sequence()->void:
 for phase in ["dash_sample_050ms","dash_sample_100ms","dash_sample_150ms","dash_sample_200ms","dash_sample_250ms","dash_sample_300ms","dash_sample_350ms","dash_sample_400ms"]:
  await create_timer(0.05).timeout
  if host==null or not is_instance_valid(host):return
  await capture(phase)
func watch(event:Dictionary)->void:
 if str(event.get("kind",""))=="attack_started":
  attacks+=1;print("NATIVE_ATTACK ",JSON.stringify(event))
 if str(event.get("kind",""))=="dash_attack_started":
  dashes+=1
  traced_cast=int(event.cast_id);traced_until=float(event.real_time)+.55;boundary_captured.clear()
 if str(event.get("kind","")) in ["dash","dash_attack_started","attack_cancelled","damage"]:print("NATIVE_ACTION ",JSON.stringify(event))
func trace_render()->void:
 if host==null or traced_cast<0 or host.sim.real_time>traced_until:return
 var ev:Dictionary=host.presentation.animation
 var age:float=host.sim.real_time-(traced_until-.55)
 print("DASH_RENDER_TRACE ",JSON.stringify({"cast_id":traced_cast,"age":age,"source_time":host.sim.real_time,"facing":host.sim.hero.facing,"dash_left":host.sim.hero.dash_left,"invulnerable":host.sim.hero_damage_immune(),"iframe_left":host.sim.dash_iframe_left,"dash_step_immune":host.sim.dash_step_immune,"puppet":host.presentation.receipt.get("puppet_motion",{}).duplicate(true),"trail":host.presentation.dash_trail,"mirror":host.presentation._mirror}))
 var label:String="windup" if age>=.02 and age<.07 else "contact" if age>=.116 and age<.20 else "recover" if age>=.30 and age<.40 else "settled" if age>=.48 else ""
 if label!="" and not boundary_captured.has(label):
  boundary_captured[label]=true
  root.get_texture().get_image().save_png("user://dash_attack_pitch_cast_%d_%s.png"%[traced_cast,label])
func _initialize()->void:
 RenderingServer.frame_post_draw.connect(trace_render)
 root.add_child(load("res://boot.tscn").instantiate())
 root.size_changed.connect(func():capture.call_deferred("window_resized"))
func _process(dt:float)->bool:
 elapsed+=dt
 if elapsed>180:
  if host!=null:host.frontdoor_close_run("native_hud_timeout")
  print("NATIVE_HUD_END bounded_timeout_not_automatic_acceptance");quit();return false
 if entry==null:
  var boot=root.get_node_or_null("Boot")
  if boot!=null:
   for c in boot.get_children():
    if c.get("screen")!=null:entry=c
  return false
 if state==0:entry._start.pressed.emit();state=1;return false
 host=entry.active_room
 if host==null:return false
 if state==1:
  if host.shop_session.initial_modal_open:
   if host.initial_hud.hex_draft.visible:host.initial_hud.hex_draft.selected.emit(0)
   return false
  var audit:=PointerAudit.new();audit.owner_tree=self;root.add_child(audit)
  host.sim.combat_event.connect(watch);state=2;ready_at=elapsed
  capture.call_deferred("preparation_ready")
  print("NATIVE_HUD_SETUP ordinary_first_room")
 elif state==2:
  host.initial_hud.bottom_actions.E.pressed.emit();state=3
 elif state==3 and host.initial_hud.bottom_candidate_buttons.has("E2"):
  host.initial_hud.bottom_candidate_buttons.E2.pressed.emit();state=4
 elif state==4:
  host.initial_hud.bottom_popup.get_child(0).get_child(0).pressed.emit()
  var down:=InputEventKey.new();down.physical_keycode=KEY_W;down.keycode=KEY_W;down.pressed=true;host.input_router.handle_event(down)
  state=5
 elif state==5 and host.shop_session.exit_map_open:
  var up:=InputEventKey.new();up.physical_keycode=KEY_W;up.keycode=KEY_W;up.pressed=false;host.input_router.handle_event(up)
  var choices:Array=host.shop_session.available_choices()
  if not choices.is_empty():host.route_map.buttons[str(choices[0].node_id)].pressed.emit();state=6;combat_setup_at=elapsed
 elif state==6 and host.sim.phase=="combat" and elapsed-combat_setup_at>1.0:
  var pause:=InputEventKey.new();pause.physical_keycode=KEY_SPACE;pause.keycode=KEY_SPACE;pause.pressed=true;host._input(pause)
  pause.pressed=false;host._input(pause)
  state=7;capture.call_deferred("combat_paused_ready");print("NATIVE_HUD_READY paused_normal_first_combat")
 return false
