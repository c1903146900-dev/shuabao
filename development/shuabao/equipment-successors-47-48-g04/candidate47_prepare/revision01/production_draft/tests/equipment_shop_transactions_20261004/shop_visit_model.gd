extends RefCounted
## Isolated economic candidate. No Node, timer, HP mutation, passive implementation or promotion.
## Failed commands stage a detached copy; undo applies inverse item patches + gold delta ONLY.
var config: Dictionary
var state: Dictionary
var receipts: Dictionary = {}
var _owner: WeakRef

func _init(definitions: Dictionary = {}, authority: RefCounted = null, run_id: String = "", actor_id: String = "yanguizhou") -> void:
 config = definitions.duplicate(true)
 if authority != null: _owner = weakref(authority)
 state = {"run_id":run_id, "actor_id":actor_id, "hero_id":"yanguizhou", "actor_dead":false, "revision":0, "epoch":0, "room_id":"", "visited_rooms":[], "shop_area":"", "shop_active":false, "ui_open":false, "phase":"safe", "gold":0, "inventory":[], "next_uid":1, "next_tx":1, "undo":[], "body_receipts":{}, "taskLedger":{}, "effect_receipts":{}, "active_elixir":{}, "battle_id":"", "flask_charges":0, "flask_entitlement":"", "flask_uses_by_battle":{}}

func snapshot() -> Dictionary:
 return state.duplicate(true)

func token() -> Dictionary:
 return {"epoch":state.epoch, "revision":state.revision, "room_id":state.room_id}

func command(id: String, action: String, args: Dictionary = {}) -> Dictionary:
 return _dispatch(id, action, args, false)

func authority_command(owner: RefCounted, id: String, action: String, args: Dictionary = {}) -> Dictionary:
 if _owner == null or not is_same(_owner.get_ref(), owner): return _deny("wrong_authority")
 return _dispatch(id, action, args, true)

func quote(item_id: String) -> Dictionary:
 var draft: Dictionary = state.duplicate(true)
 var result: Dictionary = _buy(draft, item_id)
 result["token"] = token()
 if result.accepted:
  result["outcome_text"] = "装备栏已满，购买后立即饮用；该笔已使用交易不能撤回" if result.get("auto_drink", false) else "购买后放入装备栏"
 return result

func _dispatch(id: String, action: String, args: Dictionary, trusted: bool) -> Dictionary:
 if id.is_empty(): return _deny("missing_command_id")
 var request: Dictionary = {"action":action, "args":args.duplicate(true), "trusted":trusted}
 if receipts.has(id):
  if receipts[id].request != request: return _deny("command_id_conflict")
  var duplicate: Dictionary = receipts[id].result.duplicate(true)
  duplicate["changed"] = false
  duplicate["replayed"] = true
  duplicate["events"] = [] # Never dispatch consumed effects or task/body rewards twice.
  return duplicate
 if args.get("epoch", -1) != state.epoch: return _deny("stale_epoch")
 if args.get("revision", -1) != state.revision: return _deny("stale_revision")
 if args.get("room_id", "") != state.room_id: return _deny("stale_room")
 var draft: Dictionary = state.duplicate(true)
 var result: Dictionary = _apply(draft, action, args, trusted)
 if result.accepted:
  draft.revision += 1
  state = draft
 result["changed"] = result.accepted
 result["revision"] = state.revision
 result["epoch"] = state.epoch
 receipts[id] = {"request":request, "result":result.duplicate(true)}
 return result

func _apply(s: Dictionary, action: String, args: Dictionary, trusted: bool) -> Dictionary:
 if action in ["enter_room", "begin_visit", "leave_area", "battle_begin", "battle_end", "credit_reward", "pay_body", "task_effect", "consume_recovery", "life_state"]:
  if not trusted: return _deny("authority_required")
  return _authority_apply(s, action, args)
 if action in ["open_ui", "close_ui"]:
  if s.phase != "safe" or not s.shop_active: return _deny("shop_visit_required")
  s.ui_open = action == "open_ui"
  return _ok()
 var allowed: String = _trade_guard(s)
 if not allowed.is_empty(): return _deny(allowed)
 match action:
  "buy", "craft": return _buy(s, str(args.get("item", "")))
  "sell": return _sell(s, int(args.get("uid", -1)))
  "undo": return _undo(s)
  "consume": return _consume(s, int(args.get("uid", -1)))
 return _deny("unknown_command")

func _authority_apply(s: Dictionary, action: String, args: Dictionary) -> Dictionary:
 match action:
  "life_state":
   if not args.get("dead") is bool: return _deny("invalid_life_state")
   s.actor_dead = args.dead
   return _ok()
  "enter_room":
   var next: String = str(args.get("next_room", ""))
   if next.is_empty(): return _deny("missing_room")
   if next == s.room_id or next in s.visited_rooms: return _deny("room_already_entered")
   if s.phase == "combat": return _deny("battle_end_required")
   # ALL rooms commit, including noncombat. A UI close never calls this.
   _commit_visit(s)
   s.room_id = next
   s.visited_rooms.append(next)
   return _ok()
  "begin_visit":
   if s.phase != "safe" or s.room_id.is_empty(): return _deny("safe_room_required")
   var area: String = str(args.get("area", ""))
   if area.is_empty(): return _deny("missing_shop_area")
   if s.shop_active: return _deny("visit_already_active")
   s.epoch += 1
   s.shop_active = true
   s.shop_area = area
   s.ui_open = false
   return _ok()
  "leave_area":
   if not s.shop_active: return _deny("shop_visit_required")
   _commit_visit(s)
   return _ok()
  "battle_begin":
   if s.phase != "safe" or s.room_id.is_empty(): return _deny("safe_room_required")
   var battle: String = str(args.get("battle_id", ""))
   if battle.is_empty() or battle in s.effect_receipts: return _deny("fresh_battle_required")
   _commit_visit(s)
   s.phase = "combat"
   s.battle_id = battle
   s.effect_receipts[battle] = {"kind":"battle_started"}
   s.flask_uses_by_battle[battle] = 0
   s.flask_charges = 2 if not s.flask_entitlement.is_empty() else 0
   if not s.active_elixir.is_empty(): s.active_elixir["battle_id"] = battle
   return _ok([{"type":"battle_effect_projection", "elixir":s.active_elixir.duplicate(true)}])
  "battle_end":
   if s.phase != "combat" or args.get("battle_id", "") != s.battle_id: return _deny("wrong_battle")
   s.phase = "safe"
   s.active_elixir.clear() # Next battle only, no invented wall clock.
   s.battle_id = ""
   return _ok([{"type":"clear_battle_elixir"}])
  "credit_reward":
   var reward: String = str(args.get("reward_id", ""))
   var gold: int = int(args.get("gold", -1))
   if reward.is_empty() or gold < 0: return _deny("invalid_reward")
   if s.effect_receipts.has(reward): return _deny("reward_already_credited")
   s.effect_receipts[reward] = {"kind":"verified_gold", "gold":gold}
   s.gold += gold
   # G04 uses the original game Model reward receipt, never this isolated credit path.
   return _ok()
  "pay_body":
   if not _trade_guard(s).is_empty(): return _deny("shop_visit_required")
   var purchase: String = str(args.get("purchase_id", ""))
   if purchase.is_empty() or s.body_receipts.has(purchase): return _deny("fresh_body_purchase_required")
   if s.gold < int(config.body_price): return _deny("insufficient_gold")
   for entry in s.inventory:
    if entry.id == "final:G05" and args.get("task_effects", []).is_empty(): return _deny("body_task_preflight_required")
   for fact in args.get("task_effects", []):
    var task_result: Dictionary = _task_effect(s, fact)
    if not task_result.accepted: return task_result
   s.gold -= int(config.body_price)
   s.body_receipts[purchase] = {"cost":config.body_price, "irreversible":true}
   # No undo record. Real 3-choice/hard-cap pool must be preflighted by the host.
   return _ok([{"type":"body_payment_committed", "purchase_id":purchase}])
  "task_effect":
   return _task_effect(s, args)
  "consume_recovery":
   return _consume_recovery(s, args)
 return _deny("unknown_authority_command")

func _trade_guard(s: Dictionary) -> String:
 if s.actor_dead: return "not_alive"
 if s.phase != "safe": return "unsafe_phase"
 if not s.shop_active or s.shop_area.is_empty(): return "shop_visit_required"
 return ""

func _buy(s: Dictionary, id: String) -> Dictionary:
 var allowed: String = _trade_guard(s)
 if not allowed.is_empty(): return _deny(allowed)
 if not config.get("items", {}).has(id): return _deny("missing_definition")
 var item: Dictionary = config.items[id]
 var kind: String = str(item.kind)
 if kind == "potion":
  if config.get("potion_slot_policy", "unresolved") not in ["legacy_same_id_stack", "per_unit_fixture"]: return _deny("unresolved_potion_slot_policy")
  if _has_kind(s, "flask"): return _deny("recovery_mutex")
  if _count(s, "potion") >= int(config.potion_cap): return _deny("potion_cap")
 if kind == "flask" and _has_kind(s, "potion"): return _deny("recovery_mutex")
 var before: Array = s.inventory.duplicate(true)
 var available: Array = s.inventory.duplicate(true)
 var consumed: Array = []
 var credit := 0
 if kind == "flask":
  for entry in available:
   if config.items[entry.id].kind != "flask": continue
   if id == entry.id: return _deny("flask_already_owned")
   if item.get("upgrade_from", "") != entry.id: return _deny("flask_upgrade_order")
   consumed.append(entry.duplicate(true))
   credit = int(config.items[entry.id].price)
  for entry in consumed: available.erase(entry)
 else:
  var recipe: Dictionary = _take_components(item.get("components", []), available, [])
  if not recipe.accepted: return recipe
  consumed = recipe.removed
  credit = recipe.credit
 var charge: int = maxi(0, int(item.price) - credit)
 if s.gold < charge: return _deny("insufficient_gold")
 var tx: int = int(s.next_tx)
 var lineage: Array = [tx]
 var invested := charge
 for entry in consumed:
  invested += int(entry.invested)
  _append_unique(lineage, entry.get("lineage", []))
 var events: Array = []
 var auto_drink := kind == "elixir" and available.size() >= int(config.slot_limit)
 if auto_drink:
  var preflight: String = _elixir_preflight(s, id)
  if not preflight.is_empty(): return _deny(preflight)
  if config.get("consumption_undo_policy", "unresolved") != "seal_lineage_candidate": return _deny("unresolved_consumption_undo_policy")
  _activate_elixir(s, id, "auto:%d" % tx)
  events.append({"type":"elixir_activated", "item":id, "effect_id":"auto:%d" % tx})
 else:
  var stacked := false
  if kind == "potion" and config.potion_slot_policy == "legacy_same_id_stack":
   for entry in available:
    if entry.id == id:
     entry.count += 1
     entry.invested += charge
     _append_unique(entry.lineage, lineage)
     stacked = true
     break
  if not stacked:
   if available.size() >= int(config.slot_limit): return _deny("inventory_full")
   available.append({"uid":s.next_uid, "id":id, "count":1, "invested":invested, "lineage":lineage})
   s.next_uid += 1
 s.inventory = available
 if kind == "flask": s.flask_entitlement = id
 s.gold -= charge
 _journal(s, before, charge, "buy", tx, auto_drink)
 if kind == "flask":
  var previous_flask := ""
  for previous_entry in before:
   if config.items[previous_entry.id].kind == "flask": previous_flask = str(previous_entry.id)
  s.undo.back()["flask_entitlement_before"] = previous_flask
 return _ok(events, {"charge":charge, "credit":credit, "auto_drink":auto_drink})

func _take_components(parts: Array, available: Array, path: Array) -> Dictionary:
 var removed: Array = []
 var credit := 0
 for part in parts:
  if not config.items.has(part): return _deny("missing_recipe_definition")
  if part in path: return _deny("recipe_cycle")
  var found := -1
  for index in range(available.size()):
   if available[index].id == part:
    found = index
    break
  if found >= 0:
   var entry: Dictionary = available[found]
   if entry.count != 1 or config.items[part].kind != "equipment": return _deny("invalid_component_entry")
   credit += int(config.items[part].price)
   removed.append(entry.duplicate(true))
   available.remove_at(found)
  else:
   var branch: Array = path.duplicate()
   branch.append(part)
   var nested: Dictionary = _take_components(config.items[part].get("components", []), available, branch)
   if not nested.accepted: return nested
   credit += int(nested.credit)
   removed.append_array(nested.removed)
 return _ok([], {"credit":credit, "removed":removed})

func _sell(s: Dictionary, uid: int) -> Dictionary:
 var index: int = _index(s.inventory, uid)
 if index < 0: return _deny("missing_item")
 var entry: Dictionary = s.inventory[index]
 if config.items[entry.id].kind == "flask": return _deny("unresolved_flask_switch_economics")
 var before: Array = s.inventory.duplicate(true)
 var refund: int = int(floor(float(entry.invested) * 0.9))
 s.inventory.remove_at(index)
 s.gold += refund
 _journal(s, before, -refund, "sell", int(s.next_tx), false)
 return _ok([], {"refund":refund})

func _journal(s: Dictionary, before: Array, gold_delta: int, action: String, tx: int, sealed: bool) -> void:
 var removed: Array = []
 var added: Array = []
 for index in range(before.size()):
  var entry: Dictionary = before[index]
  var after_index: int = _index(s.inventory, int(entry.uid))
  if after_index < 0 or s.inventory[after_index] != entry: removed.append({"index":index, "entry":entry.duplicate(true)})
 for index in range(s.inventory.size()):
  var entry: Dictionary = s.inventory[index]
  var before_index: int = _index(before, int(entry.uid))
  if before_index < 0 or before[before_index] != entry: added.append({"index":index, "entry":entry.duplicate(true)})
 s.undo.append({"tx":tx, "epoch":s.epoch, "action":action, "removed":removed, "added":added, "gold_delta":gold_delta, "sealed":sealed, "seal_reason":"already_used" if sealed else ""})
 s.next_tx += 1

func _undo(s: Dictionary) -> Dictionary:
 var index := -1
 for i in range(s.undo.size() - 1, -1, -1):
  if not s.undo[i].sealed:
   index = i
   break
 if index < 0:
  if not s.undo.is_empty(): return _deny(str(s.undo.back().seal_reason))
  return _deny("undo_boundary")
 var undo: Dictionary = s.undo[index]
 if undo.epoch != s.epoch: return _deny("undo_epoch_mismatch")
 if int(s.gold) + int(undo.gold_delta) < 0: return _deny("insufficient_gold")
 var available: Array = s.inventory.duplicate(true)
 for patch in undo.added:
  var slot: int = _index(available, int(patch.entry.uid))
  if slot < 0 or available[slot] != patch.entry: return _deny("undo_item_dependency")
  available.remove_at(slot)
 for patch in undo.removed:
  if _index(available, int(patch.entry.uid)) >= 0: return _deny("undo_duplicate_uid")
  available.insert(mini(int(patch.index), available.size()), patch.entry.duplicate(true))
 if available.size() > int(config.slot_limit): return _deny("inventory_full")
 # Deliberately do not restore body, taskLedger, consumed effects, counters or whole state.
 s.inventory = available
 # Flask entitlement tracks committed acquisition, independent of battle use counts.
 if undo.get("flask_entitlement_before", null) != null: s.flask_entitlement = undo.flask_entitlement_before
 s.gold += int(undo.gold_delta)
 s.undo.remove_at(index)
 return _ok([], {"undone_tx":undo.tx})

func _consume(s: Dictionary, uid: int) -> Dictionary:
 var index: int = _index(s.inventory, uid)
 if index < 0: return _deny("missing_item")
 var entry: Dictionary = s.inventory[index]
 var kind: String = str(config.items[entry.id].kind)
 if kind == "flask": return _deny("flask_combat_consumer_required")
 if kind not in ["potion", "elixir"]: return _deny("not_consumable")
 if kind == "elixir":
  var reason: String = _elixir_preflight(s, str(entry.id))
  if not reason.is_empty(): return _deny(reason)
 if config.get("consumption_undo_policy", "unresolved") != "seal_lineage_candidate": return _deny("unresolved_consumption_undo_policy")
 if kind == "potion": return _deny("verified_recovery_consumer_required")
 _seal_lineage(s, entry.get("lineage", []), "already_used")
 var effect_id: String = "consume:%d:%d" % [s.epoch, s.revision]
 _activate_elixir(s, str(entry.id), effect_id)
 s.inventory.remove_at(index)
 return _ok([{"type":"elixir_activated", "item":entry.id, "effect_id":effect_id}])

func _consume_recovery(s: Dictionary, args: Dictionary) -> Dictionary:
 if s.actor_dead: return _deny("not_alive")
 var index: int = _index(s.inventory, int(args.get("uid", -1)))
 if index < 0: return _deny("missing_item")
 var entry: Dictionary = s.inventory[index]
 var kind: String = str(config.items[entry.id].kind)
 if kind not in ["potion", "flask"]: return _deny("not_recovery")
 var effect_id: String = str(args.get("effect_id", ""))
 if effect_id.is_empty() or s.effect_receipts.has(effect_id): return _deny("fresh_effect_required")
 if not args.get("consumer_preflight_passed", false): return _deny("recovery_consumer_not_ready")
 if kind == "flask":
  if s.phase != "combat" or s.battle_id.is_empty(): return _deny("flask_combat_only")
  var uses: int = int(s.flask_uses_by_battle.get(s.battle_id, 0))
  if uses >= 2: return _deny("flask_exhausted")
  s.flask_uses_by_battle[s.battle_id] = uses + 1
  s.flask_charges = 2 - (uses + 1)
 else:
  if config.get("consumption_undo_policy", "unresolved") != "seal_lineage_candidate": return _deny("unresolved_consumption_undo_policy")
  _seal_lineage(s, entry.get("lineage", []), "already_used")
  entry.invested -= int(entry.invested / entry.count)
  entry.count -= 1
  if entry.count == 0: s.inventory.remove_at(index)
 s.effect_receipts[effect_id] = {"kind":"recovery_committed", "item":entry.id}
 return _ok([{"type":"recovery_committed", "item":entry.id, "effect_id":effect_id, "recovery":config.items[entry.id].recovery.duplicate(true)}])

func _elixir_preflight(s: Dictionary, id: String) -> String:
 if s.actor_dead: return "not_alive"
 if s.phase != "safe": return "elixir_prebattle_only"
 if s.active_elixir.get("item", "") == id: return "same_name_elixir_active"
 if not config.items.has(id) or config.items[id].kind != "elixir": return "not_elixir"
 return ""

func _activate_elixir(s: Dictionary, id: String, effect_id: String) -> void:
 s.active_elixir = {"item":id, "effect_id":effect_id, "battle_id":"", "duration_rule":"next_battle_only"}
 s.effect_receipts[effect_id] = {"kind":"consumed_elixir", "item":id}

func _task_effect(s: Dictionary, args: Dictionary) -> Dictionary:
 var equipment: String = str(args.get("equipment_id", ""))
 var event_id: String = str(args.get("event_id", ""))
 if not config.items.has(equipment) or config.items[equipment].kind != "equipment" or event_id.is_empty(): return _deny("invalid_task_receipt")
 var key: String = str(s.actor_id) + "|" + equipment
 var ledger: Dictionary = s.taskLedger.get(key, {"event_ids":[], "completed_stages":[], "progress":0, "permanent_rewards":{}}).duplicate(true)
 if event_id in ledger.event_ids: return _deny("task_event_already_recorded")
 var held: Array = []
 for entry in s.inventory:
  if entry.id == equipment: held.append(entry)
 if held.is_empty(): return _deny("task_equipment_not_held")
 var lineage: Array = []
 for entry in held: _append_unique(lineage, entry.get("lineage", []))
 # Non-item dependencies (for example a qualifying transaction) are explicit trusted receipts.
 for dependency in args.get("dependency_txs", []):
  var found := false
  for record in s.undo:
   if int(record.tx) == int(dependency): found = true
  if not found: return _deny("task_dependency_missing")
  if dependency not in lineage: lineage.append(dependency)
 if _has_reversible_lineage(s, lineage):
  if config.get("task_reward_undo_policy", "unresolved") != "seal_lineage_candidate": return _deny("unresolved_task_reward_undo_policy")
  _seal_lineage(s, lineage, "reward_already_claimed")
 # This is a receipt import boundary, not a task adjudicator or a reward grant command.
 # Caller supplies only a verified monotonic result from the run's actual task authority.
 var progress: int = int(args.get("progress", -1))
 if progress < int(ledger.progress): return _deny("task_progress_must_not_rewind")
 var stage: String = str(args.get("stage", ""))
 if not stage.is_empty() and stage in ledger.completed_stages: return _deny("task_stage_already_complete")
 ledger.progress = progress
 ledger.event_ids.append(event_id)
 if not stage.is_empty(): ledger.completed_stages.append(stage)
 var reward_key: String = str(args.get("reward_key", ""))
 if not reward_key.is_empty():
  if ledger.permanent_rewards.has(reward_key): return _deny("task_reward_already_recorded")
  ledger.permanent_rewards[reward_key] = event_id
 s.taskLedger[key] = ledger
 return _ok()

func _has_reversible_lineage(s: Dictionary, lineage: Array) -> bool:
 for record in s.undo:
  if not record.sealed and int(record.tx) in lineage: return true
 return false

func _seal_lineage(s: Dictionary, lineage: Array, reason: String) -> void:
 for record in s.undo:
  if int(record.tx) in lineage:
   record.sealed = true
   record.seal_reason = reason

func _commit_visit(s: Dictionary) -> void:
 s.undo.clear()
 s.epoch += 1
 s.shop_active = false
 s.shop_area = ""
 s.ui_open = false

func _count(s: Dictionary, kind: String) -> int:
 var count := 0
 for entry in s.inventory:
  if config.items[entry.id].kind == kind: count += int(entry.count)
 return count

func _has_kind(s: Dictionary, kind: String) -> bool:
 return _count(s, kind) > 0

func _index(entries: Array, uid: int) -> int:
 for index in range(entries.size()):
  if int(entries[index].uid) == uid: return index
 return -1

func _append_unique(target: Array, values: Array) -> void:
 for value in values:
  if value not in target: target.append(value)

func _ok(events: Array = [], extra: Dictionary = {}) -> Dictionary:
 var result: Dictionary = {"accepted":true, "reason":"", "events":events}
 result.merge(extra)
 return result

func _deny(reason: String) -> Dictionary:
 var labels: Dictionary = {"already_used":"已使用，不能撤回该消费及其依赖交易", "reward_already_claimed":"奖励已领取，不能撤回该奖励的依赖交易", "same_name_elixir_active":"同名合剂效果已生效，不能再次饮用", "unresolved_potion_slot_policy":"药品占槽粒度尚未配置", "unresolved_flask_switch_economics":"药壶恢复方案切换的经济规则尚未配置", "stale_epoch":"商店访问已变更，请刷新", "stale_revision":"交易状态已变更，请刷新", "inventory_full":"六个装备槽已满", "insufficient_gold":"金币不足", "undo_boundary":"本次商店访问没有可撤回交易"}
 return {"accepted":false, "reason":reason, "reason_text":labels.get(reason, reason), "changed":false, "events":[]}
