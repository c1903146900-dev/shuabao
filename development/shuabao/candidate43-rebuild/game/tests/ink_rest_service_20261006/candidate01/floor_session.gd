extends "res://tests/ink_p1_ordinary_20261006/candidate01/ordinary01/floor_session.gd"
## Keep the admitted exact Sim and one P1 Session ledger. Only successful
## committed service entry gains the newly authorized rest effect.
const RestService = preload("res://tests/ink_rest_service_20261006/candidate01/rest_service.gd")
var rest_service: RefCounted = RestService.new(self)

func enter_selected_node() -> Dictionary:
 var entered: Dictionary = super.enter_selected_node()
 if not entered.get("accepted",false) or not _entered_service("rest"): return entered
 var rest: Dictionary = rest_service.settle(self,_active_entry.duplicate(true))
 if not rest.accepted: return _fault("post_commit_rest:" + str(rest.reason),rest)
 growth_dirty = true
 session_events.append({"type":"rest_settled","receipt":rest.duplicate(true)})
 entered["rest"] = rest
 return _record(entered)

func snapshot() -> Dictionary:
 var state: Dictionary = super.snapshot()
 state["rest_settlements"] = rest_service.snapshot() if rest_service != null else []
 return state
