extends RefCounted
## TEST FIXTURE ONLY. Replace with feature/progression adapter at integration.
## No XP, rewards, inventory, shop, hex or authoritative production progression.
## R ranks 2/3 level gates 10/14 are TEST DEFAULTS, not approved design values.
signal ledger_changed(snapshot: Dictionary)

const MAX_LEVEL := 18
const CANDIDATES := {"Q": ["Q1", "Q2", "Q3"], "E": ["E1", "E2", "E3"], "R": ["R1", "R2"], "P": ["P1", "P2", "P3"]}
const COSTS := {"Q": [1, 1, 1, 1, 1], "E": [1, 1, 1, 1, 1], "R": [1, 2, 2], "P": [1, 1, 1]}
var _level := 1
var _combat := false
var _training_node := false
var _slots := {"Q": {"skill": "", "rank": 0}, "E": {"skill": "", "rank": 0}, "R": {"skill": "", "rank": 0}, "P": {"skill": "", "rank": 0}}
var _pending: Array[Dictionary] = []
var _r_gates: Array[int] = [6, 10, 14]

func _init(r_second_gate: int = 10, r_third_gate: int = 14) -> void:
	# Reject invalid custom gates by falling back to documented test defaults.
	if r_second_gate >= 6 and r_third_gate >= r_second_gate and r_third_gate <= MAX_LEVEL:
		_r_gates = [6, r_second_gate, r_third_gate]

func snapshot() -> Dictionary:
	return {"level": _level, "earned": _level, "spent": spent_points(), "available": _level - spent_points(), "slots": _slots.duplicate(true), "in_combat": _combat, "at_training_node": _training_node, "refundable_transactions": _pending.size(), "r_level_gates": _r_gates.duplicate(), "r_upper_gates_are_test_values": true}

func spent_points() -> int:
	var spent := 0
	for slot: String in _slots:
		for index: int in range(int(_slots[slot].rank)):
			spent += int(COSTS[slot][index])
	return spent

func set_level(new_level: int) -> Dictionary:
	if new_level < _level or new_level > MAX_LEVEL:
		return _reject("level_must_increase_within_1_to_18")
	_level = new_level
	return _changed()

func invest(slot: String, skill: String) -> Dictionary:
	if not CANDIDATES.has(slot) or not skill in CANDIDATES[slot]:
		return _reject("invalid_slot_or_skill")
	var current: Dictionary = _slots[slot]
	if current.skill != "" and current.skill != skill:
		return _reject("slot_choice_is_exclusive")
	var rank: int = int(current.rank)
	if rank >= COSTS[slot].size():
		return _reject("maximum_rank")
	if slot == "R" and _level < _r_gates[rank]:
		return _reject("r_level_gate")
	var cost := int(COSTS[slot][rank])
	if _level - spent_points() < cost:
		return _reject("insufficient_points")
	_pending.append({"slot": slot, "previous": current.duplicate(true), "cost": cost})
	_slots[slot] = {"skill": skill, "rank": rank + 1}
	return _changed()

func begin_encounter() -> Dictionary:
	if _combat:
		return _reject("already_in_combat")
	# Earlier investments commit when the next encounter starts. Investments
	# made during this encounter remain refundable after it, until the next.
	_pending.clear()
	_combat = true
	_training_node = false
	return _changed()

func end_encounter() -> Dictionary:
	if not _combat:
		return _reject("not_in_combat")
	_combat = false
	return _changed()

func undo_last_investment() -> Dictionary:
	if _combat:
		return _reject("cannot_undo_in_combat")
	if _pending.is_empty():
		return _reject("no_new_investment_to_undo")
	var transaction: Dictionary = _pending.pop_back()
	_slots[transaction.slot] = transaction.previous.duplicate(true)
	return _changed()

func set_training_node(present: bool) -> Dictionary:
	if _combat:
		return _reject("cannot_enter_training_in_combat")
	_training_node = present
	return _changed()

func reset_at_training() -> Dictionary:
	if _combat or not _training_node:
		return _reject("training_node_required")
	for slot: String in _slots:
		_slots[slot] = {"skill": "", "rank": 0}
	_pending.clear()
	return _changed()

func _changed() -> Dictionary:
	var state := snapshot()
	ledger_changed.emit(state.duplicate(true))
	return {"ok": true, "state": state}

func _reject(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "state": snapshot()}
