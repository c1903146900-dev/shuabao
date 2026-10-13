extends RefCounted
## TEST FIXTURE ONLY. Frozen kernel is a disposable evaluator, never a second wallet.
const Kernel = preload("res://tests/equipment_shop_transactions_20261004/shop_visit_model.gd")
const AUTHORITY_FIELDS = ["gold", "inventory", "next_uid", "revision", "phase", "actor_dead", "actor_id", "hero_id"]

static func initial_metadata(run_id: String, actor_id: String) -> Dictionary:
 var evaluator = Kernel.new({}, null, run_id, actor_id)
 var metadata: Dictionary = evaluator.snapshot()
 for field in AUTHORITY_FIELDS: metadata.erase(field)
 return metadata

static func project(ledger_state: Dictionary) -> Dictionary:
 var draft: Dictionary = ledger_state.shop_visit.duplicate(true)
 draft.merge({"gold":ledger_state.gold, "inventory":ledger_state.inventory.duplicate(true), "next_uid":ledger_state.next_item, "revision":ledger_state.revision, "phase":ledger_state.phase, "actor_dead":ledger_state.get("actor_dead", false), "actor_id":ledger_state.actor_id, "hero_id":ledger_state.hero_id}, true)
 return draft

static func evaluate(ledger_state: Dictionary, definitions: Dictionary, action: String, args: Dictionary, trusted: bool) -> Dictionary:
 var draft: Dictionary = project(ledger_state)
 var before: Dictionary = draft.duplicate(true)
 var evaluator = Kernel.new(definitions)
 # Deliberately no evaluator.command(), receipts or retained evaluator.state.
 var result: Dictionary = evaluator._apply(draft, action, args, trusted)
 if not result.accepted: return result
 var remove: Array = []
 var add: Array = []
 for index in range(before.inventory.size()):
  var entry: Dictionary = before.inventory[index]
  var after_index: int = _index(draft.inventory, int(entry.uid))
  if after_index < 0 or draft.inventory[after_index] != entry: remove.append({"index":index, "entry":entry.duplicate(true)})
 for index in range(draft.inventory.size()):
  var entry: Dictionary = draft.inventory[index]
  var before_index: int = _index(before.inventory, int(entry.uid))
  if before_index < 0 or before.inventory[before_index] != entry: add.append({"index":index, "entry":entry.duplicate(true)})
 var metadata: Dictionary = draft.duplicate(true)
 for field in AUTHORITY_FIELDS: metadata.erase(field)
 result["patch"] = {"revision":ledger_state.revision, "next_item_before":ledger_state.next_item, "metadata_before":ledger_state.shop_visit.duplicate(true), "gold_before":ledger_state.gold, "gold_delta":int(draft.gold)-int(before.gold), "removed":remove, "added":add, "next_item":draft.next_uid, "metadata":metadata}
 return result

static func commit(ledger_state: Dictionary, patch: Dictionary, slot_limit: int, debit_already_applied: bool = false) -> String:
 if ledger_state.revision != patch.revision: return "stale_ledger_revision"
 if ledger_state.next_item != patch.next_item_before: return "stale_item_sequence"
 if ledger_state.shop_visit != patch.metadata_before: return "stale_visit_metadata"
 var expected_gold: int = int(patch.gold_before) + (int(patch.gold_delta) if debit_already_applied else 0)
 if ledger_state.gold != expected_gold: return "ledger_currency_precondition"
 var gold: int = int(patch.gold_before) + int(patch.gold_delta)
 if gold < 0: return "insufficient_gold"
 var inventory: Array = ledger_state.inventory.duplicate(true)
 for removed in patch.removed:
  var slot: int = _index(inventory, int(removed.entry.uid))
  if slot < 0 or inventory[slot] != removed.entry: return "ledger_item_precondition"
  inventory.remove_at(slot)
 for added in patch.added:
  if _index(inventory, int(added.entry.uid)) >= 0: return "ledger_duplicate_uid"
  inventory.insert(mini(int(added.index), inventory.size()), added.entry.duplicate(true))
 if inventory.size() > slot_limit: return "inventory_full"
 # This is the complete economic write set. No full-player snapshot restore.
 if not debit_already_applied: ledger_state.gold = gold
 ledger_state.inventory = inventory
 ledger_state.next_item = patch.next_item
 ledger_state.shop_visit = patch.metadata.duplicate(true)
 return ""

static func _index(inventory: Array, uid: int) -> int:
 for index in range(inventory.size()):
  if int(inventory[index].uid) == uid: return index
 return -1
