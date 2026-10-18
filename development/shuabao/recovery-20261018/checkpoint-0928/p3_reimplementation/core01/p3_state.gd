extends RefCounted
# REIMPLEMENTATION, not recovery of the lost 401895aa artifact.
# Pure rule state. The Sim must authenticate successful Q/E commits before calling.
const Tuning = preload("res://tests/ink_q1_foundation_20261004/revision02/scripts/ink_tuning.gd")
var rank: int = 0
var counts: Dictionary = {"q": 0, "e": 0}
var ready: Dictionary = {"q": false, "e": false}
var epoch: int = 0
var release_serial: int = 0
var cd_reset_serial: Dictionary = {"q": 0, "e": 0}
var _seen: Dictionary = {}
var _journal: Array = []
var _next_transaction: int = 0

func snapshot() -> Dictionary:
 return {"rank": rank, "counts": counts.duplicate(), "ready": ready.duplicate(), "epoch": epoch, "release_serial": release_serial, "cd_reset_serial": cd_reset_serial.duplicate()}

func threshold() -> int:
 return int(Tuning.parameter("P3-1", rank)) if rank > 0 else 0

func reset(new_rank: int = 0) -> void:
 rank = clampi(new_rank, 0, 4)
 counts = {"q": 0, "e": 0}
 ready = {"q": false, "e": false}
 epoch += 1
 _seen.clear()
 _journal.clear()

# Called only after an actual original cooldown reset, not inferred from CD equality.
# Cross-room transitions do not call reset; rest calls this barrier, retaining progress.
func cooldown_reset(slots: Array = ["q", "e"]) -> void:
 for slot in slots:
  if cd_reset_serial.has(slot):
   cd_reset_serial[slot] += 1

func _settle(slot: String, cooldowns: Dictionary) -> Dictionary:
 var before: float = maxf(0.0, float(cooldowns.get(slot, 0.0)))
 var refunded: float = 0.0
 if ready[slot] and before > 0.0:
  refunded = before * Tuning.fraction("P3-2", rank)
  cooldowns[slot] = maxf(0.0, before - refunded)
  counts[slot] = 0
  ready[slot] = false
 return {"before": before, "after": maxf(0.0, before - refunded), "refunded": refunded, "pending": ready[slot]}

func release(slot: String, identity: String, cooldowns: Dictionary) -> Dictionary:
 if rank <= 0 or not counts.has(slot) or identity.is_empty() or _seen.has(identity):
  return {"accepted": false, "reason": "inactive_invalid_or_duplicate"}
 _seen[identity] = true
 release_serial += 1
 if not ready[slot]:
  counts[slot] = mini(int(counts[slot]) + 1, threshold())
  ready[slot] = int(counts[slot]) >= threshold()
 var cd: Dictionary = _settle(slot, cooldowns)
 return {"accepted": true, "slot": slot, "identity": identity, "cd": cd, "state": snapshot()}

# Original Model owns fees, allocations, deduplication and permission to call this.
# Same-rank projection is deliberately inert and does not mint a transaction.
func upgrade(new_rank: int, cooldowns: Dictionary) -> Dictionary:
 if new_rank == rank:
  return {"accepted": true, "changed": false}
 if new_rank != rank + 1 or new_rank > 4:
  return {"accepted": false, "reason": "not_next_rank"}
 var before: Dictionary = snapshot()
 rank = new_rank
 var refunds: Dictionary = {"q": 0.0, "e": 0.0}
 for slot in ["q", "e"]:
  if int(counts[slot]) >= threshold():
   counts[slot] = threshold()
   ready[slot] = true
  refunds[slot] = _settle(slot, cooldowns).refunded
 _next_transaction += 1
 _journal.append({"id": _next_transaction, "before": before, "rank_after": rank, "refunds": refunds})
 return {"accepted": true, "changed": true, "transaction": _next_transaction, "state": snapshot()}

func undo_upgrade(transaction: int, cooldowns: Dictionary) -> Dictionary:
 if _journal.is_empty():
  return {"accepted": false, "reason": "no_transaction"}
 var entry: Dictionary = _journal.back()
 var before: Dictionary = entry.before
 if entry.id != transaction or rank != entry.rank_after or epoch != before.epoch or release_serial != before.release_serial:
  return {"accepted": false, "reason": "stale_or_not_lifo"}
 _journal.pop_back()
 rank = int(before.rank)
 counts = before.counts.duplicate()
 ready = before.ready.duplicate()
 for slot in ["q", "e"]:
  if cd_reset_serial[slot] == before.cd_reset_serial[slot]:
   cooldowns[slot] = maxf(0.0, float(cooldowns.get(slot, 0.0))) + float(entry.refunds[slot])
 return {"accepted": true, "state": snapshot()}
