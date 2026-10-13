extends SceneTree
## Main-only finite reproduction. This author did not run Godot.
## All control comes from a naturally updated Boss through EnemyDirector._release.
## No direct damage_hero call, stun assignment, debug kill, or callback mutation.
const Sim = preload("res://tests/ink_q1_foundation_20261004/revision02/scripts/ink_sim.gd")
const InputAdapter = preload("res://tests/ink_q1_foundation_20261004/revision02/scripts/ink_input_adapter.gd")
var observations: Array = []
var fixture_errors: Array = []
func key(code: int) -> InputEventKey:
 var event = InputEventKey.new()
 event.physical_keycode = code
 event.pressed = true
 return event
func mouse(pressed: bool) -> InputEventMouseButton:
 var event = InputEventMouseButton.new()
 event.button_index = MOUSE_BUTTON_LEFT
 event.pressed = pressed
 return event
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 for operation in ["walk", "new_basic", "new_shift", "q_arm", "accepted_preview_release"]:
  probe(operation)
 var report = {
  "fixture_executed": fixture_errors.is_empty(),
  "fixture_errors": fixture_errors,
  "source_binding": "revision02-source_binding.json",
  "control_source": "enemy_director.gd:368 Boss natural melee supplies 0.20 seconds; core:497 applies control*(1-tenacity)",
  "scope": "Five finite natural-Boss control observations, not a global action-cancellation policy or playable-host acceptance",
  "observations": observations
 }
 var file = FileAccess.open("res://tests/ink_q1_foundation_20261004/revision02/control_probe_result.json", FileAccess.WRITE)
 file.store_string(JSON.stringify(report, "  "))
 file.close()
 print("INK_QA_CONTROL_PROBE ", JSON.stringify(report))
 quit(0 if fixture_errors.is_empty() else 1)
func probe(operation: String) -> void:
 var sim = Sim.new()
 root.add_child(sim)
 sim.hero.position = Vector3.ZERO
 sim.auto_finish = false
 sim.ai_enabled = true
 sim.hero.loadout.q = "q1"
 sim.hero.ranks.q = 1
 sim.begin_encounter("ink-natural-boss-control", [{"kind": "boss", "position": Vector3(0, 0, -2.5)}])
 var adapter = InputAdapter.new()
 adapter.bind(sim)
 var damage_samples: Array = []
 var holder: Array = [sim]
 sim.combat_event.connect(func(event):
  if event.kind == "damage" and event.target == "yanguizhou":
   damage_samples.append({"event": event.duplicate(true), "stun_left_at_damage_publication": holder[0].hero.stun_left, "hp_after_damage": holder[0].hero.hp})
 )
 var preview_admission: Dictionary = {}
 if operation == "accepted_preview_release":
  preview_admission["arm"] = adapter.handle_event(key(KEY_Q))
  preview_admission["down"] = adapter.handle_event(mouse(true), Vector3.ZERO)
  var motion = InputEventMouseMotion.new()
  preview_admission["motion"] = adapter.handle_event(motion, Vector3(4, 0, 0))
 var waited_steps: int = 0
 while waited_steps < 250 and sim.hero.stun_left <= sim.TIME_EPS and not sim.hero.dead:
  sim.step(0.02)
  waited_steps += 1
 if sim.hero.stun_left <= sim.TIME_EPS or damage_samples.is_empty():
  fixture_errors.append(operation + ": natural Boss failed to produce the required damage/control within 5 seconds")
  sim.free()
  return
 var result: Dictionary = {
  "operation": operation,
  "natural_control_obtained": true,
  "waited_steps": waited_steps,
  "hero_time": sim.hero_time,
  "stun_before_input": sim.hero.stun_left,
  "tenacity": sim.hero.tenacity(),
  "boss_attack_index": sim.enemies[0].attack_index,
  "boss_state": sim.enemies[0].state,
  "damage_sample": damage_samples.back(),
  "preview_phase_before_input": sim.ink_input.phase
 }
 var before_position: Vector3 = sim.hero.position
 var action: Dictionary = {}
 match operation:
  "walk":
   action = adapter.handle_event(key(KEY_D))
   sim.step(0.02)
  "new_basic": action = adapter.handle_event(mouse(true), Vector3(9, 0, 0))
  "new_shift":
   action = adapter.handle_event(key(KEY_SHIFT), Vector3(9, 0, 0))
   sim.step(0.02)
  "q_arm": action = adapter.handle_event(key(KEY_Q))
  "accepted_preview_release":
   result["preview_admission"] = preview_admission
   action = adapter.handle_event(mouse(false), Vector3(4, 0, 0))
 result.merge({
  "action_result": action,
  "stun_after_input": sim.hero.stun_left,
  "distance_moved": before_position.distance_to(sim.hero.position),
  "basic_count": sim.ink_basics.size(),
  "wave_count": sim.ink_waves.size(),
  "preview_phase_after_input": sim.ink_input.phase,
  "dash_left": sim.hero.dash_left,
  "attack_index": sim.hero.attack_index,
  "note": "Q arm and already accepted preview release are reported separately; this probe does not prescribe cancelling existing projectiles"
 }, true)
 observations.append(result)
 sim.free()
