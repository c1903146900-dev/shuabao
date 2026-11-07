extends SceneTree
# Native mouse/keyboard inspection window after ordinary first-room setup.
# No source-state injection, automatic combat, or synthetic pointer events.
var elapsed:float=0
var entry:Node
var host:Node
var state:int=0
var ready_at:float=-1
var attacks:int=0
var busy:bool=false
var serial:int=0
class PointerAudit extends Node:
 var owner_tree
 func _input(event:InputEvent)->void:
  if event is InputEventMouseButton or (event is InputEventKey and not event.echo):
   owner_tree.record_input(event)
func record_input(event:InputEvent)->void:
 if host==null:return
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
 var row:Dictionary={"label":label,"serial":serial,"elapsed":elapsed,"phase":host.sim.phase,"camera":host.camera.position,"viewport":root.get_visible_rect(),"physical_window":DisplayServer.window_get_size(),"screen_transform":root.get_screen_transform(),"image_size":root.get_texture().get_size(),"bar":hud.bottom_bar.get_global_rect(),"popup":hud.bottom_popup.get_global_rect(),"popup_visible":hud.bottom_popup.visible,"slots":rects,"potions":host.ordinary_potion_controls.get_children().filter(func(c):return c is Button).map(func(c):return {"text":c.text,"rect":c.get_global_rect(),"visible":c.is_visible_in_tree(),"disabled":c.disabled}),"attacks":attacks,"move":host.input_router.movement(),"last_receipt":host.input_router.last_receipt,"hp":host.sim.hero.hp}
 root.get_texture().get_image().save_png("/workspace/scratch/73ebae91a474/compact_hud_review_20261107/native/frame_%03d.png"%serial)
 print("NATIVE_HUD_FRAME ",JSON.stringify(row));serial+=1;busy=false
func watch(event:Dictionary)->void:
 if str(event.get("kind",""))=="attack_started":attacks+=1;print("NATIVE_ATTACK ",JSON.stringify(event))
func _initialize()->void:
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
  print("NATIVE_HUD_READY normal_ui_no_combat_injection")
 return false
