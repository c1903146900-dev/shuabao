extends SceneTree
## Main-owned finite Control-signal gate. The author does not launch Godot.
## Uses production Hex HUD/Controller and ShopPanel; lightweight test-owned
## Q1/skill-undo/open Buttons use the same verified host Adapter/session seams.
## No normal-entry funds, live top-up, fabricated selection, reward, or UI stat patch.
const Sim = preload("res://tests/ink_intermediate_stats_20261004/ink_intermediate_sim.gd")
const Session = preload("res://tests/ink_intermediate_shop_ui_20261004/session.gd")
const FundedSession = preload("res://tests/ink_intermediate_shop_ui_20261004/funded_session.gd")
const IntermediateShopPanel = preload("res://tests/ink_intermediate_shop_ui_20261004/fix02/shop_panel.gd")
const Controller = preload("res://tests/ink_initial_hex_ui_20261004/fix01/controller.gd")
const HUD = preload("res://tests/ink_initial_hex_ui_20261004/hex_hud.gd")
const Router = preload("res://tests/ink_q1_foundation_20261004/revision02/scripts/ink_input_adapter.gd")
const Tuning = preload("res://tests/ink_q1_foundation_20261004/revision02/scripts/ink_tuning.gd")
const BINDING = "res://tests/ink_intermediate_stats_20261004/source_binding.json"
const EXPECTED_BINDING = "a79fc889f1cb028099c9baf2882b44f84a3345179b6415ef6113304a8901720e"
const SOURCE_MAP = "res://tests/ink_intermediate_stats_20261004/source_map.json"
const EXPECTED_CASES = ["ordinary_four_choice_q1", "two_uid_craft_hp_inverse", "unsupported_predebit", "G24_craft_slots", "G30_craft_debit", "any_room_commit"]
var checks: int = 0
var failures: Array = []
var observations: Array = []
var completed_cases: Dictionary = {}
var rows: Dictionary = {}
var fresh_serial: int = 0
var command_serial: int = 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok: failures.append(label); push_error(label)
func near(actual: float, expected: float, label: String) -> void:
 check(is_finite(actual) and absf(actual - expected) < 0.00001, "%s: %.9f expected %.9f" % [label, actual, expected])
func uid_list(inventory: Array) -> Array:
 var out: Array = []
 for entry in inventory: out.append(entry.uid)
 return out
func button(text_value: String, callback: Callable) -> Button:
 var control := Button.new(); control.text = text_value
 root.add_child(control); control.pressed.connect(callback)
 return control
func fresh(funded: bool) -> Dictionary:
 fresh_serial += 1
 var sim = Sim.new(); root.add_child(sim)
 sim.hero.position = Vector3.ZERO; sim.ai_enabled = false; sim.auto_finish = false
 var session: RefCounted = FundedSession.new() if funded else Session.new()
 var run_id: String = "intermediate-ui-gate-%d" % fresh_serial
 if funded:
  var refused: Dictionary = session.initialize_funded_session(sim, run_id, false, false)
  check(not refused.accepted and session.status == "unbound", "funding requires explicit fresh-fixture opt-in")
 var initialized: Dictionary = session.initialize_funded_session(sim, run_id, false, true) if funded else session.initialize_session(sim, run_id, false)
 check(initialized.get("accepted", false), "fresh exact intermediate session admitted")
 if not initialized.get("accepted", false):
  observations.append({"case":"initialization_failed", "receipt":initialized}); sim.free(); return {}
 var state: Dictionary = session.ledger.model.snapshot()
 check(state.level == 1 and state.xp == 0 and state.points == 1 and state.gold == (1500 if funded else 0), "startup exact money/level/XP/original1SP")
 check(state.inventory.is_empty() and state.selected_hex.is_empty() and state.skills.Q.rank == 0 and state.reward_ids.is_empty(), "startup grants no equipment, Hex, skill, or reward")
 if funded:
  var before: Dictionary = session.ledger.model.state.duplicate(true)
  check(not session.initialize_funded_session(sim, run_id, false, true).accepted, "second startup funding cannot top up live session")
  check(session.ledger.model.state == before, "rejected second funding preserves exact authority")
 else: check(not session.has_method("initialize_funded_session"), "ordinary Session exposes no funding entry point")
 var router = Router.new(); router.bind(sim)
 check(session.bind_input_suspender(router.suspend_input).accepted, "original input suspender bound")
 var hud = HUD.new(); root.add_child(hud)
 var controller = Controller.new()
 controller.command_completed.connect(session.progression_command_completed)
 controller.gameplay_block_changed.connect(session.set_modal_blocked)
 controller.bind(session.ledger.model, hud, session.ledger.definitions)
 var panel = IntermediateShopPanel.new(); root.add_child(panel); panel.bind_session(session)
 var f: Dictionary = {"sim":sim, "s":session, "router":router, "hud":hud, "c":controller, "panel":panel, "requests":[], "controls":[]}
 panel.transaction_requested.connect(func(id: String, action: String, args: Dictionary):
  var result: Dictionary = session.submit(id, action, args)
  f.requests.append({"id":id, "action":action, "arguments":args.duplicate(true), "result":result.duplicate(true)})
  session.update_after_source_step(); controller.refresh(); panel.refresh(true))
 panel.close_requested.connect(func(): session.close_panel(); panel.refresh(true))
 # Same requests as initial fix01 Host._learn_q1/_undo_initial_skill.
 f["learn"] = button("学习 Q1（消耗原有1SP）", func():
  if session.ledger.model.snapshot().pending_milestones.is_empty():
   hud.adapter.request("learn", {"slot_id":"Q", "candidate_id":"Q1", "expected_rank":int(session.ledger.model.state.skills.Q.rank)}))
 f["skill_undo"] = button("撤销本次技能投入", func():
  if session.ledger.model.snapshot().pending_milestones.is_empty(): hud.adapter.request("undo_new_points"))
 f["open"] = button("打开原商店", func(): session.open_panel(); panel.refresh(true))
 f.controls = [f.learn, f.skill_undo, f.open]
 return f
func close(f: Dictionary) -> void:
 f.s.close_run()
 for control in f.controls: control.free()
 f.panel.free(); f.hud.free(); f.sim.free()
func find_button(node: Node, text_value: String) -> Button:
 if node is Button and node.text == text_value: return node
 for child in node.get_children():
  var found: Button = find_button(child, text_value)
  if found != null: return found
 return null
func select_item(f: Dictionary, id: String) -> bool:
 var category: String = id.get_slice(":", 0)
 var label: String = {"base":"基础12", "intermediate":"合成18", "final":"成装42"}.get(category, "消耗品11")
 var tab: Button = find_button(f.panel, label)
 check(tab != null, "actual category Button exists: " + label)
 if tab == null: return false
 tab.pressed.emit()
 check(f.panel._item_buttons.has(id), "actual catalog item Button exists: " + id)
 if not f.panel._item_buttons.has(id): return false
 f.panel._item_buttons[id].pressed.emit()
 check(f.panel._selected == id, "item Button selects exact source item: " + id)
 return f.panel._selected == id
func purchase(f: Dictionary, id: String) -> Dictionary:
 if not select_item(f, id): return {"accepted":false, "reason":"missing_control"}
 check(not f.panel._buy.disabled and f.panel._quote.get("accepted", false), "actual purchase Button has current accepted quote: " + id)
 if f.panel._buy.disabled: return {"accepted":false, "reason":"disabled_control"}
 if id.begins_with("intermediate:"):
  var shown_before: Dictionary = f.panel.recipe_projection
  var required: Dictionary = {}
  for part in rows[id].components: required[part] = int(required.get(part, 0)) + 1
  var owned: Dictionary = {}
  for held in f.s.ledger.model.state.inventory:
   if required.has(held.id): owned[held.id] = int(owned.get(held.id, 0)) + int(held.count)
  check(shown_before.get("required_counts", {}) == required and shown_before.get("owned_counts", {}) == owned, "recipe UI shows actual required/owned component counts: " + id)
  check(shown_before.get("source_price", -1) == rows[id].price and shown_before.get("source_component_total", -1) == rows[id].price - rows[id].combine_fee, "recipe UI preserves original price/component total: " + id)
  check(shown_before.get("quote", {}).get("charge", -1) == f.panel._quote.charge, "shown real debit comes from same current Model quote: " + id)
  var raw_fee: Variant = rows[id].combine_fee
  var raw_charge: Variant = f.panel._quote.charge
  var raw_credit: Variant = f.panel._quote.credit
  var integral_money: bool = true
  for amount in [raw_fee, raw_charge, raw_credit]:
   integral_money = integral_money and typeof(amount) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(amount)) and float(amount) >= 0.0 and floorf(float(amount)) == float(amount)
  check(integral_money, "visible money contract requires finite nonnegative integer-valued fee/debit/credit: " + id)
  if not integral_money: return {"accepted":false, "reason":"nonintegral_visible_money_contract"}
  var expected_buy: String = "合成 %s（本次 %d金币）" % [rows[id].name, int(raw_charge)]
  var expected_fee_line: String = "原合成费 %d金 · 本次实际扣款 %d金（已持组件抵扣%d金）" % [int(raw_fee), int(raw_charge), int(raw_credit)]
  var expected_parts: Array[String] = []
  var source_catalog: Dictionary = f.s.ledger.model.shop_catalog().items
  for part in required:
   expected_parts.append("%s ×%d（持有%d/%d）" % [source_catalog[part].name, int(required[part]), int(owned.get(part, 0)), int(required[part])])
  var expected_recipe: String = "原配方：" + " + ".join(expected_parts)
  var actual_buy: String = f.panel._buy.text
  var actual_detail: String = f.panel._detail.text
  check(actual_buy == expected_buy, "visible craft Button exactly names actual debit and currency: " + id)
  check(expected_fee_line in actual_detail.split("\n"), "visible complete original fee/current debit/component credit line matches exactly: " + id)
  check(expected_recipe in actual_detail.split("\n"), "visible complete original recipe/owned counts line matches exactly: " + id)
  observations.append({"case":"visible_recipe_text", "item":id, "actual_buy":actual_buy, "actual_detail":actual_detail, "expected_buy":expected_buy, "expected_fee_line":expected_fee_line, "expected_recipe":expected_recipe, "fee":raw_fee, "fee_type":type_string(typeof(raw_fee)), "fee_str":str(raw_fee), "charge":raw_charge, "charge_type":type_string(typeof(raw_charge)), "charge_str":str(raw_charge), "credit":raw_credit, "credit_type":type_string(typeof(raw_credit))})
 var count_before: int = f.requests.size()
 f.panel._buy.pressed.emit()
 check(f.requests.size() == count_before + 1, "purchase Button emits exactly one request: " + id)
 if f.requests.size() != count_before + 1: return {"accepted":false, "reason":"missing_request"}
 var request: Dictionary = f.requests.back()
 if id.begins_with("intermediate:"):
  var shown: Dictionary = f.panel.recipe_projection
  check(shown.get("components", []) == rows[id].components and shown.get("combine_fee", -1) == rows[id].combine_fee, "recipe projection preserves original component sequence and combine fee: " + id)
 check(request.action == ("craft" if id.begins_with("intermediate:") else "buy"), "UI dispatches exact buy/craft operation: " + id)
 check(request.result.accepted, "actual UI transaction accepted: " + id + ": " + str(request.result.reason))
 return request.result
func reverse(f: Dictionary) -> Dictionary:
 check(not f.panel._undo.disabled, "actual undo Button enabled")
 var count_before: int = f.requests.size()
 f.panel._undo.pressed.emit()
 check(f.requests.size() == count_before + 1, "actual undo Button emits exactly one request")
 return f.requests.back().result if f.requests.size() == count_before + 1 else {"accepted":false, "reason":"missing_request"}
func choose(f: Dictionary, wanted: String = "", refresh_personal: bool = false) -> bool:
 var state: Dictionary = f.s.ledger.model.snapshot()
 check(f.s.open_panel().reason == "mandatory_hex_pending" and f.s.learn_q1().reason == "mandatory_hex_pending", "mandatory initial offer blocks shop and direct Q1")
 f.c.ensure_auto_hex()
 check(f.hud.hex_required and f.hud.hex_draft.visible and f.sim.paused, "actual initial four-choice modal pauses source")
 check(f.hud.hex_draft.cards.size() == 4 and f.hud.projection.get("choices", []).size() == 4, "exactly four real choice Controls")
 if f.hud.hex_draft.cards.size() != 4 or f.hud.projection.get("choices", []).size() != 4: return false
 if refresh_personal:
  var seen: Dictionary = {}
  for id in f.s.ledger.model.state.offers["1"].slots: seen[id] = true
  for slot in [0, 2, 1, 3]:
   f.hud.hex_draft.cards[slot].refresh.pressed.emit()
   check(f.c.last_result.accepted and f.hud.hex_draft.cards[slot].refresh.disabled, "actual slot refresh accepted once")
   var replacement: String = f.s.ledger.model.state.offers["1"].slots[slot]
   check(not seen.has(replacement), "refresh never repeats seen effect")
   seen[replacement] = true
  check(seen.size() == 8, "all four refresh Controls produce eight distinct effects")
 var chosen_slot: int = 3
 if not wanted.is_empty():
  chosen_slot = f.s.ledger.model.state.offers["1"].slots.find(wanted)
  for slot in range(4):
   if chosen_slot >= 0: break
   f.hud.hex_draft.cards[slot].refresh.pressed.emit()
   check(f.c.last_result.accepted, "find requested supported Hex through actual single-use refresh")
   chosen_slot = f.s.ledger.model.state.offers["1"].slots.find(wanted)
  check(chosen_slot >= 0, "requested source Hex appears in real eight-candidate pool: " + wanted)
  if chosen_slot < 0: return false
 var chosen: String = f.s.ledger.model.state.offers["1"].slots[chosen_slot]
 var before_gold: int = int(state.gold)
 f.hud.hex_draft.cards[chosen_slot].select.pressed.emit()
 f.hud.hex_draft.cards[chosen_slot].select.pressed.emit()
 await create_timer(0.30).timeout
 state = f.s.ledger.model.snapshot()
 check(state.selected_hex == [chosen] and state.pending_milestones.is_empty(), "actual selection commits one Hex despite duplicate signal")
 check(state.gold == before_gold and state.points == 1 and state.xp == 0, "initial selection grants no currency/XP/SP")
 check(not f.sim.paused and not f.hud.hex_required and not f.hud.hex_draft.visible, "successful initial choice releases modal pause")
 if state.selected_hex != [chosen]: return false
 var personal: bool = f.s.ledger.definitions.hexes[chosen].hero == "yanguizhou"
 if personal: check(state.hex_status[chosen] == "dormant" and chosen not in f.sim.hero.hexes, "selected personal remains dormant before actual Q1")
 f.learn.pressed.emit()
 state = f.s.ledger.model.snapshot()
 check(f.c.last_result.accepted and state.points == 0 and state.skills.Q.rank == 1 and f.sim.hero.ranks.q == 1, "actual Q1 Button spends only original1SP through Adapter/Controller/Model/Sim")
 check(state.hex_status[chosen] == "active" and chosen in f.sim.hero.hexes, "chosen source Hex remains selected and active after Q1")
 var before: Dictionary = f.s.ledger.model.state.duplicate(true)
 f.learn.pressed.emit()
 check(not f.c.last_result.accepted and f.s.ledger.model.state == before, "repeated Q1 Button cannot duplicate original skill investment")
 return true
func unchanged_progression(f: Dictionary, before: Dictionary, label: String) -> void:
 var state: Dictionary = f.s.ledger.model.state
 for key in ["selected_hex", "skills", "points", "xp", "level", "rng", "reward_ids"]:
  check(state[key] == before[key], label + " preserves " + key)
 check(f.sim.hero.ranks.q == 1, label + " retains actual Q1 rank")
func run() -> void:
 check(FileAccess.get_sha256(BINDING) == EXPECTED_BINDING, "exact verified intermediate source binding")
 var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE_MAP))
 if source is Dictionary and source.get("rows", null) is Array:
  for row in source.rows: rows[row.id] = row
 else: check(false, "source map must be valid rows")
 if not rows.is_empty() and failures.is_empty():
  await ordinary_case()
  await commerce_case()
  await unsupported_case()
  await g24_case()
  await g30_case()
  await room_case()
 var all_cases_complete: bool = true
 for case_name in EXPECTED_CASES:
  var ended: bool = bool(completed_cases.get(case_name, false))
  check(ended, "case reached final assertion: " + case_name)
  all_cases_complete = all_cases_complete and ended
 var report: Dictionary = {"suite":"intermediate_actual_control_to_ledger", "passed":failures.is_empty(), "checks":checks, "failures":failures, "completed":all_cases_complete, "completed_cases":completed_cases, "observed":observations, "source_binding_id":FileAccess.get_sha256(BINDING), "required_source_binding_id":EXPECTED_BINDING, "scope":"real production HexDraft/ShopPanel pressed signals, existing Controller/Adapter/Session/Model/Bridge/exact Sim; isolated test-owned Q1/skill-undo/open Controls use verified host seams", "engine_UI":"complete_only_if_all_cases_reached_end_and_zero_failures", "native_pixels_input_audio":"NOT_RUN", "full_host_layout":"NOT_RUN", "ordinary_12_row_route":"HOLD_unconfigured", "finite_fixture":"fresh opted-in 1500 once per funded session; zero live topups/rewards/SP grants", "engine_invoked_by_author":false, "ui_view_script":"res://tests/ink_intermediate_shop_ui_20261004/fix02/shop_panel.gd"}
 var file := FileAccess.open("res://tests/ink_intermediate_shop_ui_20261004/ui_result.json", FileAccess.WRITE)
 if file == null:
  push_error("ui_result.json could not be written"); quit(2); return
 file.store_string(JSON.stringify(report, "  ")); file.close()
 print("INK_INTERMEDIATE_SHOP_UI_REPORT ", JSON.stringify(report))
 quit(0 if failures.is_empty() else 1)
func ordinary_case() -> void:
 var f: Dictionary = fresh(false)
 if f.is_empty(): return
 if not await choose(f, "", true): close(f); return
 var state: Dictionary = f.s.ledger.model.snapshot()
 check(state.gold == 0 and state.xp == 0 and state.points == 0 and state.skills.Q.rank == 1, "ordinary true four-choice/Q1 preserves unfunded entry")
 check(f.s.next_room_preflight().reason == "ordinary_12_row_content_unconfigured", "ordinary formal route remains explicit HOLD")
 f.open.pressed.emit()
 check(f.s.panel_open and f.panel.visible, "ordinary safe shop opens after mandatory choice")
 if select_item(f, "base:B01"):
  var before: Dictionary = f.s.ledger.model.state.duplicate(true)
  var count_before: int = f.requests.size()
  check(f.panel._buy.disabled and f.panel._quote.reason == "insufficient_gold", "ordinary zero wallet disables unaffordable equipment")
  f.panel._buy.pressed.emit()
  check(f.requests.size() == count_before and f.s.ledger.model.state == before, "disabled unaffordable Control cannot emit debit")
 observations.append({"case":"ordinary", "gold":state.gold, "points":state.points, "selected":state.selected_hex, "q_rank":state.skills.Q.rank})
 completed_cases.ordinary_four_choice_q1 = true; close(f)
func commerce_case() -> void:
 var f: Dictionary = fresh(true)
 if f.is_empty(): return
 if not await choose(f): close(f); return
 f.open.pressed.emit(); check(f.panel.visible and f.s.panel_open, "actual open Control displays funded shop")
 var stable_list: Array = f.panel._list.get_children()
 var stable_inventory: Array = f.panel._inventory.get_children()
 var stable_request_count: int = f.requests.size()
 f.panel.refresh(false); f.panel.refresh(false)
 check(f.panel._list.get_children() == stable_list and f.panel._inventory.get_children() == stable_inventory, "same-revision nonforced refresh preserves actual visible row identities")
 check(f.panel._inventory.get_child_count() == 6 and f.requests.size() == stable_request_count, "no-op refresh neither clears/duplicates rows nor sends transactions")
 purchase(f, "base:B06")
 # A real skill undo updates the one Model while an already-rendered shop quote
 # remains on screen. No token, ledger revision, or UI quote is patched here.
 if select_item(f, "intermediate:I07"):
  check(f.panel._quote.accepted and f.panel._quote.charge == 650 and f.panel._quote.credit == 450, "partial-component quote charges missing450 component plus original200 fee")
  check(f.panel.recipe_projection.required_counts == {"base:B06":1, "base:B07":1} and f.panel.recipe_projection.owned_counts == {"base:B06":1}, "partial recipe Controls expose source requirements and actual single owned component")
  var stale_revision: int = int(f.panel._quote.token.revision)
  f.skill_undo.pressed.emit()
  check(f.c.last_result.accepted and f.s.ledger.model.state.skills.Q.rank == 0, "real skill undo creates a newer authority revision")
  check(f.s.ledger.model.state.revision > stale_revision, "rendered quote actually became stale")
  var unchanged: Dictionary = f.s.ledger.model.state.duplicate(true)
  f.panel._buy.pressed.emit()
  check(not f.s.last_receipt.accepted and f.s.last_receipt.reason == "stale_revision", "actual craft Button rejects stale rendered quote")
  check(f.s.ledger.model.state == unchanged, "stale Control request cannot debit, consume, or mutate authority")
  f.learn.pressed.emit()
  check(f.c.last_result.accepted and f.sim.hero.ranks.q == 1 and f.s.ledger.model.state.points == 0, "same returned original1SP reactivates Q1")
  f.panel.refresh(true)
 purchase(f, "base:B07")
 var before: Dictionary = f.s.ledger.model.state.duplicate(true)
 var before_hp: float = f.sim.hero.hp
 check(before.inventory.size() == 2 and uid_list(before.inventory)[0] != uid_list(before.inventory)[1], "two original component entries have distinct actual UIDs")
 check(before.gold == 600, "two450 components charge one1500 wallet to600")
 near(f.sim.hero.stats.max_hp, Tuning.hero_stats().max_hp + rows["base:B06"].expected_stats.max_hp, "B06 real maxHP before craft")
 var result: Dictionary = purchase(f, "intermediate:I07")
 var inventory: Array = f.s.ledger.model.state.inventory
 check(result.get("charge", -1) == rows["intermediate:I07"].combine_fee and result.get("credit", -1) == 900, "real craft charges only original200 combine fee")
 check(inventory.size() == 1 and inventory[0].id == "intermediate:I07", "exactly two components consumed and exactly one intermediate held")
 if inventory.size() != 1: close(f); return
 var crafted: Dictionary = inventory[0].duplicate(true)
 check(crafted.uid not in uid_list(before.inventory) and crafted.count == 1 and crafted.invested == 1100 and crafted.lineage.size() == 3, "new UID retains exact two component transaction lineage and total investment")
 check(f.s.ledger.model.equipment_effects().stats == rows["intermediate:I07"].expected_stats, "consumed components do not double-count derived equipment stats")
 near(f.sim.hero.stats.max_hp, Tuning.hero_stats().max_hp + 220, "actual I07 maxHP220 only")
 near(f.sim.hero.stats.defence, Tuning.hero_stats().defence + 18, "actual I07 defense18 only")
 near(f.sim.hero.hp, before_hp, "craft does not heal")
 check(f.s.ledger.model.state.gold == 400, "craft debits one wallet once")
 unchanged_progression(f, before, "craft")
 var journal: Array = f.s.ledger.model.state.shop_visit.undo.duplicate(true)
 var epoch: int = int(f.s.ledger.model.state.shop_visit.epoch)
 f.panel._close.pressed.emit()
 check(not f.s.panel_open and not f.panel.visible, "actual close Button closes shop")
 f.open.pressed.emit()
 check(f.s.ledger.model.state.shop_visit.undo == journal and f.s.ledger.model.state.shop_visit.epoch == epoch, "close/reopen preserves same exact visit journal and epoch")
 check(reverse(f).accepted, "actual craft undo accepted")
 check(f.s.ledger.model.state.inventory == before.inventory and f.s.ledger.model.state.gold == before.gold, "undo restores exact2UID identity/order/count/investment/lineage and money")
 near(f.sim.hero.hp, before_hp, "craft inverse preserves exact pre-craft HP")
 unchanged_progression(f, before, "craft inverse")
 purchase(f, "intermediate:I07")
 crafted = f.s.ledger.model.state.inventory[0].duplicate(true)
 near(f.sim.heal(200, false, {"source":"finite_UI_actual_heal_setup"}), 200, "actual heal establishes560of580 without reward")
 f.panel.refresh(true)
 var pre_sale: Dictionary = f.s.ledger.model.state.duplicate(true)
 check(f.panel._sell_buttons.size() == 1, "actual crafted entry has one sale Control")
 var sale_button: Button = f.panel._sell_buttons[0]
 var sale_button_ref: WeakRef = weakref(sale_button)
 var request_count_before_sale: int = f.requests.size()
 var sale_listener: Dictionary = {"count":0}
 sale_button.pressed.connect(func(): sale_listener.count += 1)
 sale_button.pressed.emit()
 check(f.requests.size() == request_count_before_sale + 1, "sale pressed emits exactly one transaction during immediate refresh")
 check(is_instance_valid(sale_button) and not sale_button.is_inside_tree() and sale_button.disabled, "emitting sale Button is detached and disabled immediately, alive until deferred deletion")
 check(sale_listener.count == 1, "remaining pressed listener still completes exactly once after real transaction listener")
 check(f.panel._inventory.get_child_count() == 6 and f.panel._sell_buttons.is_empty(), "sale synchronously displays exactly six empty replacement rows without duplicates")
 check(f.s.last_receipt.accepted and f.s.last_receipt.refund == 990, "sale Control returns90percent actual1100 investment")
 near(f.sim.hero.hp, 360, "sale clamps actual560HP to source360")
 near(f.s.last_receipt.health_projection.transaction_clamp, 200, "sale owns only actual200HP clamp")
 var inverse: Dictionary = reverse(f)
 check(inverse.accepted and not inverse.health_projection.healing_event_emitted, "sale inverse emits no healing event")
 check(f.s.ledger.model.state.inventory == pre_sale.inventory and f.s.ledger.model.state.gold == pre_sale.gold, "sale undo restores exact crafted UID/lineage and wallet")
 near(f.sim.hero.hp, 560, "sale inverse restores only its200HP clamp")
 near(inverse.health_projection.undo_restored_own_clamp, 200, "health inverse receipt attributes exact200")
 var undo_request: Dictionary = f.requests.back().duplicate(true)
 var after_undo: Dictionary = f.s.ledger.model.state.duplicate(true)
 var requests_after_inverse: int = f.requests.size()
 await process_frame
 await process_frame
 check(sale_button_ref.get_ref() == null, "retired emitting sale Button is actually destroyed on subsequent frames")
 check(f.requests.size() == requests_after_inverse and sale_listener.count == 1, "deferred row retirement duplicates neither transaction nor existing listener")
 var replay: Dictionary = f.s.submit(undo_request.id, undo_request.action, undo_request.arguments)
 check(replay.accepted and not replay.changed and replay.events.is_empty(), "exact accepted Control request replay is inert")
 check(f.s.ledger.model.state == after_undo and f.sim.hero.hp == 560, "replay duplicates neither money, UID nor HP")
 unchanged_progression(f, before, "sale and replay")
 observations.append({"case":"two_uid_craft_hp_inverse", "original_components":before.inventory, "crafted":crafted, "craft_charge":result.get("charge", -1), "restored_hp":f.sim.hero.hp, "restored_gold":f.s.ledger.model.state.gold, "stale_quote_rejected":true, "replay":replay})
 completed_cases.two_uid_craft_hp_inverse = true; close(f)
func unsupported_case() -> void:
 var f: Dictionary = fresh(true)
 if f.is_empty(): return
 if not await choose(f): close(f); return
 f.open.pressed.emit()
 var count: int = 0
 var catalog: Dictionary = f.s.ledger.model.shop_catalog().items
 for id in catalog:
  if catalog[id].equipment_runtime.supported: continue
  count += 1
  if not select_item(f, str(id)): continue
  var before: Dictionary = f.s.ledger.model.state.duplicate(true)
  var before_hp: float = f.sim.hero.hp
  var request_count: int = f.requests.size()
  check(f.panel._buy.disabled and not f.panel._quote.get("accepted", false), "unsupported actual Control disabled before debit: " + id)
  f.panel._buy.pressed.emit()
  check(f.requests.size() == request_count and f.s.ledger.model.state == before, "disabled unsupported Control emits no transaction: " + id)
  for operation in ["buy", "craft"]:
   command_serial += 1
   var args: Dictionary = f.s.ledger.model.commerce_token(); args["item"] = id
   var denied: Dictionary = f.s.submit("unsupported-ui-guard:%d" % command_serial, operation, args)
   check(not denied.accepted and str(denied.reason).begins_with("equipment_runtime_hold:"), "session rejects forged unsupported intent before debit: " + id + "/" + operation)
   check(f.s.ledger.model.state == before and f.sim.hero.hp == before_hp, "unsupported intent preserves exact money/UID/HP/progression: " + id)
 check(count == 55, "exact B12 + I12 +42 final +11 consumable HOLD entries")
 check(f.s.ledger.model.equipment_runtime_status("base:B12").reason == "regen_time_unit_unresolved" and f.s.ledger.model.equipment_runtime_status("intermediate:I12").reason == "regen_time_unit_unresolved", "B12/I12 whole-item regen HOLD remains explicit")
 observations.append({"case":"unsupported_predebit", "blocked_entries":count, "unchanged_gold":f.s.ledger.model.state.gold})
 completed_cases.unsupported_predebit = true; close(f)
func g24_case() -> void:
 var f: Dictionary = fresh(true)
 if f.is_empty(): return
 if not await choose(f, "common_g24"): close(f); return
 f.open.pressed.emit()
 for id in rows["intermediate:I03"].components: purchase(f, str(id))
 var before: Dictionary = f.s.ledger.model.state.duplicate(true)
 check(before.inventory.size() == 3 and before.gold == 50, "G24 actual three source components consume1450 once")
 var base: Dictionary = Tuning.hero_stats()
 near(f.sim.hero.stats.max_hp, base.max_hp * 1.18, "G24 three empty slots produce source18percent maxHP")
 near(f.sim.hero.stats.common_damage_multiplier, 1.24, "G24 three empty slots produce source24percent final damage")
 var hp_before: float = f.sim.hero.hp
 var result: Dictionary = purchase(f, "intermediate:I03")
 check(result.charge == 50 and f.s.ledger.model.state.gold == 0 and f.s.ledger.model.state.inventory.size() == 1, "G24 finite1500 exactly covers three-component craft")
 check(f.s.ledger.model.equipment_effects().stats == rows["intermediate:I03"].expected_stats, "G24 craft stats contain only held I03")
 near(f.sim.hero.stats.max_hp, base.max_hp * 1.24, "G24 five empty slots honor source four-slot cap")
 near(f.sim.hero.stats.common_damage_multiplier, 1.32, "G24 source damage cap recomputed from actual inventory")
 near(f.sim.hero.hp, hp_before, "G24 capacity increase does not heal")
 check(reverse(f).accepted and f.s.ledger.model.state.inventory == before.inventory and f.s.ledger.model.state.gold == before.gold, "G24 undo restores exact three component identities and50 fee")
 near(f.sim.hero.stats.max_hp, base.max_hp * 1.18, "G24 inverse restores three-slot source maxHP")
 near(f.sim.hero.stats.common_damage_multiplier, 1.24, "G24 inverse restores source damage multiplier")
 unchanged_progression(f, before, "G24 inverse")
 observations.append({"case":"G24", "before_slots":3, "crafted_slots":1, "source_empty_slot_cap":4, "gold_after_undo":f.s.ledger.model.state.gold})
 completed_cases.G24_craft_slots = true; close(f)
func g30_case() -> void:
 var f: Dictionary = fresh(true)
 if f.is_empty(): return
 if not await choose(f, "common_g30"): close(f); return
 f.open.pressed.emit()
 purchase(f, "base:B01"); purchase(f, "base:B01")
 var before: Dictionary = f.s.ledger.model.state.duplicate(true)
 check(before.inventory.size() == 2 and uid_list(before.inventory)[0] != uid_list(before.inventory)[1] and before.gold == 600, "G30 duplicate-ID recipe uses two distinct450 UID entries")
 near(f.sim.hero.stats.max_hp, 395, "G30 real remaining600 gives source35HP")
 near(f.sim.heal(35, false, {"source":"finite_UI_G30_actual_heal"}), 35, "actual G30 heal establishes395HP")
 f.panel.refresh(true)
 var result: Dictionary = purchase(f, "intermediate:I01")
 check(result.charge == 200 and f.s.ledger.model.state.gold == 400, "actual craft200 fee crosses G30500gold threshold")
 check(f.s.ledger.model.state.inventory.size() == 1 and f.s.ledger.model.equipment_effects().stats == rows["intermediate:I01"].expected_stats, "two same-ID components contribute no duplicate24AD after28AD craft")
 near(f.sim.hero.stats.ad, Tuning.hero_stats().ad + 28, "actual crafted28AD actor sink")
 near(f.sim.hero.stats.max_hp, 360, "G30 source maxHP responds to real400wallet")
 near(f.sim.hero.stats.defence, Tuning.hero_stats().defence, "G30 source defense responds to actual debit")
 near(f.sim.hero.hp, 360, "G30 actual threshold debit clamps35HP")
 near(result.health_projection.transaction_clamp, 35, "craft transaction owns only35HP clamp")
 var inverse: Dictionary = reverse(f)
 check(inverse.accepted and f.s.ledger.model.state.inventory == before.inventory and f.s.ledger.model.state.gold == 600, "G30 inverse restores exact duplicate component UIDs and200 fee")
 near(f.sim.hero.stats.max_hp, 395, "G30 inverse derives source maxHP from restored600")
 near(f.sim.hero.stats.defence, Tuning.hero_stats().defence + 4, "G30 inverse derives source4defense")
 near(f.sim.hero.hp, 395, "G30 inverse restores its exact35HP clamp")
 near(inverse.health_projection.undo_restored_own_clamp, 35, "G30 inverse receipt35 only")
 check(not inverse.health_projection.healing_event_emitted, "G30 inverse never emits healing proc")
 unchanged_progression(f, before, "G30 inverse")
 observations.append({"case":"G30", "before_gold":600, "crafted_gold":400, "restored_gold":f.s.ledger.model.state.gold, "restored_hp":f.sim.hero.hp})
 completed_cases.G30_craft_debit = true; close(f)
func room_case() -> void:
 var f: Dictionary = fresh(true)
 if f.is_empty(): return
 if not await choose(f): close(f); return
 f.open.pressed.emit()
 purchase(f, "base:B06"); purchase(f, "base:B07"); purchase(f, "intermediate:I07")
 var before: Dictionary = f.s.ledger.model.state.duplicate(true)
 check(not before.shop_visit.undo.is_empty(), "ANY-room test begins with actual reversible craft journal")
 f.panel._close.pressed.emit()
 # Test-owned call through the original bound-owner authority, not a new route.
 # This deliberately checks a noncombat room; formal12-row content remains HOLD.
 var next_room: String = f.s.run_id + "/finite-another-safe-room"
 var committed: Dictionary = f.s._authority("enter_room", {"next_room":next_room})
 check(committed.accepted and f.s.ledger.model.state.shop_visit.room_id == next_room, "existing authority commits ANY next room, including safe room")
 check(f.s.ledger.model.state.shop_visit.undo.is_empty(), "ANY-room authority irreversibly clears prior visit inverse journal")
 f.open.pressed.emit()
 check(f.s.panel_open and f.panel._undo.disabled, "later safe shop exposes no previous-room undo")
 var after: Dictionary = f.s.ledger.model.state.duplicate(true)
 # A programmatic pressed signal can bypass disabled rendering; authority still denies.
 f.panel._undo.pressed.emit()
 check(not f.s.last_receipt.accepted and f.s.last_receipt.reason == "undo_boundary", "previous-room inverse is refused through actual undo signal")
 check(f.s.ledger.model.state == after and f.s.ledger.model.state.inventory == before.inventory and f.s.ledger.model.state.gold == before.gold, "room boundary cannot restore spent money or consumed component UIDs")
 unchanged_progression(f, before, "ANY-room commit")
 check(f.sim.encounter_generation == 0 and f.sim.enemies.is_empty() and f.s.ledger.model.state.reward_ids.is_empty(), "safe-room boundary invents no encounter, kill, or reward")
 observations.append({"case":"any_room_commit", "room":next_room, "gold":f.s.ledger.model.state.gold, "inventory":f.s.ledger.model.state.inventory})
 completed_cases.any_room_commit = true; close(f)
