extends "res://tests/ink_e2_ordinary_20261005/candidate01/sim.gd"
## Narrow successor for actual same-frame resume -> E remainder loss.
## Ordinary E2 stays locked. No parent E1/Q2/core or normal no-backlog E change.
var _e2_pending_board_input: Dictionary = {}
var _e2_board_input_serial: int = 0
var _e2_board_input_receipts: Array = []
var _e2_draining_local: bool = false

func _e2_has_local_work() -> bool:
 return not _e2_pending_sweep.is_empty() or not _e2_pending_burst.is_empty() or not _e2_pending_motion.is_empty() or not _e2_pending_terminal.is_empty()

func _request_action(action: String, aim: Vector3) -> Dictionary:
 if hero.loadout.e=="e2" and action in ["e","ink_e_down"] and not _e2_draining_local:
  if not _e2_pending_board_input.is_empty():
   return {"accepted":false,"reason":"boat_boarding_input_already_queued","consumed":true,"boarding_input_id":_e2_pending_board_input.input_id}
  if phase=="combat" and not paused and _e2_live(ink_boat) and ink_boat.phase=="outward" and _e2_has_local_work():
   # Accept only the input intent here. Old packets must not be dispatched
   # inside this request_action transaction: their callbacks retain the normal
   # original reentrant action path when the local remainder later drains.
   _e2_board_input_serial += 1
   var owned: Dictionary = {"input_id":"e2-remainder-board:%d:%s:%d" % [encounter_generation,room_id,_e2_board_input_serial],"state":ink_boat,"cast_id":int(ink_boat.cast_id),"room_id":room_id,"generation":encounter_generation,"owner":hero,"requested_at":hero_time,"aim":aim}
   _e2_pending_board_input = owned
   var result: Dictionary = {"accepted":true,"reason":"boat_boarding_queued_behind_admitted_contacts","queued":true,"consumed":true,"cast_id":owned.cast_id,"boarding_input_id":owned.input_id,"state_revision":revision}
   _e2_record_board_input(owned,"queued",result)
   return result
 return super._request_action(action,aim)

func _e2_resume_local() -> void:
 var prior: bool = _e2_draining_local
 _e2_draining_local = true
 super._e2_resume_local()
 _e2_draining_local = prior

func _fixed_step(real_dt: float) -> void:
 if _e2_pending_board_input.is_empty():
  super._fixed_step(real_dt)
  return
 if paused: return
 var scope: Dictionary = _ink_scope()
 _e2_resume_local()
 if not _ink_scope_current(scope) or hero.dead: return
 if paused:
  real_accumulator += real_dt
  return
 _e2_resolve_pending_board()
 if not _ink_scope_current(scope) or hero.dead: return
 if paused:
  real_accumulator += real_dt
  return
 # The base finds no repeated E2 work, then runs its unchanged Q2 remainder
 # and the single inherited new world/core step. No clock is stepped above.
 super._fixed_step(real_dt)

func _e2_board_input_current(owned: Dictionary) -> bool:
 return not owned.is_empty() and phase=="combat" and not hero.dead and hero.loadout.e=="e2" and is_same(hero,owned.owner) and int(owned.generation)==encounter_generation and str(owned.room_id)==room_id and _e2_live(owned.state) and int(owned.cast_id)==int(ink_boat.cast_id) and ink_boat.phase=="outward"

func _e2_resolve_pending_board() -> void:
 if _e2_pending_board_input.is_empty() or paused or _e2_has_local_work(): return
 var owned: Dictionary = _e2_pending_board_input
 _e2_pending_board_input = {} # Pop once before any legal admission callback.
 if not _e2_board_input_current(owned):
  _e2_record_board_input(owned,"retired",{"accepted":false,"reason":"queued_boat_owner_retired"})
  return
 # The original user command already caches its queued receipt. An empty
 # internal command ID executes that ONE intent under the original transaction
 # guard, rather than returning the cached queued receipt or making a new root.
 # Current control, cooldown bypass and exact current landing checks remain
 # the normal E2 policy; no stale landing coordinate is supplied or projected.
 var result: Dictionary = request_action("e",owned.aim,"")
 _e2_record_board_input(owned,"executed" if result.get("accepted",false) else "rejected",result)

func _e2_record_board_input(owned: Dictionary, status: String, result: Dictionary) -> void:
 var receipt: Dictionary = {"input_id":owned.input_id,"cast_id":owned.cast_id,"generation":owned.generation,"room_id":owned.room_id,"requested_at":owned.requested_at,"resolved_at":hero_time,"core_steps":ink_core_steps,"status":status,"result":result.duplicate(true),"current_boat_position":owned.state.get("position",Vector3.ZERO)}
 _e2_board_input_receipts.append(receipt)
 while _e2_board_input_receipts.size()>32: _e2_board_input_receipts.pop_front()

func _e2_abort_local() -> void:
 if not _e2_pending_board_input.is_empty():
  var owned: Dictionary = _e2_pending_board_input
  _e2_pending_board_input = {}
  _e2_record_board_input(owned,"retired",{"accepted":false,"reason":"boat_cancel_death_or_scope_retirement"})
 super._e2_abort_local()

func e2_board_input_report() -> Dictionary:
 var pending_view: Dictionary = {}
 if not _e2_pending_board_input.is_empty():
  var owned: Dictionary = _e2_pending_board_input
  pending_view = {"input_id":owned.input_id,"cast_id":owned.cast_id,"generation":owned.generation,"room_id":owned.room_id,"requested_at":owned.requested_at}
 return {"pending":pending_view,"receipts":_e2_board_input_receipts.duplicate(true),"ordinary_E2_enabled":false}
