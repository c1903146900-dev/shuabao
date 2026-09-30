extends "res://scripts/combat/arena.gd"
## Test-only scene root. Live gameplay uses fengli_arena.tscn without these fixtures.
func run_core_tests() -> Dictionary:
 return preload("res://tests/combat/tests_core.gd").new().run()
func fixture_training() -> Dictionary:
 new_run()
 simulation.ai_enabled = false
 simulation.auto_finish = false
 simulation.hero.stats.regen = 0
 return get_combat_snapshot()
func fixture_warning() -> void:
 new_run()
 manual_step = true
 var enemy: Dictionary = simulation.enemies[-1]
 enemy.position = Vector3(0,0,0)
 enemy.aim = Vector3.BACK
 enemy.state = "warning"
 enemy.attack_shape = "cone"
 enemy.warning_progress = 0.65
 enemy.timer = 0.4
 simulation.hero.position = Vector3(0,0,3)
 _sync_views(0)
func fixture_ultimate() -> void:
 new_run()
 manual_step = true
 simulation.hero.position = Vector3.ZERO
 simulation.request_action("r")
 simulation.step(0.31)
 _sync_views(0)
func fixture_victory() -> void:
 new_run()
 manual_step = true
 for enemy in simulation.enemies: simulation.damage_enemy(enemy,enemy.hp,"acceptance_fixture",0,true)
 simulation._check_victory()
 _sync_views(0.5)

func run_all_tests() -> String:
 var result: Dictionary = {"core":preload("res://tests/combat/tests_core.gd").new().run(),"extended":preload("res://tests/combat/tests_extended.gd").new().run(),"progression":preload("res://tests/combat/tests_loadout_fixture.gd").new().run()}
 return JSON.stringify(result)

var input_probe: String = ""
var probe_before: Dictionary = {}
var probe_events: Array = []
var input_results: Array = []
func begin_input_probe(kind: String) -> String:
 manual_step = false
 demonstration = false
 preset_index = 0
 fixture_training()
 simulation.enemies.clear()
 simulation.hero.position = Vector3.ZERO
 mouse_at = Vector2(640,260)
 var direction: Vector3 = (_aim_point()-simulation.hero.position).normalized()
 simulation.hero.facing = direction
 simulation.spawn_enemy("minion",direction*2.0,1000)
 input_probe = kind
 probe_events.clear()
 probe_before = simulation.snapshot()
 return JSON.stringify({"probe":kind,"before_position":str(simulation.hero.position),"target":str(simulation.enemies[0].position)})
func _unhandled_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo:
  probe_events.append({"key":event.keycode,"physical":event.physical_keycode})
 if event is InputEventMouseButton and event.pressed: probe_events.append({"mouse_button":event.button_index})
 if event is InputEventMouseMotion: probe_events.append({"mouse_move":str(event.position)})
 super._unhandled_input(event)
func finish_input_probe() -> String:
 var h = simulation.hero
 var displacement: Vector3 = h.position-probe_before.hero.position
 var passed: bool = false
 match input_probe:
  "w": passed = displacement.z < -0.1
  "s": passed = displacement.z > 0.1
  "a": passed = displacement.x < -0.1
  "d": passed = displacement.x > 0.1
  "aim": passed = h.facing.x > 0.1
  "attack": passed = simulation.enemies[0].hp < 1000
  "shift": passed = displacement.length() > 1.0 and h.cooldowns.shift > 0 and simulation.enemies[0].hp == 1000
  "q": passed = simulation.enemies[0].hp < 1000 and h.cooldowns.q > 0
  "e": passed = h.overload_left > 0 and h.cooldowns.e == 0
  "r": passed = simulation.enemies[0].hp < 1000 and (simulation.r1_active or h.cooldowns.r > 0)
  "preset": passed = preset_index == 1 and h.loadout.q == "q2" and h.loadout.e == "e1" and h.loadout.r == "r2"
 passed = passed and not probe_events.is_empty()
 var result: Dictionary = {"probe":input_probe,"passed":passed,"events":probe_events.duplicate(true),"displacement":str(displacement),"target_hp":simulation.enemies[0].hp,"cooldowns":h.cooldowns.duplicate(),"overload":h.overload_left,"world_time":simulation.clock.world_time}
 input_results.append(result)
 return JSON.stringify(result)
func input_report() -> String:
 var failures: Array = input_results.filter(func(entry): return not entry.passed)
 return JSON.stringify({"checks":input_results.size(),"failures":failures,"results":input_results})

func set_fixture_preset(index: int) -> void:
 preset_index = index
 manual_step = true
 new_run()
 simulation.ai_enabled = false
 simulation.auto_finish = false
 simulation.hero.position = Vector3.ZERO
 _sync_views(0)
func sample_demo(real_seconds: float) -> String:
 manual_step = true
 demonstration = true
 _sync_views(real_seconds)
 _step_effects(real_seconds)
 _demo(real_seconds)
 simulation.step(real_seconds)
 _sync_views(0)
 return JSON.stringify({"time":simulation.clock.world_time,"phase":simulation.phase,"hp":simulation.hero.hp,"enemies":simulation.living().size()})

func begin_demo() -> void:
 manual_step = true
 demonstration = true
 preset_index = 0
 new_run()
 _sync_views(0)

func fixture_candidate_visual(index: int, action: String) -> void:
 set_fixture_preset(index)
 var target: Vector3 = Vector3(-2,0,1)
 simulation.request_action(action,target)
 simulation.step(0.22 if action != "r" else 0.10)
 _sync_views(0)

func inject_mouse_button(x: float, y: float, pressed: bool) -> void:
 # MCP test route: one NEW native event per call. The pinned upstream click bridge
 # mutates a shared press event into release before accumulated input is dispatched.
 var event = InputEventMouseButton.new()
 event.position = Vector2(x,y)
 event.button_index = MOUSE_BUTTON_LEFT
 event.pressed = pressed
 Input.parse_input_event(event)
