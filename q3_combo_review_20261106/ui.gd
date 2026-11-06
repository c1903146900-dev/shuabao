extends SceneTree
# Normal Boot/UI event regression. No combat HP/AI/damage/resource injection.
# Event-driven test, not manual user acceptance.
var time:float=0
var tick:float=0
var entry:Node
var host:Node
var state:int=0
var checks:int=0
var learned:bool=false
func check(ok:bool,label:String)->void:
 checks+=1;print("CHECK ",label," ",ok)
 if not ok:quit(9)
func key(k:int)->void:
 for on in [true,false]:
  var e:=InputEventKey.new();e.physical_keycode=k;e.keycode=k;e.pressed=on;Input.parse_input_event(e)
func move(k:int,on:bool)->void:
 var e:=InputEventKey.new();e.physical_keycode=k;e.keycode=k;e.pressed=on;host.input_router.handle_event(e)
func snap(name:String)->void:
 root.get_texture().get_image().save_png("user://q3_combo_ui_"+name+".png")
func _initialize()->void:root.add_child(load("res://boot.tscn").instantiate())
func _process(dt:float)->bool:
 time+=dt;tick+=dt
 if time>60:check(false,"timeout");return false
 if tick<.25:return false
 tick=0
 if entry==null:
  var b=root.get_node_or_null("Boot")
  if b!=null:
   for c in b.get_children():
    if c.get("screen")!=null:entry=c
  return false
 if state==0:entry._start.pressed.emit();state=1;return false
 host=entry.active_room
 if host==null:return false
 var s=host.shop_session
 if s.initial_modal_open:
  if host.initial_hud.hex_draft.visible:host.initial_hud.hex_draft.selected.emit(0)
  return false
 match state:
  1:
   check("出发前" in host.objective_label.text,"preparation_skill_hint");snap("preparation")
   check(not host.initial_hud.bottom_actions.E.disabled,"E_learn_button_enabled")
   host.initial_hud.bottom_actions.E.pressed.emit();state=2
  2:
   check(host.initial_hud.bottom_popup.visible,"skill_cards_open")
   check(not host.initial_hud.bottom_candidate_buttons.E2.disabled,"E2_available")
   host.initial_hud.bottom_candidate_buttons.E2.pressed.emit();state=3
  3:
   check(int(s.ledger.model.state.skills.E.rank)==1 and int(s.ledger.model.state.points)==0,"E2_learned_once")
   host.initial_hud.toggle_slot("E");move(KEY_W,true);state=4
  4:
   if s.exit_map_open:move(KEY_W,false);key(KEY_ESCAPE);state=5
  5:
   check(not s.exit_map_open,"escape_closed_map")
   check("向下离开出口" in host.objective_label.text,"map_reentry_explained");snap("reentry")
   move(KEY_S,true);state=6
  6:
   if not s.room_exit_view().inside:move(KEY_S,false);move(KEY_W,true);state=7
  7:
   if s.exit_map_open:
    move(KEY_W,false);check(not host.route_map.overview_active,"reopened_at_choices")
    var id:String=str(s.available_choices()[0].node_id);host.route_map.buttons[id].pressed.emit();state=8
  8:
   if s.status=="combat":key(KEY_P);state=9
  9:
   check(not s.panel_open,"combat_shop_still_rejected")
   check("战斗" in host.objective_label.text,"shop_rejection_explained");snap("shop_denied")
   key(KEY_ESCAPE);state=10
  10:
   check(host.sim.paused and "已暂停" in host.objective_label.text,"pause_overrides_notice");snap("paused")
   print("FINAL PLAYER_UI_PASS checks=",checks);host.frontdoor_close_run("ranged_facing_ui_rebuild");quit()
 return false
