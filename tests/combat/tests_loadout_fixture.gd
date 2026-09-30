extends RefCounted
# Relative preload keeps this suite portable when both files share a directory.
const Ledger = preload("res://scripts/combat/loadout_fixture.gd")
var _checks := 0
var _failures: Array[String] = []

func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)

func run() -> Dictionary:
	_checks = 0
	_failures.clear()
	var ledger = Ledger.new()
	_check(ledger.snapshot().available == 1, "level 1 grants exactly one point")
	_check(not ledger.invest("R", "R1").ok, "R cannot be learned before level 6")
	_check(ledger.invest("Q", "Q1").ok, "Q works with all other slots empty")
	_check(not ledger.invest("E", "E3").ok, "no overspend at level 1")
	_check(not ledger.invest("Q", "Q2").ok, "mutually exclusive choices")
	_check(not ledger.invest("X", "Q1").ok, "unknown slot rejected")
	_check(not ledger.invest("Q", "E1").ok, "cross slot candidate rejected")
	_check(not ledger.set_level(19).ok, "level above 18 rejected")
	_check(not ledger.set_level(0).ok, "level below 1 rejected")
	ledger.set_level(18)
	for index in range(4):
		_check(ledger.invest("Q", "Q1").ok, "Q numerical rank %d" % (index + 2))
	for index in range(5):
		_check(ledger.invest("E", "E3").ok, "E numerical rank %d" % (index + 1))
	for index in range(3):
		_check(ledger.invest("R", "R1").ok, "R rank %d" % (index + 1))
	for index in range(3):
		_check(ledger.invest("P", "P3").ok, "P rank %d" % (index + 1))
	_check(ledger.snapshot().spent == 18 and ledger.snapshot().available == 0, "5+5+5+3 exactly 18")
	_check(not ledger.invest("Q", "Q1").ok, "Q max rank")
	_check(not ledger.invest("R", "R1").ok, "R max rank")
	_check(not ledger.invest("P", "P3").ok, "P max rank")
	_check(not ledger.set_level(17).ok, "no level rollback or refund exploit")
	var copied: Dictionary = ledger.snapshot()
	copied.slots.Q.rank = 0
	copied.r_level_gates[0] = 1
	_check(ledger.snapshot().slots.Q.rank == 5 and ledger.snapshot().r_level_gates[0] == 6, "snapshot cannot mutate ledger")
	_check(ledger.undo_last_investment().ok and ledger.snapshot().available == 1, "new points can be undone")
	ledger.begin_encounter()
	_check(not ledger.undo_last_investment().ok, "combat rejects refund")
	_check(ledger.invest("P", "P3").ok, "combat permits upgrade without pausing")
	_check(ledger.snapshot().in_combat, "invest does not end combat")
	_check(not ledger.set_training_node(true).ok, "cannot enter training during combat")
	_check(not ledger.reset_at_training().ok, "combat cannot respec")
	_check(not ledger.begin_encounter().ok, "repeated begin does not commit new combat points")
	ledger.end_encounter()
	_check(ledger.undo_last_investment().ok, "combat investment refundable before next encounter")
	_check(not ledger.undo_last_investment().ok, "old committed point cannot be undone")
	_check(not ledger.reset_at_training().ok, "old skills require training")
	ledger.set_training_node(true)
	_check(ledger.reset_at_training().ok and ledger.snapshot().available == 18, "training refunds point ledger only")
	for slot: String in Ledger.CANDIDATES:
		for skill: String in Ledger.CANDIDATES[slot]:
			ledger.reset_at_training()
			_check(ledger.invest(slot, skill).ok, "standalone candidate " + skill)
	var gated = Ledger.new(9, 13)
	gated.set_level(6)
	_check(gated.invest("R", "R2").ok and gated.spent_points() == 1, "R initial rank at 6 costs 1")
	_check(not gated.invest("R", "R2").ok, "configurable second rank gate")
	gated.set_level(9)
	_check(gated.invest("R", "R2").ok and gated.spent_points() == 3, "second R costs 2")
	_check(not gated.invest("R", "R2").ok, "configurable third rank gate")
	gated.set_level(13)
	_check(gated.invest("R", "R2").ok and gated.spent_points() == 5, "third R costs 2")
	gated.undo_last_investment()
	_check(gated.spent_points() == 3, "R undo restores full 2 points")
	var invalid_config = Ledger.new(1, 2)
	_check(invalid_config.snapshot().r_level_gates == [6, 10, 14], "invalid gate config falls back to test defaults")
	var boundary = Ledger.new()
	boundary.set_level(2)
	boundary.invest("P", "P1")
	boundary.begin_encounter()
	boundary.end_encounter()
	_check(not boundary.undo_last_investment().ok, "next encounter commits precombat allocation")
	boundary.invest("P", "P1")
	boundary.undo_last_investment()
	_check(boundary.snapshot().slots.P.rank == 1, "undo upgrade preserves old rank")
	return {"suite": "combat_loadout_fixture", "passed": _failures.is_empty(), "checks": _checks, "failures": _failures.duplicate()}
