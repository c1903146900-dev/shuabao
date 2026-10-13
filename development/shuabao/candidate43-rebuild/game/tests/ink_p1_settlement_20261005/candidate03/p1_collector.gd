extends RefCounted
## Whole-root bookkeeping only. Amounts come from the real committed damage event.
## Dictionary identity, not actor_id equality, defines distinct enemy instances.
var roots: Dictionary = {}

func begin(context: Dictionary, owner, rank: int, bonus: float, refund: float) -> void:
 var id: int = int(context.cast_id)
 if roots.has(id): return
 roots[id] = {"context":context.duplicate(true), "owner":owner, "rank":rank, "bonus":bonus, "refund":refund, "targets":[], "packets":{}, "depth":0, "complete":false, "settled":false}

func enter(id: int) -> void:
 if roots.has(id): roots[id].depth = int(roots[id].depth) + 1

func leave(id: int) -> void:
 if roots.has(id): roots[id].depth = maxi(0, int(roots[id].depth) - 1)

func capture(id: int, packet_id: int, enemy: Dictionary, actual: float) -> void:
 if not roots.has(id) or not is_finite(actual) or actual < 0.0: return
 var state: Dictionary = roots[id]
 if bool(state.settled) or state.packets.has(packet_id): return
 state.packets[packet_id] = true
 for target in state.targets:
  if is_same(target.enemy, enemy):
   target.actual = float(target.actual) + actual
   return
 state.targets.append({"enemy":enemy, "actor_id":str(enemy.actor_id), "actual":actual})

func complete(id: int) -> void:
 if roots.has(id): roots[id].complete = true

func ready(id: int) -> bool:
 return roots.has(id) and bool(roots[id].complete) and not bool(roots[id].settled) and int(roots[id].depth) == 0

func take(id: int) -> Dictionary:
 if not ready(id): return {}
 var state: Dictionary = roots[id]
 # Claim BEFORE any HP/CD write or user-visible callback. A duplicate completion
 # cannot collect its own supplement or pay the same root again.
 state.settled = true
 return state

func cancel(id: int) -> void:
 roots.erase(id)

func clear() -> void:
 roots.clear()
