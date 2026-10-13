extends SceneTree
## PREPARED, NOT RUN BY AUTHOR. Real Ink ledger / mocked external events, source-only fixture.
const Bridge = preload("res://tests/ink_shop_ledger_bridge_20261004/ink_shop_ledger_bridge.gd")
const LedgerProjection = preload("res://tests/ink_shop_ledger_bridge_20261004/commerce_projection.gd")
const Model = preload("res://tests/ink_shop_ledger_bridge_20261004/ink_shop_run_model.gd")
const Numeric = preload("res://tests/equipment_shop_transactions_20261004/numeric_table_adapter.gd")
const SHOP_PATH = "res://tests/ink_first_floor_flow_20261004/fixtures/provisional_shop.json"
const FIXTURE = "res://tests/equipment_shop_transactions_20261004/fixtures/source_prices.json"
const NUMERIC = "res://tests/equipment_editable_tables_20261004/outputs/equipment_tables/converted/equipment_numeric_config.json"
var owner := RefCounted.new()
var serial := 0
var checks := 0
var failures: Array = []

class FixtureJournalSim extends Node:
 var hero: Dictionary = {"actor_id":"yanguizhou"}
 var room_id := "room-1"
 var combat_level_id := "room-1"
 var encounter_generation := 1
 var phase := "combat"
 var wave := 1
 var event_log: Array = []
 var enemy: Dictionary = {"actor_id":"mock_minion", "kind":"minion", "rank_category":"ordinary", "dead":true}
 func enemy_by_id(id: String) -> Dictionary: return enemy if id == enemy.actor_id else {}
 func fixture_kill() -> Dictionary:
  var event: Dictionary = {"kind":"kill", "sequence":1, "room_id":room_id, "combat_level_id":combat_level_id, "generation":encounter_generation, "wave":wave, "target":enemy.actor_id, "credit":"solo_lethal"}
  event_log.append(event.duplicate(true))
  return event

func _initialize() -> void:
 _binding_guards()
 _single_ledger_and_numeric()
 _ordinary_transactions()
 _rooms_and_battle()
 _consumption_and_sealing()
 _body_and_task_receipts()
 _stale_projection()
 print(JSON.stringify({"suite":"ink_single_ledger_shop_bridge", "checks":checks, "failures":failures, "scope":"economic_test_fixture_real_ledger_mock_external_events", "real_gameplay_proved":false, "hp_effects_proved":false, "production_ready":false}))
 quit(0 if failures.is_empty() else 1)

func _capabilities() -> Dictionary:
 var hooks: Array = ["stats.v1", "recovery.v1", "equipment.task_completion.v1", "hex.final_design.yanguizhou_h01.v1"]
 for stat in ["AD", "AP", "attack_speed", "max_hp", "defense", "move_speed", "crit_chance", "cooldown_reduction", "lifesteal", "tenacity", "penetration", "hp_regen"]: hooks.append("stat." + stat + ".v1")
 return {"schema_version":1, "hero_id":"yanguizhou", "source_binding_id":"ECONOMIC_BRIDGE_MOCK_CAPABILITIES_NOT_RUNTIME", "runtime_candidates":["Q1"], "supported_hooks":hooks}

func _new(gold: int = 10000) -> RefCounted:
 var bridge = Bridge.new()
 _check(bridge.initialize_economic_fixture(_capabilities(), SHOP_PATH, FIXTURE, NUMERIC, owner, "fixture-run", true).accepted, "explicit numeric-loaded fixture initializes")
 # Explicit finite fixture funding only. Production bridge has no seed/gold grant API.
 bridge.model.state.gold = gold
 _check(_call(bridge.model, "enter_room", {"next_room":"room-1"}, true).accepted, "host commits initial room instance")
 _check(_call(bridge.model, "begin_visit", {"area":"room-1/shop"}, true).accepted, "host opens actual shop area")
 return bridge

func _call(m: RefCounted, action: String, extra: Dictionary = {}, trusted: bool = false) -> Dictionary:
 serial += 1
 var args: Dictionary = m.commerce_token()
 args.merge(extra, true)
 return m.commerce_authority(owner, "gate-%d" % serial, action, args) if trusted else m.commerce_command("gate-%d" % serial, action, args)

func _bad(m: RefCounted, action: String, extra: Dictionary, expected: String, trusted: bool = false) -> void:
 var before: Dictionary = m.state.duplicate(true)
 var result: Dictionary = _call(m, action, extra, trusted)
 _check(not result.accepted and result.reason == expected, "denied: " + expected)
 _check(m.state == before, "no ledger mutation on denial: " + expected)

func _binding_guards() -> void:
 var b = _new(0)
 var m: RefCounted = b.model
 var sim = FixtureJournalSim.new()
 var before: Dictionary = m.state.duplicate(true)
 _check(m.bind_floor(owner, sim, "different-run").reason == "commerce_floor_run_mismatch" and m.state == before, "shop-first binding refuses a different floor run without mutation")
 _check(m.bind_floor(owner, sim, "fixture-run").accepted, "shop-first binding accepts matching floor run")
 var reverse = Model.new(b.definitions, "yanguizhou")
 reverse.set_supported_hooks(_capabilities().supported_hooks)
 _check(reverse.bind_floor(owner, sim, "floor-first-run").accepted, "floor-first binding fixture initialized")
 before = reverse.state.duplicate(true)
 _check(reverse.bind_commerce(owner, m.commerce_definitions, "other-run", true).reason == "commerce_floor_run_mismatch" and reverse.state == before, "floor-first binding refuses different commerce run without mutation")
 _check(reverse.bind_commerce(owner, m.commerce_definitions, "floor-first-run", true).accepted, "floor-first binding accepts matching commerce run")
 var ephemeral: RefCounted = RefCounted.new()
 var expired = Model.new(b.definitions, "yanguizhou")
 _check(expired.bind_commerce(ephemeral, m.commerce_definitions, "expired-owner-run", true).accepted, "ephemeral owner fixture binds")
 ephemeral = null
 before = expired.state.duplicate(true)
 _check(expired.commerce_authority(null, "expired-owner-call", "enter_room", expired.commerce_token()).reason == "wrong_commerce_authority" and expired.state == before, "expired WeakRef and null caller cannot become trusted authority")
 sim.free()

func _single_ledger_and_numeric() -> void:
 var disabled = Bridge.new()
 _check(not disabled.initialize_economic_fixture(_capabilities(), SHOP_PATH, FIXTURE, NUMERIC, owner, "fixture-run").accepted, "economic fixture opt-in required")
 _check(not disabled.initialize(_capabilities(), SHOP_PATH, true).accepted, "cannot silently replace normal initialization")
 var b = _new(0)
 var m: RefCounted = b.model
 _check(m.state.level == 1 and m.state.points == 1 and m.state.xp == 0 and m.state.selected_hex.is_empty(), "fresh growth remains Lv1/1SP without selected Hex")
 _check(m.snapshot().pending_milestones == [1], "initial Hex HOLD preserved")
 for key in LedgerProjection.AUTHORITY_FIELDS: _check(not m.state.shop_visit.has(key), "visit metadata has no duplicate authority field: " + key)
 _check(m.config.equipment_tasks.is_empty(), "old placeholder equipment tasks not stacked on new receipt import")
 var sim = FixtureJournalSim.new()
 _check(m.bind_floor(owner, sim, "fixture-run").accepted, "same run ledger binds existing verified event path")
 _check(m.command("set-combat-room", "enter_level", {"combat_level_id":"room-1"}).accepted, "existing combat room accepts committed room receipt")
 var begin: Dictionary = b.begin_encounter()
 _check(begin.ok and begin.events.size() == 2 and begin.receipt.accepted, "existing bridge begin encounter uses same ledger and forwards lifecycle receipt")
 var event: Dictionary = sim.fixture_kill()
 _check(m.observe_live_event(owner, sim, event).accepted, "mock journal kill enters actual Ink reward authority")
 _check(m.state.gold == 20 and m.state.xp == 12, "one native kill receipt credits source 20g and 12XP once")
 _check(m.observe_live_event(owner, sim, event).accepted and m.state.gold == 20, "duplicate native kill cannot add another wallet credit")
 _check(b.end_encounter().ok, "existing bridge ends encounter")
 _check(_call(m, "begin_visit", {"area":"room-1/shop-after"}, true).accepted, "new postbattle shop visit")
 _bad(m, "credit_reward", {"reward_id":"duplicate-channel", "gold":20}, "existing_ink_reward_authority_only", true)
 var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
 var numeric: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(NUMERIC))
 numeric.parameters["base:B01.price"].value = 13
 var edited: Dictionary = Numeric.build(fixture, numeric)
 _check(edited.accepted and edited.definitions.items["base:B01"].price == 13 and fixture.items["base:B01"].price == 450, "editable numeric projection does not rewrite frozen source")
 # A separate constructor is used for edited config, never hot swap an in-flight run.
 var tuned = Model.new(b.definitions, "yanguizhou")
 tuned.set_supported_hooks(_capabilities().supported_hooks)
 _check(tuned.bind_commerce(owner, edited.definitions, "edited-run", true).accepted, "fresh edited numeric config binds")
 tuned.state.gold = 20 # Fixture funding matches native receipt value; not another reward authority.
 _call(tuned, "enter_room", {"next_room":"edit-room"}, true)
 _call(tuned, "begin_visit", {"area":"edit-shop"}, true)
 _check(_call(tuned, "buy", {"item":"base:B01"}).accepted and tuned.state.gold == 7, "ledger uses edited 13g once rather than frozen source price")
 _check(_call(tuned, "undo").accepted and tuned.state.gold == 20, "edited price refunds exact investment once")
 _check(m.state.gold == 20 and m.state.inventory.is_empty(), "separate run fixture never alters existing ledger")
 sim.free()

func _ordinary_transactions() -> void:
 var b = _new()
 var m: RefCounted = b.model
 _check(not m.command("legacy-buy", "buy", {"item":"base:B01"}).accepted, "legacy buy bypass closed")
 _check(not m.command("legacy-undo", "undo_shop").accepted, "legacy whole inventory undo closed")
 _call(m, "buy", {"item":"base:B01"})
 _call(m, "buy", {"item":"base:B01"})
 var before: Dictionary = m.state.duplicate(true)
 var quote: Dictionary = m.commerce_quote("intermediate:I01")
 _check(quote.accepted and quote.charge == 200 and quote.credit == 900 and m.state == before, "quote exact component credit and no live writes")
 _check(_call(m, "craft", {"item":"intermediate:I01"}).accepted and m.state.gold == 8900 and m.state.inventory.size() == 1, "source craft applies one 200g residual debit")
 _check(_call(m, "undo").accepted and m.state.gold == before.gold and m.state.inventory == before.inventory, "craft inverse restores exact component UIDs")
 _check(_call(m, "sell", {"uid":m.state.inventory[0].uid}).refund == 405, "sale source fraction uses actual investment")
 _check(_call(m, "undo").accepted and m.state.inventory == before.inventory and m.state.gold == before.gold, "sale inverse restores only matching item and money delta")
 _call(m, "close_ui")
 _call(m, "open_ui")
 _check(_call(m, "undo").accepted and m.state.inventory.size() == 1, "UI close/open keeps same visit undo")
 var args: Dictionary = m.commerce_token(); args["item"] = "base:B02"
 var once: Dictionary = m.commerce_command("repeat-click", "buy", args)
 var committed: Dictionary = m.state.duplicate(true)
 var replay: Dictionary = m.commerce_command("repeat-click", "buy", args)
 _check(once.accepted and replay.accepted and not replay.changed and replay.events.is_empty() and m.state == committed, "one ledger receipt suppresses repeated debit and event")
 _check(not m.commerce_command("new-old-quote", "buy", args).accepted and m.state == committed, "stale quote rejected against live ledger revision")
 _check(not m.commerce_command("repeat-click", "sell", args).accepted and m.state == committed, "conflicting command ID rejected")
 _check(m.snapshot().inventory == m.state.inventory and m.equipment_effects().stats.is_empty(), "snapshot names real items but does not fabricate gameplay effects")
 _bad(m, "buy", {"item":"potion:1"}, "unresolved_potion_slot_policy")
 _bad(m, "enter_room", {"next_room":"forged-room"}, "authority_required")
 var stranger := RefCounted.new()
 _check(not m.commerce_authority(stranger, "foreign", "enter_room", m.commerce_token()).accepted, "wrong host cannot change visit")

func _rooms_and_battle() -> void:
 var b = _new()
 var m: RefCounted = b.model
 _call(m, "buy", {"item":"base:B01"})
 var old: Dictionary = m.commerce_token()
 _check(_call(m, "enter_room", {"next_room":"noncombat-event-room"}, true).accepted, "ANY next noncombat room commits visit")
 _check(m.state.shop_visit.undo.is_empty() and not m.state.shop_visit.shop_active, "noncombat transition clears journal and area")
 _call(m, "begin_visit", {"area":"event-shop"}, true)
 _bad(m, "undo", {}, "undo_boundary")
 old["item"] = "base:B02"
 _check(not m.commerce_command("old-room-click", "buy", old).accepted, "old room token cannot trade in later shop")
 _call(m, "buy", {"item":"base:B02"})
 _call(m, "enter_room", {"next_room":"combat-room-2"}, true)
 _check(m.state.shop_visit.undo.is_empty(), "combat-room transition also commits before encounter")
 _check(m.command("unmatched-level", "enter_level", {"combat_level_id":"not-committed"}).reason == "committed_room_receipt_required", "uncommitted transition cannot bypass area receipt")
 _check(m.command("matching-level", "enter_level", {"combat_level_id":"combat-room-2"}).accepted, "committed combat room enters original ledger lifecycle")
 _check(b.begin_encounter().ok, "battle starts")
 _bad(m, "undo", {}, "unsafe_phase")
 _bad(m, "buy", {"item":"base:B01"}, "unsafe_phase")
 _check(b.end_encounter().ok, "battle ends")
 _call(m, "begin_visit", {"area":"combat-room-2/shop"}, true)
 _bad(m, "undo", {}, "undo_boundary")
 _call(m, "buy", {"item":"base:B03"})
 _call(m, "leave_area", {}, true)
 _call(m, "begin_visit", {"area":"combat-room-2/shop"}, true)
 _bad(m, "undo", {}, "undo_boundary")

func _consumption_and_sealing() -> void:
 var b = _new()
 var m: RefCounted = b.model
 _call(m, "buy", {"item":"elixir:01"})
 var uid: int = m.state.inventory[0].uid
 _call(m, "buy", {"item":"base:B01"})
 var args: Dictionary = m.commerce_token(); args["uid"] = uid
 var result: Dictionary = m.commerce_command("consume-once", "consume", args)
 _check(result.accepted and result.events.size() == 1 and result.events[0].has("effect_id"), "consumption returns one committed effect intent")
 var effects: Dictionary = m.state.shop_visit.effect_receipts.duplicate(true)
 var replay: Dictionary = m.commerce_command("consume-once", "consume", args)
 _check(replay.accepted and replay.events.is_empty() and not replay.changed and m.state.shop_visit.effect_receipts == effects, "consumption replay cannot duplicate effect")
 _check(_call(m, "undo").accepted and m.state.inventory.is_empty() and m.state.shop_visit.effect_receipts == effects, "unrelated purchase undo preserves consumed elixir")
 _bad(m, "undo", {}, "already_used")
 var full = _new()
 m = full.model
 for i in range(6): _call(m, "buy", {"item":"base:B01"})
 var gold: int = m.state.gold
 var quote: Dictionary = m.commerce_quote("elixir:01")
 _check(quote.auto_drink and m.state.shop_visit.active_elixir.is_empty(), "full-slot quote advertises auto-drink without effect")
 _check(_call(m, "buy", {"item":"elixir:01"}).accepted and m.state.gold == gold-650 and m.state.inventory.size() == 6, "auto-drink debits once without seventh slot")
 _bad(m, "buy", {"item":"elixir:01"}, "same_name_elixir_active")
 _check(_call(m, "undo").accepted and m.state.inventory.size() == 5 and m.state.shop_visit.active_elixir.item == "elixir:01", "auto-drink seals itself but not unrelated equipment")
 _call(m, "enter_room", {"next_room":"quiet-room"}, true)
 _check(m.state.shop_visit.active_elixir.item == "elixir:01", "pending elixir survives noncombat room commit")
 m.command("elixir-combat-room", "enter_level", {"combat_level_id":"quiet-room"})
 var begun: Dictionary = m.command("elixir-start", "context", {"phase":"combat"})
 _check(begun.accepted and not m.state.shop_visit.active_elixir.battle_id.is_empty() and begun.events.size() == 2, "lifecycle delivers pending battle effect projection once")
 var repeated: Dictionary = m.command("elixir-start", "context", {"phase":"combat"})
 _check(repeated.accepted and repeated.events.is_empty(), "replayed lifecycle receipt emits no second effect projection")
 _check(m.command("elixir-end", "context", {"phase":"safe"}).accepted and m.state.shop_visit.active_elixir.is_empty(), "battle end clears pending effect exactly once")
 var flask = _new()
 m = flask.model
 _check(_call(m, "buy", {"item":"flask:1"}).accepted and m.state.inventory.size() == 1, "flask occupies existing six-slot inventory")
 _bad(m, "sell", {"uid":m.state.inventory[0].uid}, "unresolved_flask_switch_economics")
 _bad(m, "consume_recovery", {"uid":m.state.inventory[0].uid, "effect_id":"flask-effect", "consumer_preflight_passed":false}, "recovery_consumer_not_ready", true)
 m.command("flask-level", "enter_level", {"combat_level_id":"room-1"})
 flask.begin_encounter()
 _check(m.state.shop_visit.flask_charges == 2, "only battle start grants two flask charges")
 var recover: Dictionary = _call(m, "consume_recovery", {"uid":m.state.inventory[0].uid, "effect_id":"flask-effect", "consumer_preflight_passed":true}, true)
 _check(recover.accepted and recover.events.size() == 1 and m.state.shop_visit.flask_charges == 1, "trusted consumer gets recovery receipt with one use consumed")
 _bad(m, "consume_recovery", {"uid":m.state.inventory[0].uid, "effect_id":"flask-effect", "consumer_preflight_passed":true}, "fresh_effect_required", true)

func _body_and_task_receipts() -> void:
 var b = _new(2000)
 var m: RefCounted = b.model
 _call(m, "buy", {"item":"base:B01"})
 var paid: Dictionary = _call(m, "pay_body", {"purchase_id":"body-1"}, true)
 _check(paid.accepted, "bound body intent invokes existing three-choice authority")
 _check(paid.ledger_purchase_id == m.state.body[0].purchase_id and paid.events[0].ledger_purchase_id == paid.ledger_purchase_id and m.state.shop_visit.body_receipts["body-1"].ledger_purchase_id == paid.ledger_purchase_id, "body receipt maps external ID to actual selectable ledger purchase")
 _check(m.state.gold == 650 and m.state.body.size() == 1 and m.state.body[0].candidates.size() == 3, "actual ledger body debit occurs once, not twice")
 var purchase: Dictionary = m.state.body[0]
 _check(m.command("pick-body", "select_body", {"purchase_id":paid.ledger_purchase_id, "outcome":purchase.candidates[0]}).accepted, "existing body choice remains selectable")
 var body: Array = m.state.body.duplicate(true)
 var rng: int = m.state.rng
 _check(b.invest("Q", "Q1").ok, "unrelated skill progression changes real ledger")
 var skills: Dictionary = m.state.skills.duplicate(true)
 _check(_call(m, "undo").accepted and m.state.gold == 1100 and m.state.inventory.is_empty(), "equipment inverse leaves paid body cost deducted")
 _check(m.state.body == body and m.state.rng == rng and m.state.skills == skills and m.state.points == 0, "undo does not restore body/RNG/skills/points")
 _bad(m, "pay_body", {"purchase_id":"body-1"}, "fresh_body_purchase_required", true)
 var sale = _new(950)
 m = sale.model
 _call(m, "buy", {"item":"base:B01"})
 _call(m, "sell", {"uid":m.state.inventory[0].uid})
 _call(m, "pay_body", {"purchase_id":"sale-funded-body"}, true)
 _check(m.state.gold == 5 and m.state.body.size() == 1, "sale proceeds may fund one irreversible body purchase")
 _bad(m, "undo", {}, "insufficient_gold")
 _check(m.state.body.size() == 1 and m.state.inventory.is_empty(), "failed sale inverse cannot rewind body or mint inventory")
 var tasks = _new(12000)
 m = tasks.model
 _call(m, "buy", {"item":"base:B07"})
 _call(m, "buy", {"item":"base:B10"})
 _call(m, "craft", {"item":"intermediate:I15"})
 _call(m, "craft", {"item":"final:G05"})
 _call(m, "buy", {"item":"base:B01"})
 var fact: Dictionary = {"equipment_id":"final:G05", "event_id":"verified-fixture-stage-1", "progress":5, "stage":"1", "reward_key":"free-body-stage-1"}
 # Explicit external task-authority fixture: reward already exists; bridge only imports receipt.
 m.state["fixture_claimed_rewards"] = {"free-body-stage-1":{"claimed":true}}
 var points: int = m.state.points
 _check(_call(m, "task_effect", fact, true).accepted, "verified task receipt seals acquisition and craft dependencies")
 var ledger: Dictionary = m.state.shop_visit.taskLedger.duplicate(true)
 _check(_call(m, "undo").accepted and m.state.inventory.size() == 1 and m.state.shop_visit.taskLedger == ledger, "unrelated equipment stays reversible after reward seal")
 _bad(m, "undo", {}, "reward_already_claimed")
 _check(m.state.fixture_claimed_rewards["free-body-stage-1"].claimed and m.state.points == points, "import/undo neither revokes nor regrants already claimed reward")
 _call(m, "sell", {"uid":m.state.inventory[0].uid})
 _check(_call(m, "undo").accepted and m.state.shop_visit.taskLedger == ledger, "task-item sale/undo cannot clear reward ledger")
 _bad(m, "task_effect", fact, "task_event_already_recorded", true)
 _bad(m, "task_effect", {"equipment_id":"final:G04", "event_id":"gold-source", "progress":1}, "unresolved_gold_task_sources", true)

func _stale_projection() -> void:
 var b = _new()
 var m: RefCounted = b.model
 var evaluated: Dictionary = LedgerProjection.evaluate(m.state, m.commerce_definitions, "buy", {"item":"base:B01"}, false)
 _check(evaluated.accepted, "detached preflight produces bounded write patch")
 # Minimum single-thread reentry analogue: real ledger command happens before commit.
 _check(b.invest("Q", "Q1").ok, "intervening actual ledger command advances revision")
 var after: Dictionary = m.state.duplicate(true)
 _check(LedgerProjection.commit(m.state, evaluated.patch, 6) == "stale_ledger_revision" and m.state == after, "stale preflight cannot overwrite newer progression")
 evaluated = LedgerProjection.evaluate(m.state, m.commerce_definitions, "buy", {"item":"base:B01"}, false)
 # Separate explicit external-authority mutation fixtures, not invented gold event policy.
 m.state.gold += 17
 m.state.revision += 1
 after = m.state.duplicate(true)
 _check(LedgerProjection.commit(m.state, evaluated.patch, 6) == "stale_ledger_revision" and m.state == after and m.state.gold == 10017, "new gold arriving after preflight survives stale rejection")
 _call(m, "buy", {"item":"elixir:01"})
 evaluated = LedgerProjection.evaluate(m.state, m.commerce_definitions, "buy", {"item":"base:B02"}, false)
 _check(_call(m, "consume", {"uid":m.state.inventory[0].uid}).accepted, "consumption can commit between separate fixture preflight and commit")
 after = m.state.duplicate(true)
 _check(LedgerProjection.commit(m.state, evaluated.patch, 6) == "stale_ledger_revision" and m.state == after and m.state.inventory.is_empty(), "stale purchase cannot resurrect consumed inventory")
 evaluated = LedgerProjection.evaluate(m.state, m.commerce_definitions, "buy", {"item":"base:B02"}, false)
 m.state.gold += 3 # Defense even if a buggy external writer forgot to increment revision.
 after = m.state.duplicate(true)
 _check(LedgerProjection.commit(m.state, evaluated.patch, 6) == "ledger_currency_precondition" and m.state == after, "exact currency precondition also guards unversioned mutation")

func _check(value: bool, label: String) -> void:
 checks += 1
 if not value: failures.append(label)
