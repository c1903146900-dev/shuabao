extends "res://tests/integration/two_room_input.gd"
var sustain_checks := {}
var sustain_samples := {}
func sustain_capture(label: String) -> void:
 sustain_samples[label] = integration_snapshot()
 sustain_samples[label]["stats"] = simulation.hero.stats.duplicate(true)
 print("SUSTAIN_SAMPLE ",label," ",JSON.stringify(sustain_samples[label]))
func start_sustain() -> String:
 call_deferred("run_sustain")
 return "SUSTAIN_STARTED"
func close_modal() -> void:
 if live_hud.supply.visible: await click(live_hud.supply_close)
 elif live_hud.shade.visible: await key(KEY_ESCAPE)
 await frames(6)
func buy_item(id: String) -> void:
 await close_modal()
 await click(live_hud.supply_button)
 await frames(6)
 var button: Button = live_hud.shop_buttons[id]
 var scroll: ScrollContainer = live_hud.shop_grid.get_parent()
 scroll.ensure_control_visible(button)
 await frames(8)
 print("BUY_INPUT ",id," supply=",live_hud.supply.visible," disabled=",button.disabled," rect=",button.get_global_rect())
 await click(button)
 await frames(6)
 await close_modal()
func win_next() -> void:
 await close_modal()
 await click(start_button)
 await fight(false)
 await close_modal()
func use_normal() -> void:
 var index := -1
 for i in range(ledger.model.snapshot().inventory.size()):
  if ledger.model.snapshot().inventory[i].id == "normal_tonic": index = i
 if index < 0:
  sustain_checks.normal_available = false
  return
 await click(live_hud.equipment[index])
 await click(live_hud.use_buttons[index])
 await close_modal()
func run_sustain() -> void:
 await run_checks() # Existing real input: learn, two room rewards, iron blade, upgrade.
 if simulation.phase != "victory": finish_sustain(); return
 await win_next() # Earn HP equipment and potion money from actual kills.
 var hp_before: float = simulation.hero.hp
 var cd_before: Dictionary = simulation.hero.cooldowns.duplicate()
 await buy_item("blood_crystal")
 sustain_capture("HP_equipped")
 sustain_checks.HP_max_without_healing = simulation.hero.stats.max_hp == 340 and simulation.hero.hp == hp_before and simulation.hero.cooldowns == cd_before
 for i in range(4): await buy_item("normal_tonic")
 sustain_capture("purchased_potions")
 sustain_checks.normal_stack_one_of_six_slots = ledger.model.snapshot().inventory.size() == 3 and ledger.model.snapshot().inventory[2].count == 4
 var before: float = simulation.hero.hp
 await use_normal()
 sustain_capture("first_heal")
 sustain_checks.actual_normal_heal = is_equal_approx(simulation.hero.hp,minf(340,before+61.2)) and simulation.hero.cooldowns == cd_before
 var receipt: Dictionary = controller.receipt_log[-1]
 if receipt.request.action != "use_item":
  sustain_checks.use_request_routed = false
  finish_sustain()
  return
 var healed_hp: float = simulation.hero.hp
 consumers.use_recovery(simulation,ledger.model,receipt.request.command_id,int(receipt.request.uid))
 sustain_checks.duplicate_use_no_second_heal = simulation.hero.hp == healed_hp
 for i in range(3):
  if simulation.hero.hp < simulation.hero.stats.max_hp: await use_normal()
 sustain_capture("full_heal")
 var inventory: Array = ledger.model.snapshot().inventory.duplicate(true)
 await use_normal()
 sustain_checks.full_health_no_consume = simulation.hero.hp == 340 and ledger.model.snapshot().inventory == inventory and controller.last_result.reason == "full_health"
 await win_next()
 await buy_item("mainspring")
 sustain_capture("AS_equipped")
 sustain_checks.AS_consumer = is_equal_approx(simulation.hero.attack_speed(),1.7*1.12)
 await win_next()
 if ledger.model.snapshot().gold < 550: await win_next()
 await buy_item("cooling_core")
 sustain_capture("CDR_equipped")
 sustain_checks.CDR_consumer = is_equal_approx(simulation.hero.stats.cdr,0.06)
 await key(KEY_Q)
 sustain_checks.frozen_actual_receipt = last_action_receipt.result.reason == "encounter_frozen" and live_hud.slots.Q.text.contains("战后冻结")
 # Real new dash uses reduced cooldown; the old cooldown wasn't rewritten by buying.
 await click(start_button)
 await key(KEY_SHIFT)
 var dash_time := -1.0
 for event in simulation.event_log:
  if event.kind == "dash": dash_time = event.world_time
 sustain_checks.CDR_actual_new_dash = dash_time >= 0 and absf(simulation.hero.cooldowns.shift-maxf(0,3.2*0.94-(simulation.clock.world_time-dash_time)))<0.03
 await key(KEY_E)
 sustain_checks.unlearned_actual_receipt = last_action_receipt.result.reason in ["unlearned","action_locked"]
 await fight(false)
 await key(KEY_ESCAPE)
 # Select an available numeric hex through its actual panel.
 await key(KEY_P)
 live_hud.tabs.current_tab = 2
 await frames()
 await click(live_hud.hex_open)
 await frames()
 sustain_capture("hex_offer")
 var button: Button = live_hud.hex_cards[0].select
 await click(button)
 await key(KEY_ESCAPE)
 sustain_capture("hex_selected")
 sustain_checks.numeric_hex_consumed = ledger.model.snapshot().selected_hex.size() == 1 and ledger.model.aggregate_effects().hexes.size() == 1
 finish_sustain()
func finish_sustain() -> void:
 var failures := []
 for label in sustain_checks:
  if not sustain_checks[label]: failures.append(label)
 set_meta("sustain_report",{"checks":sustain_checks,"failures":failures,"source":"real GUI InputEvents; gold/XP only earned by kills"})
 print("SUSTAIN_REPORT ",JSON.stringify(get_meta("sustain_report")))
func sustain_report() -> String:
 return JSON.stringify(get_meta("sustain_report",{}))

func consumer_unit_report() -> String:
 var result = preload("res://tests/integration/consumer_tests.gd").new().run()
 print("CONSUMER_REPORT ",JSON.stringify(result))
 return JSON.stringify(result)
