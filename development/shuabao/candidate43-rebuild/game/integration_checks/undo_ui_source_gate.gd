extends "res://integration_checks/training12_source_gate.gd"
## Prepared source regression only. The parent owns all Godot invocations.
## Original Host/Session/Model, panel requests and potion buttons are retained.
const UNDO_NEW_PANEL := "res://visual_rework_20261009/transaction_panel.gd"
const UNDO_OLD_PANEL := "res://formal_training_20261009/panel.gd"
const UndoPotionControls = preload("res://tests/ink_equipment_live_20261008/content01/potion_controls.gd")
const UNDO_GROUPS := ["ordinary_reversible", "consumed_same_visit", "mixed_sealed_tail", "committed_new_visit", "formal_training_permanent"]
var undo_mode: String = "compare"
var undo_partition: String = "all"
var undo_required: Array = UNDO_GROUPS.duplicate()
var undo_completed: Array = []
var undo_records: Array = []
var undo_defects_observed: int = 0

func _initialize() -> void:
 output_path = "user://undo_ui_source_gate.json"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--undo-result="): output_path = arg.trim_prefix("--undo-result=")
  if arg.begins_with("--undo-mode="): undo_mode = arg.trim_prefix("--undo-mode=")
  if arg.begins_with("--undo-group="): undo_partition = arg.trim_prefix("--undo-group=")
 if undo_mode not in ["compare", "legacy"]:
  push_error("Expected --undo-mode=compare or legacy"); quit(2); return
 if undo_partition != "all":
  if undo_partition not in UNDO_GROUPS:
   push_error("Unknown undo source group"); quit(2); return
  undo_required = [undo_partition]
 run.call_deferred()

func undo_protected(f: Dictionary) -> PackedByteArray:
 # A rejected request may add its own receipt; gameplay state must be unchanged.
 return var_to_bytes([f.session.ledger.model.state, f.session.ledger.model.potion_consumer.snapshot(), f.sim.hero.hp, f.sim.hero.stats, f.sim.phase, f.session.status, f.session.panel_open])

func undo_unsealed_txs(f: Dictionary) -> Array:
 var out: Array = []
 for record: Dictionary in f.session.ledger.model.state.shop_visit.undo:
  if not bool(record.sealed): out.append(int(record.tx))
 return out

func undo_fixture(label: String) -> Dictionary:
 var f: Dictionary = funded_shop(label)
 if f.is_empty(): return {}
 var path: String = UNDO_NEW_PANEL if undo_mode == "compare" else UNDO_OLD_PANEL
 if not check(ResourceLoader.exists(path), "explicit panel exists: " + path): dispose(f); return {}
 var script: Script = load(path)
 if not check(script != null and script.can_instantiate(), "source panel can instantiate"): dispose(f); return {}
 var panel: Control = script.new()
 root.add_child(panel)
 panel.bind_session(f.session)
 f["undo_panel"] = panel
 f["undo_legacy"] = null
 f.host.shop_session = f.session
 f.host.shop_panel = panel
 panel.transaction_requested.connect(f.host._submit_shop)
 if undo_mode == "compare":
  var legacy: Control = load(UNDO_OLD_PANEL).new()
  root.add_child(legacy)
  legacy.bind_session(f.session)
  f.undo_legacy = legacy
  check(panel.get_script().get_base_script().resource_path == UNDO_OLD_PANEL, "new panel is exactly one UI layer over unchanged formal training panel")
 var potions: HBoxContainer = UndoPotionControls.new()
 root.add_child(potions)
 potions.set_process(false)
 potions.bind_session(f.session)
 f["undo_potions"] = potions
 panel.refresh(true)
 check(panel.visible and panel._state.ready and f.session.panel_open, "real Session opens subject panel")
 check(f.session.ledger.model.snapshot().content_profile == "ordinary_equipment43_potions3", "retained 43 equipment / 3 potion profile")
 check(f.session.ledger.model.config.body.outcomes.size() == 12, "retained formal twelve training outcomes")
 check(f.session.ledger.model.state.shop_visit.undo.is_empty(), "fresh visit starts with no journal records")
 return f

func undo_sample(f: Dictionary, label: String, candidate_disabled: bool, legacy_disabled: bool, sealed_tooltip: bool = false) -> void:
 var before: PackedByteArray = undo_protected(f)
 f.undo_panel.refresh(true)
 var subject_disabled: bool = f.undo_panel._undo.disabled
 check(subject_disabled == (candidate_disabled if undo_mode == "compare" else legacy_disabled), label + ": explicit subject button state")
 check(f.undo_panel.visible, label + ": subject panel remains open")
 var old_disabled: bool = subject_disabled
 if undo_mode == "compare":
  f.undo_legacy.refresh(true)
  old_disabled = bool(f.undo_legacy._undo.disabled)
  check(old_disabled == legacy_disabled, label + ": unchanged original panel control")
  if sealed_tooltip:
   check(not str(f.undo_panel._undo.tooltip_text).is_empty() and str(f.undo_panel._undo.tooltip_text).contains("不可撤回"), label + ": consumed record has explanatory tooltip")
 check(undo_protected(f) == before, label + ": both UI projections are gameplay-readonly")
 if candidate_disabled != legacy_disabled:
  check(not old_disabled and not f.session.ledger.model.state.shop_visit.undo.is_empty() and undo_unsealed_txs(f).is_empty(), label + ": original enabled-all-sealed defect reproduced")
  undo_defects_observed += 1
 undo_records.append({"kind":"panel_comparison", "case":current_group, "stage":label, "subject_path":f.undo_panel.get_script().resource_path, "subject_disabled":subject_disabled, "legacy_disabled":old_disabled, "expected_candidate_disabled":candidate_disabled, "tooltip":f.undo_panel._undo.tooltip_text, "token":f.session.ledger.model.commerce_token().duplicate(true), "journal":f.session.ledger.model.state.shop_visit.undo.duplicate(true)})

func undo_buy(f: Dictionary, item: String) -> bool:
 var panel: Control = f.undo_panel
 panel._set_category("consumables" if item.begins_with("potion:") else "base")
 panel._select(item)
 panel.refresh(true)
 if not check(not panel._buy.disabled and panel._quote.get("accepted", false), "real rendered purchase is enabled: " + item): return false
 panel._buy.pressed.emit()
 f.session.update_after_source_step()
 var result: Dictionary = f.session.last_receipt.duplicate(true)
 undo_records.append({"kind":"original_panel_purchase", "item":item, "receipt":result})
 return check(result.get("accepted", false), "original panel signal -> Host -> Session buys " + item + ": " + str(result.get("reason", "")))

func undo_press(f: Dictionary) -> Dictionary:
 f.undo_panel.refresh(true)
 if not check(not f.undo_panel._undo.disabled, "actual undo button enabled before positive signal"): return {}
 f.undo_panel._undo.pressed.emit()
 f.session.update_after_source_step()
 var result: Dictionary = f.session.last_receipt.duplicate(true)
 undo_records.append({"kind":"original_panel_undo", "receipt":result})
 return result

func undo_close(f: Dictionary) -> bool:
 var before: Dictionary = f.session.ledger.model.state.shop_visit.duplicate(true)
 var result: Dictionary = f.session.close_panel()
 f.undo_panel.refresh(true)
 if not check(result.get("accepted", false) and not f.session.panel_open and not f.undo_panel.visible, "original Session closes and hides panel"): return false
 var after: Dictionary = f.session.ledger.model.state.shop_visit
 check(after.undo == before.undo and after.epoch == before.epoch and after.room_id == before.room_id and after.shop_active and not after.ui_open, "close is not visit commit and preserves exact journal/epoch/room")
 return true

func undo_reopen(f: Dictionary) -> bool:
 var before: Dictionary = f.session.ledger.model.state.shop_visit.duplicate(true)
 var result: Dictionary = f.session.open_panel()
 if not check(result.get("accepted", false), "same original Session reopens shop"): return false
 var after: Dictionary = f.session.ledger.model.state.shop_visit
 check(after.undo == before.undo and after.epoch == before.epoch and after.room_id == before.room_id, "same-area reopen retains exact journal and visit identity")
 f.undo_panel.refresh(true)
 return true

func undo_drink_original_button(f: Dictionary) -> bool:
 var model = f.session.ledger.model
 var held: Dictionary = held_item(f, "potion:1")
 if not check(not held.is_empty() and int(held.count) == 1, "one actual purchased bottle ready for original potion button"): return false
 var journal_before: Array = model.state.shop_visit.undo.duplicate(true)
 var epoch: int = int(model.state.shop_visit.epoch)
 var gold: int = int(model.state.gold)
 var hp: float = float(f.sim.hero.hp)
 var active_before: int = model.potion_consumer.snapshot().active.size()
 f.undo_potions._process(0.0)
 if not check(f.undo_potions.get_child_count() == 1, "original potion control renders one held tier"): return false
 var button: Button = f.undo_potions.get_child(0)
 if not check(not button.disabled and not f.session.panel_open and not f.sim.paused, "original potion UI admits closed-shop safe use"): return false
 button.pressed.emit()
 f.session.update_after_source_step()
 var used: Dictionary = f.session.last_receipt.duplicate(true)
 if not check(used.get("accepted", false), "original potion button -> use_potion -> verified consumer succeeds: " + str(used.get("reason", ""))): return false
 check(held_item(f, "potion:1").is_empty() and model.potion_consumer.snapshot().active.size() == active_before + 1, "consumer removes exactly one bottle and creates a real recovery effect")
 check(int(model.state.gold) == gold and float(f.sim.hero.hp) == hp, "safe pre-drink neither refunds purchase nor fabricates immediate healing")
 check(int(model.state.shop_visit.epoch) == epoch and model.state.shop_visit.undo.size() == journal_before.size(), "real consumption retains journal length and same visit epoch")
 for lineage_tx: int in held.lineage:
  var found: bool = false
  for record: Dictionary in model.state.shop_visit.undo:
   if int(record.tx) == lineage_tx:
    found = true
    check(record.sealed and record.seal_reason == "already_used", "real consumer seals purchased bottle lineage with already_used")
  check(found, "sealed purchase history was retained, not erased")
 undo_records.append({"kind":"original_potion_control_signal", "uid":held.uid, "lineage":held.lineage.duplicate(), "receipt":used, "journal_before":journal_before, "journal_after":model.state.shop_visit.undo.duplicate(true), "consumer":model.potion_consumer.snapshot().duplicate(true), "hp_before":hp, "hp_after":f.sim.hero.hp})
 return true

func undo_rejection(f: Dictionary, expected_reason: String, label: String) -> void:
 var before: PackedByteArray = undo_protected(f)
 var result: Dictionary = shop_command(f, "undo")
 check(not result.get("accepted", false) and result.get("reason", "") == expected_reason, label + ": original ledger rejects undo with " + expected_reason)
 check(undo_protected(f) == before, label + ": rejection preserves wallet/items/HP/body/consumer/visit")
 undo_records.append({"kind":"source_undo_rejection", "case":current_group, "stage":label, "receipt":result})

func undo_dispose(f: Dictionary) -> void:
 if f.is_empty(): return
 for key: String in ["undo_panel", "undo_legacy", "undo_potions"]:
  if f.get(key) != null and is_instance_valid(f[key]): f[key].free()
 f.host.shop_panel = null
 b04_integrity(f, current_group)
 dispose(f)

func undo_finish_group(f: Dictionary) -> void:
 undo_dispose(f)
 undo_completed.append(current_group)

func undo_ordinary() -> void:
 current_group = "ordinary_reversible"
 var f: Dictionary = undo_fixture(current_group)
 if f.is_empty(): return
 var model = f.session.ledger.model
 var gold: int = int(model.state.gold)
 undo_sample(f, "empty fresh visit", true, true)
 if not undo_buy(f, "base:B01"): undo_dispose(f); return
 var tx: int = int(model.state.shop_visit.undo.back().tx)
 check(undo_unsealed_txs(f) == [tx], "ordinary purchase creates one authentic unsealed record")
 undo_sample(f, "ordinary purchase", false, false)
 # Isolated UI state only, no fake Model/Session or journal mutation. The same
 # revision makes the base refresh retain another disabling decision.
 var before: PackedByteArray = undo_protected(f)
 f.undo_panel._undo.disabled = true
 f.undo_panel.refresh(false)
 check(f.undo_panel._undo.disabled and undo_protected(f) == before, "same-revision refresh never force-enables an already disabled undo button")
 undo_sample(f, "forced original refresh restores current ordinary offer", false, false)
 var undone: Dictionary = undo_press(f)
 check(undone.get("accepted", false) and int(undone.get("undone_tx", -1)) == tx, "button undoes exactly the ordinary purchase")
 check(int(model.state.gold) == gold and model.state.inventory.is_empty() and model.state.shop_visit.undo.is_empty(), "ordinary inverse restores original gold and inventory")
 undo_sample(f, "ordinary inverse leaves no history", true, true)
 undo_finish_group(f)

func undo_consumed() -> void:
 current_group = "consumed_same_visit"
 var f: Dictionary = undo_fixture(current_group)
 if f.is_empty(): return
 if not undo_buy(f, "potion:1"): undo_dispose(f); return
 undo_sample(f, "unconsumed purchased potion", false, false)
 if not undo_close(f) or not undo_drink_original_button(f) or not undo_reopen(f): undo_dispose(f); return
 check(f.session.ledger.model.state.shop_visit.undo.size() == 1 and undo_unsealed_txs(f).is_empty(), "same visit contains only one authentic consumed/sealed purchase")
 undo_sample(f, "reopen after real consumption", true, false, true)
 undo_rejection(f, "already_used", "all sealed history")
 # A second close/reopen must not clear the journal or resurrect availability.
 if not undo_close(f) or not undo_reopen(f): undo_dispose(f); return
 undo_sample(f, "second reopen of same sealed visit", true, false, true)
 undo_finish_group(f)

func undo_mixed() -> void:
 current_group = "mixed_sealed_tail"
 var f: Dictionary = undo_fixture(current_group)
 if f.is_empty(): return
 var model = f.session.ledger.model
 if not undo_buy(f, "base:B01"): undo_dispose(f); return
 var first: Dictionary = model.state.shop_visit.undo.back().duplicate(true)
 if not undo_buy(f, "potion:1") or not undo_close(f) or not undo_drink_original_button(f) or not undo_reopen(f): undo_dispose(f); return
 var sealed_tail: Dictionary = model.state.shop_visit.undo.back().duplicate(true)
 check(model.state.shop_visit.undo.size() == 2 and sealed_tail.sealed and undo_unsealed_txs(f) == [int(first.tx)], "real mixed history has older unsealed equipment followed by newer sealed potion")
 undo_sample(f, "mixed history remains reversible", false, false)
 if undo_mode == "compare": check(str(f.undo_panel._undo.tooltip_text).is_empty(), "mixed history does not keep an all-sealed tooltip")
 var gold: int = int(model.state.gold)
 var consumer: Dictionary = model.potion_consumer.snapshot().duplicate(true)
 var undone: Dictionary = undo_press(f)
 check(undone.get("accepted", false) and int(undone.get("undone_tx", -1)) == int(first.tx), "original reverse scan skips newer sealed purchase and undoes older equipment")
 check(int(model.state.gold) == gold + int(first.gold_delta) and owned_count(f, "base:B01") == 0 and held_item(f, "potion:1").is_empty(), "mixed inverse refunds only equipment and never resurrects consumed potion")
 check(model.state.shop_visit.undo == [sealed_tail] and model.potion_consumer.snapshot() == consumer, "mixed inverse preserves exact sealed history and active potion consumer")
 undo_sample(f, "mixed inverse leaves only sealed history", true, false, true)
 undo_rejection(f, "already_used", "remaining sealed tail")
 # A fresh ordinary transaction in the same visit clears the stale tooltip.
 if not undo_buy(f, "base:B02"): undo_dispose(f); return
 undo_sample(f, "new unsealed transaction after sealed-only state", false, false)
 if undo_mode == "compare": check(str(f.undo_panel._undo.tooltip_text).is_empty(), "new ordinary purchase clears prior sealed-only tooltip")
 undo_finish_group(f)

func undo_new_visit() -> void:
 current_group = "committed_new_visit"
 var f: Dictionary = undo_fixture(current_group)
 if f.is_empty(): return
 var model = f.session.ledger.model
 if not undo_buy(f, "base:B01"): undo_dispose(f); return
 var held: Array = model.state.inventory.duplicate(true)
 var old_epoch: int = int(model.state.shop_visit.epoch)
 var old_room: String = str(model.state.shop_visit.room_id)
 if not undo_close(f) or not enter(f, 1): undo_dispose(f); return
 check(model.state.shop_visit.undo.is_empty() and int(model.state.shop_visit.epoch) > old_epoch and str(model.state.shop_visit.room_id) != old_room and not model.state.shop_visit.shop_active, "actual next authored room commits prior visit and clears history")
 check(model.state.inventory == held, "commit retains purchased equipment")
 # Existing bounded source-damage fixture settles the real first-row roster;
 # it never writes terminal, HP, generation, actor roster or row receipts.
 if not b04_settle_row(f, 1) or not g02_open(f): undo_dispose(f); return
 check(model.state.shop_visit.shop_active and model.state.shop_visit.undo.is_empty() and int(model.state.shop_visit.epoch) > old_epoch, "actual settled next-room shop starts a fresh empty visit")
 undo_sample(f, "new committed visit", true, true)
 undo_rejection(f, "undo_boundary", "new visit cannot reverse old purchase")
 check(model.state.inventory == held, "rejected cross-visit reversal preserves original purchase")
 undo_finish_group(f)

func undo_training() -> void:
 current_group = "formal_training_permanent"
 var f: Dictionary = undo_fixture(current_group)
 if f.is_empty(): return
 var model = f.session.ledger.model
 var gold: int = int(model.state.gold)
 f.undo_panel._set_category("training")
 if not check(not f.undo_panel._training_pay.disabled, "unchanged formal training payment is available"): undo_dispose(f); return
 f.undo_panel._training_pay.pressed.emit()
 f.session.update_after_source_step()
 var pending: Dictionary = model.snapshot().body_pending.duplicate(true)
 if not check(pending.get("candidates", []).size() == 3 and int(model.state.gold) == gold - 900, "real training button pays original900 and offers original three outcomes"): undo_dispose(f); return
 check(model.state.shop_visit.undo.is_empty(), "permanent payment adds no undo record")
 undo_sample(f, "formal training payment is not reversible", true, true)
 var pending_before: PackedByteArray = undo_protected(f)
 var rejected_pending: Dictionary = shop_command(f, "undo")
 check(not rejected_pending.get("accepted", false) and undo_protected(f) == pending_before, "direct undo cannot reverse pending formal payment")
 if not undo_close(f) or not undo_reopen(f): undo_dispose(f); return
 f.undo_panel.refresh(true)
 if not check(model.snapshot().body_pending == pending and f.undo_panel._training_choices.get_child_count() == 3, "closing/reopening retains exact paid training choices"): undo_dispose(f); return
 var choice: Button = f.undo_panel._training_choices.get_child(0)
 choice.pressed.emit()
 f.session.update_after_source_step()
 if not check(model.snapshot().body_pending.is_empty() and int(model.training_status().completed_count) == 1 and int(model.state.gold) == gold - 900, "real formal choice is applied exactly once with no second payment"): undo_dispose(f); return
 var body: Array = model.state.body.duplicate(true)
 var effects: Dictionary = model.body_effects().duplicate(true)
 check(model.state.shop_visit.undo.is_empty(), "permanent selection adds no undo record")
 undo_sample(f, "formal training selection is not reversible", true, true)
 undo_rejection(f, "undo_boundary", "completed training cannot be undone")
 if not undo_buy(f, "base:B01"): undo_dispose(f); return
 var undone: Dictionary = undo_press(f)
 check(undone.get("accepted", false) and model.state.body == body and model.body_effects() == effects and int(model.state.gold) == gold - 900, "later equipment inverse preserves permanent training and original900 charge")
 undo_sample(f, "after later equipment inverse training remains permanent", true, true)
 undo_finish_group(f)

func undo_report() -> void:
 check(undo_completed == undo_required, "all requested undo source groups completed")
 if "consumed_same_visit" in undo_required or "mixed_sealed_tail" in undo_required:
  check(undo_defects_observed > 0, "unchanged old-panel bug was observed on authentic all-sealed history")
 var report: Dictionary = {"suite":"undo_ui_original_source", "passed":failures.is_empty() and undo_completed == undo_required, "mode":undo_mode, "meaning":"fixed panel regression plus unchanged old-panel defect control" if undo_mode == "compare" else "legacy defect reproduction only, not a fixed UI pass", "checks":checks, "failures":failures, "check_records":check_records, "required_groups":undo_required, "completed_groups":undo_completed, "original_defects_observed":undo_defects_observed, "records":undo_records, "wallet_fixtures":evidence.wallet_fixtures, "source_damage_fixtures":fixture_packets, "actual_Host_factories":true, "actual_Session_and_single_Model":true, "original_potion_button_signals":true, "original_shop_button_signals":true, "direct_sealed_history_body_rng_HP_stats_writes":false, "UI_disabled_field_fixture":true, "native_GUI":false, "natural_play":false, "full_Host_controls_construction":false, "production_ready":false}
 var file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
 if file == null: push_error("Cannot write undo source result"); quit(2); return
 file.store_string(JSON.stringify(report, "  "))
 var error: Error = file.get_error()
 file.close()
 print("UNDO_UI_ORIGINAL_SOURCE ", JSON.stringify({"passed":report.passed, "mode":undo_mode, "checks":checks, "failures":failures, "result":output_path}))
 quit(2 if error != OK else (0 if report.passed else 1))

func run() -> void:
 g03_reset_evidence()
 if "ordinary_reversible" in undo_required: undo_ordinary()
 if "consumed_same_visit" in undo_required: undo_consumed()
 if "mixed_sealed_tail" in undo_required: undo_mixed()
 if "committed_new_visit" in undo_required: undo_new_visit()
 if "formal_training_permanent" in undo_required: undo_training()
 await process_frame # Flush inherited signal-safe queue_free after disposal.
 undo_report()
