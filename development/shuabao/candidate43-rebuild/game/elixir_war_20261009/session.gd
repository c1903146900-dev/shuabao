extends "res://elixir_hunter_20261009/session.gd"
## Only the two admitted bottles gains a shop consumption entry. The one
## original Model receipt owns identity, token checks, replay and conflict.
func submit(id: String, action: String, args: Dictionary) -> Dictionary:
 if action != "consume": return super.submit(id,action,args)
 var reason: String = _training_ui_reason()
 if not reason.is_empty(): return _record(_deny(reason))
 if id.is_empty(): return _record(_deny("missing_command_id"))
 var permitted: Array = ["epoch","revision","room_id","uid"]
 for key: Variant in args:
  if key not in permitted: return _record(_deny("unsupported_elixir_argument"))
 for key: String in ["epoch","revision","uid"]:
  if not args.has(key) or typeof(args[key]) != TYPE_INT: return _record(_deny("invalid_elixir_argument_type:"+key))
 if not args.has("room_id") or typeof(args.room_id) != TYPE_STRING: return _record(_deny("invalid_elixir_argument_type:room_id"))
 # Existing IDs must reach the original exact request comparison even after
 # successful consumption removed their UID. An unrelated receipt conflicts.
 if not ledger.model.receipts.has(id):
  var found: bool = false
  for item: Dictionary in ledger.model.state.inventory:
   if int(item.uid)==int(args.uid) and str(item.id) in ["elixir:01","elixir:04"]: found=true;break
  if not found: return _record(_deny("admitted_elixir_uid_required"))
 var result: Dictionary = ledger.shop_authority(self,id,"consume",args.duplicate(true))
 if result.get("accepted",false): growth_dirty = true
 return _record(result)
