extends "res://tests/ink_initial_hex_ui_20261004/fix01/controller.gd"
## Same request identity, Model.command, receipts and Bridge projection path.
var _session: WeakRef

func bind_session(session: RefCounted, view: Control) -> void:
 _session = weakref(session)
 if not command_completed.is_connected(session.progression_command_completed):
  command_completed.connect(session.progression_command_completed)
 bind(session.ledger.model, view, session.ledger.definitions)

func handle_request(request: Dictionary) -> void:
 var action: String = str(request.get("action", ""))
 if action in ["learn", "undo_new_points", "undo_skill", "respec"]:
  if _session == null or _session.get_ref() == null:
   _finish(request, _boundary("session_unavailable")); return
  var session = _session.get_ref()
  if session.sim.transaction_active:
   _finish(request, _boundary("transaction_in_progress")); return
  if not model.snapshot().pending_milestones.is_empty():
   _finish(request, _boundary("mandatory_hex_pending")); return
  if action == "respec" and (not session._entered_service("training") or not model.state.training):
   _finish(request, _boundary("entered_training_node_required")); return
 super.handle_request(request)

func refresh() -> void:
 super.refresh()
 if is_instance_valid(hud) and model != null and hud.has_method("present_q_growth"):
  hud.present_q_growth(model.snapshot(), definitions)
