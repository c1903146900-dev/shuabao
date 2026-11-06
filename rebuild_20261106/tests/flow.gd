extends SceneTree
# CONTROLLED UI/flow regression: AI disabled and direct source lethal damage.
# Not natural combat, human full-floor play, or Windows validation.
var elapsed:float=0
var tick:float=0
var entry:Node
var host:Node
var started:bool=false
var checks:int=0
var pause_stage:int=0
var frozen:float=0
var pending_service:bool=false
var services:int=0
var map_closed:bool=false
var reopen:bool=false
func check(ok:bool,label:String)->void:
 checks+=1;print("CHECK ",label," ",ok)
 if not ok:quit(9)
func key(k:int)->void:
 for on in [true,false]:
  var e:=InputEventKey.new();e.physical_keycode=k;e.keycode=k;e.pressed=on;Input.parse_input_event(e)
func move(on:bool)->void:
 var e:=InputEventKey.new();e.physical_keycode=KEY_W;e.keycode=KEY_W;e.pressed=on;host.input_router.handle_event(e)
func _initialize()->void:root.add_child(load("res://boot.tscn").instantiate())
func _process(dt:float)->bool:
 elapsed+=dt;tick+=dt
 if elapsed>120:check(false,"timeout");return false
 if tick<.45:return false
 tick=0
 if entry==null:
  var b=root.get_node_or_null("Boot")
  if b!=null:
   for c in b.get_children():
    if c.get("screen")!=null:entry=c
  return false
 if not started:started=true;entry._start.pressed.emit();return false
 host=entry.active_room
 if host==null:return false
 if not host.floor_error.is_empty() or not host.startup_session_error.is_empty():check(false,"host_fault");return false
 var s=host.shop_session;var sim=host.sim
 sim.ai_enabled=false
 if s.initial_modal_open:
  move(false)
  if host.initial_hud.hex_draft.visible:host.initial_hud.hex_draft.selected.emit(0)
  return false
 if pause_stage<4 and s.status=="combat":
  move(false)
  match pause_stage:
   0:key(KEY_ESCAPE)
   1:check(sim.paused and host.manual_paused,"escape_pause");frozen=sim.clock.world_time
   2:check(is_equal_approx(frozen,sim.clock.world_time),"clock_frozen");key(KEY_ESCAPE)
   3:check(not sim.paused and not host.manual_paused,"escape_resume")
  pause_stage+=1;return false
 if pending_service:
  pending_service=false;check(s.status=="between_rooms" and s._service_ready,"service_complete");check(not host.service_continue.visible,"button_hidden");var n:int=s.node_index;key(KEY_ENTER);check(s.node_index==n,"repeat_enter_idempotent")
 if s.status=="completed":
  move(false);check(s.node_index==12,"twelve_rows");check(services>=3,"service_coverage");print("FINAL CONTROLLED_PASS checks=",checks," services=",services);host.frontdoor_close_run("controlled_flow_rebuild");quit();return false
 if s.status=="service":
  move(false);check(host.service_continue.visible and not host.service_continue.disabled,"continue_visible");check("Enter" in host.objective_label.text,"service_hint");check(not s.room_exit_ready(),"service_requires_confirmation");services+=1;key(KEY_ENTER);pending_service=true;return false
 if s.exit_map_open:
  move(false);check(not host.route_map.overview_active,"no_locked_overview")
  var choices:Array=s.available_choices();check(not choices.is_empty(),"legal_choices")
  var id:String=str(choices[0].node_id)
  for c in choices:
   if str(c.node_id)=="r02b":id="r02b"
  var b:Button=host.route_map.buttons[id];check(not b.disabled,"enabled_choice");check(b.position.y>=0 and b.position.y+b.size.y<=host.route_map.size.y,"choice_in_view")
  host.route_map.buttons[id].pressed.emit();return false
 if sim.phase in ["preparation","victory"]:move(true);return false
 move(false)
 if sim.phase=="combat":
  for enemy in sim.living():sim.damage_enemy(enemy,1000000.0,"attack",0,true)
 return false
