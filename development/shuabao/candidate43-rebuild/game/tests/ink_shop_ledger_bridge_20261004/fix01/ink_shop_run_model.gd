extends "res://tests/ink_first_floor_flow_20261004/ink_run_model.gd"
## Isolated ECONOMIC TEST FIXTURE over the real single-run Ink ledger.
## No new combat item effects, migration, final UI, automatic rewards or HP healing.
const LedgerProjection = preload("res://tests/ink_shop_ledger_bridge_20261004/commerce_projection.gd")
var commerce_definitions: Dictionary = {}
var _commerce_owner: WeakRef
var _authority_request: Dictionary = {}
var _commerce_result: Dictionary = {}

func bind_commerce(owner: RefCounted, definitions: Dictionary, run_id: String, allow_economic_fixture: bool = false) -> Dictionary:
 if not allow_economic_fixture: return _deny("economic_fixture_opt_in_required")
 if owner == null or _commerce_owner != null or run_id.is_empty(): return _deny("commerce_binding_invalid")
 if not _run_id.is_empty() and _run_id != run_id: return _deny("commerce_floor_run_mismatch")
 if state.hero_id != "yanguizhou" or state.revision != 0 or not state.inventory.is_empty() or not state.shop_undo.is_empty(): return _deny("fresh_ink_ledger_required")
 if definitions.get("hero_id", "") != "yanguizhou" or int(definitions.get("slot_limit", 0)) != 6: return _deny("invalid_commerce_definition")
 _commerce_owner = weakref(owner)
 commerce_definitions = definitions.duplicate(true)
 state["shop_visit"] = LedgerProjection.initial_metadata(run_id, str(state.actor_id))
 # Both are instance-local configuration clones. Old placeholder equipment tasks do not stack.
 config.equipment_tasks = {}
 config.body.cost = int(commerce_definitions.body_price)
 return {"accepted":true, "reason":"", "economic_fixture_only":true}

func bind_floor(owner: RefCounted, sim: Node, run_id: String) -> Dictionary:
 if not commerce_definitions.is_empty() and run_id != state.shop_visit.run_id: return _deny("commerce_floor_run_mismatch")
 return super.bind_floor(owner, sim, run_id)

func commerce_token() -> Dictionary:
 if not state.has("shop_visit"): return {}
 return {"epoch":state.shop_visit.epoch, "revision":state.revision, "room_id":state.shop_visit.room_id}

func commerce_quote(item_id: String) -> Dictionary:
 if commerce_definitions.is_empty(): return _deny("commerce_unbound")
 var result: Dictionary = LedgerProjection.evaluate(state, commerce_definitions, "buy", {"item":item_id}, false)
 result.erase("patch")
 result["events"] = []
 result["token"] = commerce_token()
 if result.accepted: result["outcome_text"] = "装备栏已满，购买后立即饮用；该笔已使用交易不能撤回" if result.get("auto_drink", false) else "购买后放入装备栏"
 result["economic_fixture_only"] = true
 return result

func commerce_command(id: String, action: String, args: Dictionary) -> Dictionary:
 return command(id, "commerce", {"operation":action, "arguments":args.duplicate(true), "trusted":false})

func commerce_authority(owner: RefCounted, id: String, action: String, args: Dictionary) -> Dictionary:
 if owner == null or _commerce_owner == null: return _deny("wrong_commerce_authority")
 var bound_owner: RefCounted = _commerce_owner.get_ref()
 if bound_owner == null or not is_same(bound_owner, owner): return _deny("wrong_commerce_authority")
 if not _authority_request.is_empty(): return _deny("reentrant_commerce_request")
 var request: Dictionary = {"operation":action, "arguments":args.duplicate(true), "trusted":true}
 _authority_request = request.duplicate(true)
 var result: Dictionary = command(id, "commerce", request)
 _authority_request = {}
 return result

func command(id: String, action: String, args: Dictionary = {}) -> Dictionary:
 var replay: bool = receipts.has(id)
 _commerce_result = {}
 var result: Dictionary = super.command(id, action, args)
 if replay:
  result["changed"] = false
  result["replayed"] = result.accepted
  result["events"] = []
  return result
 result["changed"] = result.accepted
 if result.accepted and action == "commerce":
  # The ledger command owns dedupe. Event receipts are returned only on first commit.
  result["events"] = _commerce_result.get("events", []).duplicate(true)
  for key in _commerce_result:
   if key not in ["accepted", "reason", "events", "patch"]: result[key] = _commerce_result[key]
  result["economic_fixture_only"] = true
 if result.accepted and action != "commerce" and not _commerce_result.is_empty():
  result.events.append_array(_commerce_result.get("events", []).duplicate(true))
 if receipts.has(id): receipts[id].result = result.duplicate(true)
 _commerce_result = {}
 return result

func _apply(action: String, args: Dictionary) -> String:
 if commerce_definitions.is_empty(): return super._apply(action, args)
 if action in ["buy", "sell", "undo_shop", "use_item", "buy_body", "open_shop"]: return "commerce_intent_required"
 if action == "commerce": return _apply_commerce(args)
 if action == "enter_level":
  # A successful ANY-room transition must already be registered by the bound host.
  if args.get("combat_level_id", "") != state.shop_visit.room_id: return "committed_room_receipt_required"
 if action == "context":
  var next_phase: String = str(args.get("phase", ""))
  if next_phase not in ["safe", "combat"]: return "invalid_phase"
  if next_phase != state.phase:
   var operation: String = "battle_begin" if next_phase == "combat" else "battle_end"
   var battle_id: String = str(state.shop_visit.run_id) + "|" + str(state.shop_visit.room_id) + "|battle"
   if next_phase == "combat" and state.combat_level_id != state.shop_visit.room_id: return "committed_combat_room_required"
   var projected: Dictionary = LedgerProjection.evaluate(state, commerce_definitions, operation, {"battle_id":battle_id}, true)
   if not projected.accepted: return projected.reason
   var reason: String = LedgerProjection.commit(state, projected.patch, int(commerce_definitions.slot_limit))
   if not reason.is_empty(): return reason
   _commerce_result = projected.duplicate(true)
   _commerce_result.erase("patch")
 return super._apply(action, args)

func _apply_commerce(envelope: Dictionary) -> String:
 var trusted: bool = bool(envelope.get("trusted", false))
 if trusted and (envelope != _authority_request or _authority_request.is_empty()): return "commerce_authority_required"
 var operation: String = str(envelope.get("operation", ""))
 var args: Dictionary = envelope.get("arguments", {})
 var token: Dictionary = commerce_token()
 if args.get("epoch", -1) != token.epoch: return "stale_epoch"
 if args.get("revision", -1) != token.revision: return "stale_revision"
 if args.get("room_id", "") != token.room_id: return "stale_room"
 # Rewards are already credited by the verified Ink kill authority. Never credit twice.
 if operation == "credit_reward": return "existing_ink_reward_authority_only"
 # Context/life state have one existing authority; do not let commerce disagree with it.
 if operation in ["battle_begin", "battle_end", "life_state"]: return "existing_ink_lifecycle_authority_only"
 if operation not in ["buy", "craft", "sell", "undo", "consume", "open_ui", "close_ui", "enter_room", "begin_visit", "leave_area", "pay_body", "task_effect", "consume_recovery"]: return "unknown_commerce_intent"
 var projected: Dictionary = LedgerProjection.evaluate(state, commerce_definitions, operation, args, trusted)
 if not projected.accepted: return projected.reason
 var debit_already_applied := false
 if operation == "pay_body":
  # Parent body implementation preflights its real three-choice pool, records the outcome,
  # and charges ONCE. Frozen kernel supplies only transaction/dependency bookkeeping.
  var body_reason: String = super._apply("buy_body", {})
  if not body_reason.is_empty(): return body_reason
  debit_already_applied = true
  var ledger_purchase_id: int = int(state.body.back().purchase_id)
  projected.patch.metadata.body_receipts[str(args.purchase_id)]["ledger_purchase_id"] = ledger_purchase_id
  projected["ledger_purchase_id"] = ledger_purchase_id
  for event in projected.events:
   if event.get("type", "") == "body_payment_committed": event["ledger_purchase_id"] = ledger_purchase_id
 var reason: String = LedgerProjection.commit(state, projected.patch, int(commerce_definitions.slot_limit), debit_already_applied)
 if not reason.is_empty(): return reason
 _commerce_result = projected.duplicate(true)
 _commerce_result.erase("patch")
 return ""

func snapshot() -> Dictionary:
 if commerce_definitions.is_empty(): return super.snapshot()
 # The old catalog snapshot indexes old item IDs. Do not disguise new items as old IDs.
 var out: Dictionary = state.duplicate(true)
 out["definition_version"] = config.get("version", "unresolved")
 out["rank_caps"] = {"P":4, "Q":6, "E":6, "R":4}
 out["leveling_sp_budget"] = 18
 out["full_build_cost"] = 23
 out["pending_milestones"] = []
 for milestone in [1, 4, 7, 10, 13]:
  if milestone <= state.level and (not state.offers.has(str(milestone)) or state.offers[str(milestone)].selected.is_empty()): out.pending_milestones.append(milestone)
 out["hex_status"] = {}
 for id in state.selected_hex:
  out.hex_status[id] = "unsupported" if not support(config.hexes[id]).supported else ("active" if _dependency_met(config.hexes[id]) else "dormant")
 out["body_pending"] = {}
 for purchase in state.body:
  if purchase.get("selected", "").is_empty(): out.body_pending = purchase.duplicate(true)
 out["equipment_task_status"] = equipment_task_status()
 out["content_profile"] = "economic_bridge_test_fixture"
 out["catalog_errors"] = catalog_errors.duplicate()
 out["content_warnings"] = [{"reason":"new_equipment_combat_consumers_not_connected"}]
 out["production_ready"] = false
 return out

func equipment_task_status() -> Dictionary:
 if commerce_definitions.is_empty(): return super.equipment_task_status()
 return {"status":"verified_receipts_only_no_criteria_or_reward_grant", "receipts":state.shop_visit.taskLedger.duplicate(true)}

func equipment_effects() -> Dictionary:
 if commerce_definitions.is_empty(): return super.equipment_effects()
 return {"stats":{}, "passives":[], "status":"economic_fixture_no_combat_effects"}

func purchase_quote(id: String) -> Dictionary:
 if commerce_definitions.is_empty(): return super.purchase_quote(id)
 return commerce_quote(id)

func shop_catalog() -> Dictionary:
 if commerce_definitions.is_empty(): return super.shop_catalog()
 return {"economic_fixture_only":true, "items":commerce_definitions.items.duplicate(true), "gameplay_ready":false}

func restore(_checkpoint: Dictionary) -> bool:
 # No mixed old-save migration or unvalidated external checkpoint import in this candidate.
 return false
