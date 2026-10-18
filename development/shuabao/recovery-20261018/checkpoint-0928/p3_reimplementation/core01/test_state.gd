extends RefCounted
# Wrapper must inspect accepted/checks/failures and exit nonzero on failure.
const State = preload("res://yan_p3_reimplementation_20261018b/p3_state.gd")
var checks: int = 0
var failures: Array = []

func check(condition: bool, label: String) -> void:
 checks += 1
 if not condition:
  failures.append(label)

func casts(s, cd: Dictionary, amount: int, prefix: String, slot: String = "q") -> void:
 for i in range(amount):
  s.release(slot, prefix + str(i), cd)

func run() -> Dictionary:
 checks = 0
 failures = []
 var s = State.new()
 var cd: Dictionary = {"q": 10.0, "e": 8.0}
 check(not s.release("q", "inactive", cd).accepted, "01 inactive rejects")
 var learned: Dictionary = s.upgrade(1, cd)
 check(learned.accepted and s.rank == 1 and s.counts.q == 0, "02 learn clean")
 s.release("q", "a", cd)
 check(s.counts.q == 1 and s.counts.e == 0, "03 Q independent")
 check(not s.release("q", "a", cd).accepted and s.counts.q == 1, "04 repeated receipt rejected")
 check(not s.release("r", "r", cd).accepted and not s.release("q", "", cd).accepted, "05 R and empty invalid")
 s.release("e", "e", cd)
 check(s.counts.e == 1 and s.counts.q == 1, "06 E independent")
 casts(s, cd, 3, "b")
 check(is_equal_approx(cd.q, 4.0) and s.counts.q == 0 and not s.ready.q, "07 fourth refunds 60 percent remaining")
 var before: Dictionary = s.snapshot()
 # A room transition has no core mutation; caller preserves this same object.
 check(s.snapshot() == before, "08 cross-room preserve contract")
 s.cooldown_reset()
 cd = {"q": 0.0, "e": 0.0}
 check(s.counts.e == 1 and s.cd_reset_serial.q == 1, "09 rest reset barrier preserves count")
 s.reset(1)
 casts(s, cd, 4, "zero")
 check(s.ready.q and s.counts.q == 4 and cd.q == 0.0, "10 zero CD holds ready")
 cd.q = 10.0
 s.release("q", "next", cd)
 check(is_equal_approx(cd.q, 4.0) and s.counts.q == 0 and not s.ready.q, "11 next success consumes without overflow")
 s.reset(3)
 cd = {"q": 9.0, "e": 0.0}
 casts(s, cd, 3, "upgrade")
 var u: Dictionary = s.upgrade(4, cd)
 check(cd.q == 0.0 and s.counts.q == 0, "12 reduced threshold immediate 100 percent")
 check(s.undo_upgrade(u.transaction, cd).accepted and cd.q == 9.0 and s.rank == 3 and s.counts.q == 3, "13 undo only own refund")
 cd.q = 0.0
 u = s.upgrade(4, cd)
 check(s.ready.q and s.undo_upgrade(u.transaction, cd).accepted and s.counts.q == 3 and not s.ready.q, "14 zero-CD upgrade undo")
 cd.q = 9.0
 u = s.upgrade(4, cd)
 s.cooldown_reset()
 cd.q = 0.0
 check(s.undo_upgrade(u.transaction, cd).accepted and cd.q == 0.0 and s.counts.q == 3, "15 rest then undo cannot revive cooldown")
 s.reset(1)
 var u2: Dictionary = s.upgrade(2, cd)
 var u3: Dictionary = s.upgrade(3, cd)
 check(not s.undo_upgrade(u2.transaction, cd).accepted and s.undo_upgrade(u3.transaction, cd).accepted and s.undo_upgrade(u2.transaction, cd).accepted and s.rank == 1, "16 consecutive upgrades LIFO")
 u2 = s.upgrade(2, cd)
 s.release("q", "after_upgrade", cd)
 check(not s.undo_upgrade(u2.transaction, cd).accepted, "17 release invalidates old inverse")
 s.reset(0)
 check(s.rank == 0 and s.counts.q == 0 and not s.ready.q and not s.undo_upgrade(u2.transaction, cd).accepted, "18 death/passive reset clears and invalidates")
 learned = s.upgrade(1, cd)
 var serial: int = s.release_serial
 check(not s.upgrade(1, cd).changed and s.release_serial == serial and s.undo_upgrade(learned.transaction, cd).accepted and s.rank == 0, "19 same-rank inert and learning undo")
 return {"accepted": failures.is_empty() and checks == 19, "checks": checks, "failures": failures.duplicate()}
