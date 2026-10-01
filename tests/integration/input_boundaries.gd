extends Node
var game: Node
var checks := {}
func frames(n := 4) -> void:
 for i in range(n): await get_tree().process_frame
func key(code: int, down: bool) -> void:
 var e := InputEventKey.new()
 e.keycode = code
 e.pressed = down
 Input.parse_input_event(e)
 await frames()
func move_mouse(p: Vector2) -> void:
 var e := InputEventMouseMotion.new()
 e.position = p
 Input.parse_input_event(e)
 await frames()
func start(root: Node) -> String:
 game = root
 root.add_child(self)
 call_deferred("run")
 return "BOUNDARY_TESTS_STARTED"
func run() -> void:
 game.new_run()
 game.start_room()
 game.simulation.ai_enabled = false # Input fixture only; no damage/kill claim.
 await frames()
 await move_mouse(Vector2(640,300))
 await key(KEY_W,true)
 var before: Vector3 = game.simulation.hero.position
 await move_mouse(Vector2(100,80)) # Ordinary HP HUD, not a modal.
 await frames(15)
 checks.hud_hover_preserves_held_move = game.simulation.hero.position.distance_to(before) > 0.1
 await key(KEY_W,false)
 await move_mouse(Vector2(640,300))
 await key(KEY_W,true)
 await key(KEY_K,true)
 await key(KEY_K,false)
 var stopped: Vector3 = game.simulation.hero.position
 var clock_before: float = game.simulation.clock.world_time
 await key(KEY_W,false)
 await frames(15)
 checks.modal_blocks_move_without_pausing_clock = game.simulation.hero.position.distance_to(stopped) < 0.01 and game.simulation.clock.world_time > clock_before
 await key(KEY_ESCAPE,true)
 await key(KEY_ESCAPE,false)
 await frames(10)
 checks.release_inside_modal_does_not_resume_movement = game.simulation.hero.position.distance_to(stopped) < 0.01
 game.simulation.damage_hero(99999) # Prepare actual downed lifecycle; not a player combat test.
 await frames()
 await key(KEY_ESCAPE,true)
 await key(KEY_ESCAPE,false)
 checks.result_closed_focus_on_allocation = not game.live_hud.shade.visible and game.live_hud.allocation.has_focus()
 await key(KEY_SPACE,true)
 await key(KEY_SPACE,false)
 checks.space_full_cycle_rescues_without_opening_panel = game.simulation.phase == "combat" and not game.live_hud.shade.visible
 var failures := []
 for name in checks:
  if not checks[name]: failures.append(name)
 game.set_meta("boundary_report",{"checks":checks,"failures":failures,"input":"native Godot InputEvent via MCP, not OS input"})
 print("BOUNDARY_REPORT ",JSON.stringify(game.get_meta("boundary_report")))
