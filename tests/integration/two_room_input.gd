extends "res://scripts/integration/room.gd"
## MCP starts this runner; all playable progression is driven by Godot InputEvents.
var checks := {}
var samples := {}
var stage := "idle"
func frames(n := 3) -> void:
 for i in range(n): await get_tree().process_frame
func key(code: int) -> void:
 var e := InputEventKey.new()
 e.keycode = code
 e.pressed = true
 Input.parse_input_event(e)
 await frames()
 e = InputEventKey.new()
 e.keycode = code
 e.pressed = false
 Input.parse_input_event(e)
 await frames()
func click(control: Control) -> void:
 var p := control.get_global_rect().get_center()
 for down in [true,false]:
  var e := InputEventMouseButton.new()
  e.button_index = MOUSE_BUTTON_LEFT
  e.position = p
  e.global_position = p
  e.pressed = down
  Input.parse_input_event(e)
  await frames()
func aim_attack(pressed: bool) -> void:
 var target := Vector3.ZERO
 var nearest := INF
 for enemy in simulation.enemies:
  if not enemy.dead and enemy.position.distance_to(simulation.hero.position)<nearest:
   target = enemy.position
   nearest = enemy.position.distance_to(simulation.hero.position)
 var p := camera.unproject_position(target)
 var motion_event := InputEventMouseMotion.new()
 motion_event.position = p
 Input.parse_input_event(motion_event)
 var button := InputEventMouseButton.new()
 button.button_index = MOUSE_BUTTON_LEFT
 button.position = p
 button.global_position = p
 button.pressed = pressed
 Input.parse_input_event(button)
func capture(label: String) -> void:
 samples[label] = integration_snapshot()
 samples[label]["AD"] = simulation.hero.stats.ad
 samples[label]["events"] = simulation.event_log.duplicate(true)
 print("TWO_ROOM_SAMPLE ",label," ",JSON.stringify(samples[label]))
func start_checks() -> String:
 call_deferred("run_checks")
 return "TWO_ROOM_STARTED"
func fight(use_q := true) -> void:
 var deadline := Time.get_ticks_msec()+45000
 while simulation.phase == "combat" and Time.get_ticks_msec()<deadline:
  aim_attack(true)
  await get_tree().create_timer(0.3).timeout
  if use_q: await key(KEY_Q)
 aim_attack(false)
 await frames()
func run_checks() -> void:
 stage = "learn"
 capture("initial")
 await click(live_hud.allocation)
 await click(live_hud.rows.Q.buy)
 await click(live_hud.close_button)
 capture("learned")
 checks.ui_learn_true_model = ledger.model.snapshot().skills.Q.rank == 1 and simulation.hero.loadout.q == "q1"
 await click(start_button)
 stage = "room1"
 await fight()
 capture("room1")
 checks.room1_victory = simulation.phase == "victory"
 if not checks.room1_victory:
  finish()
  return
 checks.room1_atomic_rewards = ledger.model.snapshot().gold == 450 and ledger.model.snapshot().level == 2 and ledger.model.snapshot().xp == 80 and ledger.model.snapshot().reward_ids.size() == 3
 await get_tree().create_timer(2.0).timeout
 capture("frozen1")
 checks.hp_cd_clock_frozen = samples.room1.combat.hero == samples.frozen1.combat.hero and samples.room1.combat.world_time == samples.frozen1.combat.world_time
 # Deliberate duplicate delivery of already observed authoritative events; no new reward injected.
 for event in simulation.event_log.duplicate(true):
  if event.kind == "kill": _credit_kill(event)
 _encounter_finished(samples.room1.combat)
 _encounter_finished(samples.room1.combat)
 capture("duplicate1")
 checks.duplicate_settlement_no_reward = samples.duplicate1.growth.gold == 450 and samples.duplicate1.growth.xp == 80 and samples.duplicate1.growth.reward_ids.size() == 3
 await key(KEY_ESCAPE)
 await click(live_hud.allocation)
 await click(live_hud.rows.Q.buy)
 await click(live_hud.close_button)
 await key(KEY_P)
 await click(live_hud.shop_buttons.iron_blade)
 await click(live_hud.supply_close)
 capture("purchased")
 checks.earned_point_upgrade = ledger.model.snapshot().skills.Q.rank == 2 and ledger.model.snapshot().points == 0 and simulation.hero.ranks.q == 2
 checks.real_AD_hook = simulation.hero.stats.ad == 40 and ledger.model.snapshot().gold == 0
 var frozen_cd: Dictionary = simulation.hero.cooldowns.duplicate()
 stage = "room2"
 await click(start_button)
 capture("room2start")
 checks.room_transition_preserves_ledger = room_number == 2 and samples.room2start.growth.skills == samples.purchased.growth.skills and samples.room2start.growth.inventory == samples.purchased.growth.inventory
 var elapsed_clock: float = samples.room2start.combat.world_time-samples.purchased.combat.world_time
 checks.room_transition_CD_not_reset = true
 for slot in frozen_cd:
  if absf(samples.room2start.combat.hero.cooldowns[slot]-maxf(0.0,frozen_cd[slot]-elapsed_clock))>0.025: checks.room_transition_CD_not_reset = false
 await fight(false)
 capture("room2")
 checks.room2_victory = simulation.phase == "victory"
 checks.room2_rewards_separate_identity = ledger.model.snapshot().reward_ids.size() == 6 and ledger.model.snapshot().gold == 450 and ledger.model.snapshot().level == 3 and ledger.model.snapshot().xp == 135
 var hit40 := false
 for event in simulation.event_log:
  if event.kind == "damage" and event.get("source","") == "attack" and is_equal_approx(event.get("amount",0.0),40.0): hit40 = true
 checks.real_AD_attack_damage = hit40
 stage = "victory2"
 finish()
func finish() -> void:
 var failures := []
 for name in checks:
  if not checks[name]: failures.append(name)
 set_meta("two_room_report",{"checks":checks,"failures":failures,"stage":stage,"input":"Godot InputEvent via MCP, not OS input"})
 print("TWO_ROOM_REPORT ",JSON.stringify(get_meta("two_room_report")))
func report() -> String:
 return JSON.stringify({"stage":stage,"report":get_meta("two_room_report",{}),"snapshot":integration_snapshot()})

func start_death_checks() -> String:
 if stage != "victory2" or simulation.phase != "victory": return "requires_two_room_victory"
 call_deferred("death_checks")
 return "DEATH_CHECKS_STARTED"
func wait_terminal() -> void:
 var deadline := Time.get_ticks_msec()+80000
 while simulation.phase == "combat" and Time.get_ticks_msec()<deadline:
  await get_tree().create_timer(0.2).timeout
 await frames()
func death_checks() -> void:
 stage = "natural_downing"
 await key(KEY_ESCAPE)
 await click(start_button)
 await wait_terminal()
 capture("downed")
 checks.natural_enemy_downing = simulation.phase == "downed" and simulation.hero.hp == 0
 if not checks.natural_enemy_downing:
  finish()
  return
 await key(KEY_ESCAPE)
 await key(KEY_SPACE)
 capture("rescued")
 checks.native_space_rescue_once = simulation.phase == "combat" and simulation.hero.self_rescue_used and not live_hud.shade.visible
 stage = "natural_death"
 await wait_terminal()
 capture("true_dead")
 checks.true_death_model_penalty_once = simulation.phase == "true_dead" and ledger.model.snapshot().xp == 94 and ledger.model.snapshot().level == 3 and ledger.model.snapshot().gold == 450
 _encounter_finished(samples.true_dead.combat)
 _encounter_finished(samples.true_dead.combat)
 await get_tree().create_timer(2.0).timeout
 capture("dead_frozen")
 checks.death_duplicate_no_extra_penalty = ledger.model.snapshot().xp == 94 and ledger.model.snapshot().death_ids.size() == 1
 checks.dead_hp_cd_clock_frozen = samples.true_dead.combat.hero == samples.dead_frozen.combat.hero and samples.true_dead.combat.world_time == samples.dead_frozen.combat.world_time
 await key(KEY_ESCAPE)
 await key(KEY_F5)
 capture("retry")
 checks.native_F5_same_room_ledger = simulation.phase == "combat" and simulation.combat_level_id == samples.true_dead.combat.combat_level_id and ledger.model.snapshot().skills == samples.true_dead.growth.skills and ledger.model.snapshot().inventory == samples.true_dead.growth.inventory and ledger.model.snapshot().reward_ids == samples.true_dead.growth.reward_ids and ledger.model.snapshot().xp == 94 and simulation.hero.self_rescue_used
 checks.retry_preserves_enemies = samples.retry.combat.enemies.size() == samples.true_dead.combat.enemies.size() and samples.retry.kills == samples.true_dead.kills
 stage = "death_retry_done"
 finish()
