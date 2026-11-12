extends SceneTree
# Native mouse/keyboard inspection window after ordinary first-room setup.
# Explicit G10/kill-progress/position/Q-rank/cooldown fixtures; native resume and movement.
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
 var row:Dictionary={"label":label,"phase":host.sim.phase,"paused":host.sim.paused,"hero_position":host.sim.hero.position,"cooldowns":host.sim.hero.cooldowns.duplicate(true),"ranks":host.sim.hero.ranks.duplicate(true),"souls":host.sim.common.runtime.souls.duplicate(true),"view":host.presentation.receipt.get("soul_pickups",{}).duplicate(true)}
 root.get_texture().get_image().save_png("user://%s.png"%label)
 print("G10_FRAME ",JSON.stringify(row));busy=false
func watch(event:Dictionary)->void:
 if str(event.get("kind",""))=="common_hex_soul_pickup":
  pickup_at=elapsed
  print("G10_VISUAL_PICKUP ",JSON.stringify({"event":event,"cooldowns":host.sim.hero.cooldowns.duplicate(true)}));capture.call_deferred("actual_pickup")
 if str(event.get("kind",""))=="attack_started":
  attacks+=1;print("NATIVE_ATTACK ",JSON.stringify(event))
 if str(event.get("kind",""))=="dash_attack_started":
  dashes+=1
  traced_cast=int(event.cast_id);traced_until=float(event.real_time)+.55;boundary_captured.clear()
 if str(event.get("kind","")) in ["dash","dash_attack_started","attack_cancelled","damage"]:print("NATIVE_ACTION ",JSON.stringify(event))
func _initialize()->void:
 root.add_child(load("res://boot.tscn").instantiate())
func _process(dt:float)->bool:
 elapsed+=dt
 if elapsed>110:
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
  host.shop_session.ledger.model.state.selected_hex=["common_g10"]
  host.shop_session.ledger.refresh_runtime()
  var audit:=PointerAudit.new();audit.owner_tree=self;root.add_child(audit)
  host.sim.combat_event.connect(watch);state=2;ready_at=elapsed
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
  host.sim.ai_enabled=false
  for enemy:Dictionary in host.sim.enemies.duplicate():
   enemy.state="chase"
   host.sim.damage_enemy(enemy,10000.0,"growth_fixture_lethal_packet",0,true,false,{"fixture":true,"direct":true})
  print("G10_GROWTH_AFTER_KILLS ",JSON.stringify({"model":host.shop_session.ledger.model.state,"ranks":host.sim.hero.ranks}))
  state=20
 elif state==20 and host.sim.phase=="victory":
  if int(host.shop_session.ledger.model.state.points)<1:print("G10_NO_EARNED_POINT");host.frontdoor_close_run("growth_failed");quit(3);return false
  host.initial_hud.bottom_actions.Q.pressed.emit();state=21
 elif state==21 and host.initial_hud.bottom_candidate_buttons.has("Q1"):
  host.initial_hud.bottom_candidate_buttons.Q1.pressed.emit();state=22
 elif state==22:
  host.initial_hud.bottom_popup.get_child(0).get_child(0).pressed.emit()
  print("G10_Q_LEARNED ",JSON.stringify({"ranks":host.sim.hero.ranks,"points":host.shop_session.ledger.model.state.points}))
  var down:=InputEventKey.new();down.physical_keycode=KEY_W;down.keycode=KEY_W;down.pressed=true;host.input_router.handle_event(down)
  state=23
 elif state==23 and host.shop_session.exit_map_open:
  var up:=InputEventKey.new();up.physical_keycode=KEY_W;up.keycode=KEY_W;up.pressed=false;host.input_router.handle_event(up)
  var choices:Array=host.shop_session.available_choices()
  if not choices.is_empty():host.route_map.buttons[str(choices[0].node_id)].pressed.emit();state=24;combat_setup_at=elapsed
 elif state==24 and host.sim.phase=="combat" and elapsed-combat_setup_at>1.0:
  host.sim.ai_enabled=false
  host.sim.auto_finish=false
  var target:Dictionary=host.sim.enemies[0]
  target.state="chase"
  host.sim.hero.position=target.position+Vector3(0,0,2.2)
  host.sim.common.runtime.soul_kills=23
  var killed:bool=host.sim.damage_enemy(target,10000.0,"visual_fixture_lethal_packet",0,true,false,{"fixture":true,"direct":true})
  host.sim.hero.cooldowns.q=5.0;host.sim.hero.cooldowns.e=5.0
  var pause:=InputEventKey.new();pause.physical_keycode=KEY_SPACE;pause.keycode=KEY_SPACE;pause.pressed=true;host._input(pause)
  pause.pressed=false;host._input(pause)
  if not killed or host.sim.common.runtime.souls.size()!=1 or int(host.sim.hero.ranks.q)<1 or int(host.sim.hero.ranks.e)<1:
   print("G10_VISUAL_SETUP_FAILED ",JSON.stringify({"killed":killed,"souls":host.sim.common.runtime.souls.size()}));host.frontdoor_close_run("visual_fixture_setup_failed");quit(3);return false
  state=7
  capture.call_deferred("soul_before_pickup_paused")
  print("G10_VISUAL_READY explicit_selection_23kill_lethal_and_position_fixture; native_Space_then_W")
 elif state==7:
  if pickup_at>0.0 and elapsed-pickup_at>1.0:
   print("G10_AFTER_PICKUP ",JSON.stringify({"souls":host.sim.common.runtime.souls.size(),"cooldowns":host.sim.hero.cooldowns,"view":host.presentation.receipt.get("soul_pickups",{})}));host.frontdoor_close_run("g10_pickup_observed");quit()
 return false
