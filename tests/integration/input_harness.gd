extends "res://scripts/integration/room.gd"
## Native input injection only. No direct damage, XP grants, clock stepping or AI disabling.
var samples := {}
func key_event(key: int, pressed: bool) -> String:
 var event := InputEventKey.new()
 event.keycode = key
 event.pressed = pressed
 Input.parse_input_event(event)
 return "queued_key"
func mouse_event(x: float, y: float, pressed: bool) -> String:
 var event := InputEventMouseButton.new()
 event.position = Vector2(x,y)
 event.global_position = event.position
 event.button_index = MOUSE_BUTTON_LEFT
 event.pressed = pressed
 Input.parse_input_event(event)
 return "queued_mouse"
func move_mouse(x: float, y: float) -> String:
 var event := InputEventMouseMotion.new()
 event.position = Vector2(x,y)
 event.global_position = event.position
 Input.parse_input_event(event)
 return "queued_motion"
func click_target(target: String, pressed: bool) -> String:
 var control: Control = {"learn_q":live_hud.rows.Q.buy,"allocation":live_hud.allocation,"start":start_button,"close":live_hud.close_button}.get(target)
 var p: Vector2 = control.get_global_rect().get_center()
 return mouse_event(p.x,p.y,pressed)
func capture(label: String) -> Dictionary:
 samples[label] = integration_snapshot()
 return {"label":label,"phase":simulation.phase,"hp":simulation.hero.hp,"kills":_kills(),"growth":ledger.model.snapshot(),"position":simulation.hero.position}
func report() -> String:
 var failures := []
 var checks := {}
 checks["initial_one_point"] = samples.initial.growth.level == 1 and samples.initial.growth.points == 1
 checks["native_ui_learn"] = samples.learned.growth.points == 0 and samples.learned.growth.skills.Q.rank == 1 and samples.learned.combat.hero.loadout.q == "q1"
 checks["movement"] = samples.moved.combat.hero.position.distance_to(samples.started.combat.hero.position) > 0.1
 checks["native_attack_kill"] = samples.settled.kills > 0
 checks["enemy_actual_hit"] = samples.settled.combat.hero.hp < samples.started.combat.hero.hp
 checks["death_settlement"] = samples.settled.combat.phase in ["downed","true_dead"]
 checks["hp_cd_clock_frozen"] = samples.settled.combat.hero == samples.frozen.combat.hero and samples.settled.combat.world_time == samples.frozen.combat.world_time
 checks["growth_preserved"] = samples.learned.growth.skills == samples.frozen.growth.skills and samples.frozen.growth.level == 1 and samples.frozen.growth.points == 0
 checks["hud_is_real"] = samples.frozen.hud.hp == samples.frozen.combat.hero.hp and samples.frozen.hud.skills.Q.cooldown == samples.frozen.combat.hero.cooldowns.q
 for name in checks:
  if not checks[name]: failures.append(name)
 return JSON.stringify({"checks":checks,"failures":failures,"input_source":"Godot Input.parse_input_event via MCP; not physical OS input"})

func start_boundary_checks() -> String:
 return preload("res://tests/integration/input_boundaries.gd").new().start(self)
