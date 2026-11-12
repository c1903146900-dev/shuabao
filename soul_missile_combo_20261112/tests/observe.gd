extends SceneTree
# Native mouse/keyboard inspection window after ordinary first-room setup.
# Explicit G16 selection/position/AI fixture; genuine learned Q1 and source projectile flight. Script-triggered input, not native/manual acceptance.
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
var pickup_at:float=-1.0
var launched_at:float=-1.0
var hits:int=0
var captured:int=0
var first_position:Vector3=Vector3.INF
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
func capture(label:String)->void:
 if busy or host==null:return
 busy=true
 await RenderingServer.frame_post_draw
 print("G16_FRAME ",JSON.stringify({"label":label,"phase":host.sim.phase,"source":host.sim.common.runtime.projectiles.duplicate(true),"g10_view":host.presentation.receipt.get("soul_pickups",{}),"view":host.presentation.receipt.get("common_missiles",{}).duplicate(true),"hp":host.sim.living().map(func(e):return {"id":e.actor_id,"hp":e.hp})}))
 root.get_texture().get_image().save_png("user://%s.png"%label)
 busy=false
func watch(event:Dictionary)->void:
 if str(event.get("kind",""))=="q1_started" or (str(event.get("kind",""))=="damage" and str(event.get("source",""))=="q1"):print("G16_TRIGGER_EVENT ",JSON.stringify(event))
 if str(event.get("source",""))=="common_g16":
  print("G16_EVENT ",JSON.stringify(event))
  if str(event.get("kind",""))=="damage" and float(event.get("amount",0))>0:hits+=1
func render_sample()->void:
 if host==null or state!=7:return
 var entries:Array=host.sim.common.runtime.projectiles
 if not entries.is_empty():
  var at:Vector3=entries[0].position
  if captured==0:
   first_position=at;captured=1;capture.call_deferred("first_source_missile")
  elif captured==1 and at.distance_to(first_position)>0.3:
   captured=2;capture.call_deferred("advanced_source_missile")
func _initialize()->void:
 RenderingServer.frame_post_draw.connect(render_sample)
 root.add_child(load("res://boot.tscn").instantiate())
func _process(dt:float)->bool:
 elapsed+=dt
 if elapsed>75:
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
  var fixture=load("res://fixture.gd").new()
  var checks16:Dictionary=fixture.run()
  print("G16_FIXTURE_RESULT ",JSON.stringify(checks16))
  var checks10:Dictionary=load("res://soul_fixture.gd").new().run()
  print("G10_FIXTURE_RESULT ",JSON.stringify(checks10))
  if not checks16.get("failures",[]).is_empty() or not checks10.get("failures",[]).is_empty():quit(5);return false
  host.shop_session.ledger.model.state.selected_hex=["common_g10","common_g16"]
  host.shop_session.ledger.refresh_runtime()
  var audit:=PointerAudit.new();audit.owner_tree=self;root.add_child(audit)
  host.sim.combat_event.connect(watch);state=2;ready_at=elapsed
  print("NATIVE_HUD_SETUP ordinary_first_room")
 elif state==2:
  host.initial_hud.bottom_actions.Q.pressed.emit();state=3
 elif state==3 and host.initial_hud.bottom_candidate_buttons.has("Q1"):
  host.initial_hud.bottom_candidate_buttons.Q1.pressed.emit();state=4
 elif state==4:
  host.initial_hud.bottom_popup.get_child(0).get_child(0).pressed.emit()
  var down:=InputEventKey.new();down.physical_keycode=KEY_W;down.keycode=KEY_W;down.pressed=true;host.input_router.handle_event(down)
  state=5
 elif state==5 and host.shop_session.exit_map_open:
  var up:=InputEventKey.new();up.physical_keycode=KEY_W;up.keycode=KEY_W;up.pressed=false;host.input_router.handle_event(up)
  var choices:Array=host.shop_session.available_choices()
  if not choices.is_empty():host.route_map.buttons[str(choices[0].node_id)].pressed.emit();state=6;combat_setup_at=elapsed
 elif state==6 and host.sim.phase=="combat" and elapsed-combat_setup_at>1.0:
  host.sim.ai_enabled=false
  host.sim.auto_finish=false
  var target:Dictionary=host.sim.enemies[0]
  # Explicit position/AI fixture, unchanged source projectile targeting/speed/damage.
  host.sim.hero.position=target.position+Vector3(0,0,minf(2.0,host.sim.v("Q1-3",1)*0.6))
  print("G16_BEFORE_CAST ",JSON.stringify({"ranks":host.sim.hero.ranks,"hexes":host.sim.hero.hexes,"hero":host.sim.hero.position,"target":target.position}))
  var press:=InputEventKey.new();press.physical_keycode=KEY_Q;press.keycode=KEY_Q;press.pressed=true;host.input_router.handle_event(press,target.position,false)
  press.pressed=false;host.input_router.handle_event(press,target.position,false)
  launched_at=elapsed;state=7
 elif state==7 and elapsed-launched_at>4.0:
  state=8;capture.call_deferred("after_source_settlement")
 elif state==8 and not busy:
  print("G16_SHORT_RESULT ",JSON.stringify({"hits":hits,"captured_moving_frames":captured,"source_remaining":host.sim.common.runtime.projectiles.size(),"g10_view":host.presentation.receipt.get("soul_pickups",{}),"view":host.presentation.receipt.get("common_missiles",{})}))
  host.frontdoor_close_run("g16_source_short");quit(0 if hits>0 and captured>=2 and host.sim.common.runtime.projectiles.is_empty() else 3)
 return false
