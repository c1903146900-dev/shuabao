extends Node
var game: Node
var checks := {}
func frames(n := 4) -> void:
 for i in range(n): await get_tree().process_frame
func key(code: int, down: bool, echo := false) -> void:
 var e := InputEventKey.new()
 e.keycode=code; e.pressed=down; e.echo=echo
 Input.parse_input_event(e)
 await frames()
func tap(code: int) -> void:
 await key(code,true)
 await key(code,false)
func click(control: Control) -> void:
 for down in [true,false]:
  var e:=InputEventMouseButton.new()
  e.button_index=MOUSE_BUTTON_LEFT; e.position=control.get_global_rect().get_center();e.pressed=down
  Input.parse_input_event(e)
  await frames()
func tab_to(control: Control) -> bool:
 for i in range(32):
  if game.get_viewport().gui_get_focus_owner()==control: return true
  await tap(KEY_TAB)
 return false
func start(root: Node) -> String:
 game=root
 root.add_child(self)
 call_deferred("run")
 return "ENTER_BOUNDARY_STARTED"
func run() -> void:
 checks.initial_primary_focus=game.get_viewport().gui_get_focus_owner()==game.start_button
 game.simulation.ai_enabled=false # Input boundary fixture; not a natural combat/reward test.
 await tap(KEY_K)
 await click(game.live_hud.rows.Q.buy)
 await tap(KEY_ESCAPE)
 checks.escape_preparation_focus_is_start=game.get_viewport().gui_get_focus_owner()==game.start_button
 await key(KEY_ENTER,true)
 for i in range(5): await key(KEY_ENTER,true,true)
 await key(KEY_ENTER,false)
 checks.enter_full_cycle_only_starts_room=game.simulation.phase=="combat" and game.room_number==1 and not game.live_hud.shade.visible
 if game.live_hud.shade.visible: await tap(KEY_ESCAPE)
 checks.tab_reaches_allocation=await tab_to(game.live_hud.allocation)
 await tap(KEY_ENTER)
 checks.keyboard_activation_opens_menu_without_new_room=game.live_hud.panel.visible and game.room_number==1
 # Keyboard activation of Close must not leak its release into gameplay.
 game.live_hud.close_button.grab_focus()
 await tap(KEY_ENTER)
 checks.keyboard_close_does_not_start_or_attack=not game.live_hud.shade.visible and game.room_number==1 and not game.attacking
 # Controlled terminal setup, to test the next-room shortcut separately from kills.
 game.simulation.end_encounter("victory")
 await frames()
 await tap(KEY_ESCAPE)
 checks.escape_victory_focus_is_start=game.get_viewport().gui_get_focus_owner()==game.start_button
 checks.tab_reaches_supply=await tab_to(game.live_hud.supply_button)
 await tap(KEY_ENTER)
 checks.keyboard_supply_does_not_start_room=game.live_hud.supply.visible and game.room_number==1 and game.simulation.phase=="victory"
 await tap(KEY_ESCAPE)
 await key(KEY_KP_ENTER,true)
 for i in range(5):await key(KEY_KP_ENTER,true,true)
 await key(KEY_KP_ENTER,false)
 checks.keypad_enter_one_new_room_no_modal=game.room_number==2 and game.simulation.phase=="combat" and not game.live_hud.shade.visible
 var failures:=[]
 for name in checks:
  if not checks[name]:failures.append(name)
 game.set_meta("enter_report",{"checks":checks,"failures":failures,"scope":"GUI InputEvents; AI disabled and terminal state prepared only for input boundaries"})
 print("ENTER_BOUNDARY_REPORT ",JSON.stringify(game.get_meta("enter_report")))
