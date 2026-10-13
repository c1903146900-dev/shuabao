extends RefCounted
## Resolved P2 state successor: six complete-use families on the current E3 chain.
const T = preload("res://tests/ink_q1_foundation_20261004/revision02/scripts/ink_tuning.gd")
const FAMILIES: Array = ["q1", "q2", "q3", "e1", "e2", "e3"]
const MILESTONES: Dictionary = {"q1":"successful_line_release", "q2":"successful_second_point_completion", "q3":"accepted_mountain_start", "e1":"accepted_rain_start", "e2":"accepted_boat_launch", "e3":"successful_second_frame_completion"}

var owner = null
var generation: int = -1
var room_id: String = ""
var rank: int = 0
var stacks: int = 0
var expires_at: float = 0.0
var last_family: String = ""
var use_serial: int = 0
var epoch_serial: int = 0
var ready_epoch: int = 0
var ready_use: int = 0
var ready_root: int = 0
var uses: Dictionary = {}

func bind_empty(next_owner, next_generation: int, next_room: String, next_rank: int) -> Dictionary:
 if owner != null: return _reject("already_bound_use_scope_retirement")
 if next_owner == null or next_generation < 0 or next_room.is_empty() or next_rank < 1 or next_rank > 4: return _reject("invalid_binding")
 owner = next_owner
 generation = next_generation
 room_id = next_room
 rank = next_rank
 return {"status":"OK"}

func current(candidate_owner, candidate_generation: int, candidate_room: String) -> bool:
 return owner != null and is_same(owner, candidate_owner) and generation == candidate_generation and room_id == candidate_room

func observe_time(now: float) -> Dictionary:
 if not is_finite(now) or now < 0.0: return _reject("invalid_hero_time")
 if stacks > 0 and now >= expires_at:
  # User-approved expiry retires the numerical buff and every old entitlement,
  # retaining the last completed skill for the next alternation comparison.
  _clear_buff()
 return {"status":"OK"}

func check_rank(next_rank: int) -> Dictionary:
 if owner == null or next_rank < 1 or next_rank > 4: return _reject("invalid_rank_binding")
 if next_rank < rank: return _reject("rank_reduction_requires_scope_retirement")
 # Approved live upgrades change factors, never stacks, ready order or expiry.
 rank = next_rank
 return {"status":"OK"}

func complete_use(context: Dictionary, candidate_owner, family: String, milestone: String, next_rank: int, now: float) -> Dictionary:
 if not current(candidate_owner, int(context.get("generation", -1)), str(context.get("room_id", ""))): return _reject("stale_scope")
 if family not in FAMILIES or str(context.get("candidate", "")) != family: return _reject("ineligible_family")
 if str(context.get("slot", "")) != ("q" if family.begins_with("q") else "e") or milestone != str(MILESTONES[family]): return _reject("not_complete_use")
 var id: int = int(context.get("cast_id", 0))
 if id <= 0: return _reject("missing_root")
 if uses.has(id): return _reject("root_already_counted")
 if not is_finite(now) or now < 0.0: return _reject("invalid_hero_time")
 var rank_check: Dictionary = check_rank(next_rank)
 if rank_check.status != "OK": return rank_check
 var clock_check: Dictionary = observe_time(now)
 if clock_check.status != "OK": return clock_check
 var alternating: bool = not last_family.is_empty() and last_family != family
 # Entitlement snapshots the PRE-use epoch. Root birth order is irrelevant.
 var entitled_epoch: int = ready_epoch
 var stacks_before: int = stacks
 use_serial += 1
 var record: Dictionary = {"cast_id":id, "family":family, "milestone":milestone, "use_serial":use_serial, "used_at":now, "consume_epoch":entitled_epoch, "cancelled":false}
 uses[id] = record
 last_family = family
 if alternating:
  # Capped alternation refreshes five seconds but preserves the original ready
  # epoch/cutoff; this new use keeps the entitlement captured above.
  stacks = mini(int(T.parameter("P2-2", rank)), stacks + int(T.parameter("P2-1", rank)))
  expires_at = now + T.parameter("P2-3", rank)
  if stacks == int(T.parameter("P2-2", rank)) and ready_epoch == 0:
   epoch_serial += 1
   ready_epoch = epoch_serial
   ready_use = use_serial
   ready_root = id
 return {"status":"OK", "use":record.duplicate(true), "stacks":stacks, "expires_at":expires_at, "ready_epoch":ready_epoch, "added":stacks > stacks_before, "added_stacks":stacks - stacks_before, "refreshed":alternating}

func projection(next_rank: int, now: float) -> Dictionary:
 if not is_finite(now) or now < 0.0: return _reject("invalid_hero_time")
 var rank_check: Dictionary = check_rank(next_rank)
 if rank_check.status != "OK": return rank_check
 var clock_check: Dictionary = observe_time(now)
 if clock_check.status != "OK": return clock_check
 return {"status":"OK", "ap_fraction":stacks * T.fraction("P2-4", rank), "speed_fraction":stacks * T.fraction("P2-5", rank)}

func packet_entitled(id: int, family: String) -> bool:
 if ready_epoch == 0 or not uses.has(id): return false
 var record: Dictionary = uses[id]
 return not bool(record.cancelled) and str(record.family) == family and int(record.consume_epoch) == ready_epoch and int(record.use_serial) > ready_use

func claim_positive(id: int, family: String, packet_serial: int, actual: float, position: Vector3, ap_before_clear: float, now: float) -> Dictionary:
 var clock_check: Dictionary = observe_time(now)
 if clock_check.status != "OK": return clock_check
 if not is_finite(actual) or actual <= 0.0 or not position.is_finite() or not is_finite(ap_before_clear) or packet_serial <= 0: return _reject("not_positive_committed_damage")
 if not packet_entitled(id, family): return _reject("no_current_ready_entitlement")
 var receipt: Dictionary = {"status":"CLAIMED", "generation":generation, "room_id":room_id, "cast_id":id, "family":family, "use_serial":int(uses[id].use_serial), "ready_epoch":ready_epoch, "ready_use":ready_use, "ready_root":ready_root, "packet_serial":packet_serial, "committed_at":now, "actual_original":actual, "position":position, "passive_rank":rank, "stacks_consumed":stacks, "ap_before_clear":ap_before_clear}
 # Claim and invalidation are synchronous and precede all external callbacks.
 _clear_buff()
 # Consumption retains last_family; only scope retirement clears history.
 return receipt

func cancel_root(id: int) -> void:
 if not uses.has(id): return
 # Keep the tombstone: cancelled/finished old effects cannot complete use again.
 uses[id].cancelled = true
 uses[id].consume_epoch = 0

func _clear_buff() -> void:
 stacks = 0
 expires_at = 0.0
 ready_epoch = 0
 ready_use = 0
 ready_root = 0
 for id in uses: uses[id].consume_epoch = 0

func retire_scope() -> void:
 # Rest, room, death, owner/passive replacement: no historical entitlement.
 _clear_buff()
 uses.clear()
 last_family = ""
 owner = null
 generation = -1
 room_id = ""
 rank = 0
 use_serial = 0
 epoch_serial = 0

func _reject(reason: String) -> Dictionary:
 return {"status":"REJECTED", "reason":reason}
