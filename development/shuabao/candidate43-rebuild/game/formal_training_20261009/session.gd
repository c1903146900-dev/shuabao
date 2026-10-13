extends "res://tests/ink_ordinary_composed_20261006/candidate01/floor_session.gd"
## Inserted immediately below the retained frontdoor leaf. Original identity,
## location/lifecycle guards, owner, Bridge and one ledger remain authoritative.

func _training_ui_reason() -> String:
 if not panel_open: return "shop_panel_not_open"
 var reason: String = shop_location_reason()
 if not reason.is_empty(): return reason
 if initial_modal_open or not ledger.model.snapshot().pending_milestones.is_empty(): return "mandatory_hex_pending"
 if not ledger.model.state.shop_visit.get("ui_open",false): return "shop_panel_not_open"
 return ""

func submit(id: String, action: String, args: Dictionary) -> Dictionary:
 if action not in ["training_pay","training_select"]: return super.submit(id,action,args)
 var reason: String = _training_ui_reason()
 if not reason.is_empty(): return _record(_deny(reason))
 if id.is_empty(): return _record(_deny("missing_command_id"))
 var permitted: Array = ["epoch","revision","room_id"]
 if action == "training_select": permitted.append_array(["purchase_id","outcome"])
 for key: Variant in args:
  if key not in permitted: return _record(_deny("unsupported_training_argument"))
 var result: Dictionary
 if action == "training_pay":
  # This exact UI request keeps its original token on replay. Model.command
  # checks its own receipt before stale-token preflight; no second receipt map.
  var payment: Dictionary = args.duplicate(true)
  payment["purchase_id"] = run_id+"/formal-training/"+id
  result = ledger.shop_authority(self,id,"pay_body",payment)
 else:
  var runtime_reason: String = ledger._runtime_preflight()
  if not runtime_reason.is_empty(): return _record(_deny(runtime_reason))
  # Only the original Model owns receipt identity. An existing ID reaches its
  # exact request comparison before token expiry, just like payment replay.
  # New IDs must still carry the current authoritative visit token.
  if not ledger.model.receipts.has(id):
   var token: Dictionary = ledger.model.commerce_token()
   if args.get("epoch",-1) != token.epoch: return _record(_deny("stale_epoch"))
   if args.get("revision",-1) != token.revision: return _record(_deny("stale_revision"))
   if args.get("room_id","") != token.room_id: return _record(_deny("stale_room"))
  # Keep token, purchase and outcome in the one original receipt request.
  # The inherited bridge synchronizes only a newly committed selection; an
  # unchanged replay emits no extra events and does not reapply stat effects.
  result = ledger._refresh_committed(ledger.model.command(id,"select_body",args.duplicate(true)))
 if result.get("accepted",false): growth_dirty = true
 return _record(result)

func ui_state() -> Dictionary:
 var out: Dictionary = super.ui_state()
 if not out.get("ready",false): return out
 var training: Dictionary = out.state.formal_training.duplicate(true)
 var reason: String = _training_ui_reason()
 if not reason.is_empty():
  training.can_pay = false
  training.reason = reason
 training["can_select"] = reason.is_empty() and not training.pending.is_empty()
 out["formal_training"] = training
 return out
