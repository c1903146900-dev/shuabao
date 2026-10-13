extends "res://tests/ink_equipment_live_20261008/content01/model.gd"
## Exact inherited economy/health model; only prevent a new terminal-run potion debit.
func potion_terminal_reason(owner:RefCounted)->String:
 if owner==null or _commerce_owner==null or not is_same(_commerce_owner.get_ref(),owner):return "wrong_commerce_authority"
 if str(owner.get("status")) in ["completed","aborted","defeated","faulted","unbound"]:return "potion_run_finished"
 return ""
func use_potion(owner:RefCounted,command_id:String,uid:int)->Dictionary:
 # Preserve original authority validation, conflict ordering and successful retry receipts.
 if not _potion_bound or owner==null or _commerce_owner==null or not is_same(_commerce_owner.get_ref(),owner):return super.use_potion(owner,command_id,uid)
 if command_id.is_empty() or _potion_requests.has(command_id) or receipts.has(command_id):return super.use_potion(owner,command_id,uid)
 var reason=potion_terminal_reason(owner)
 if not reason.is_empty():return _deny(reason)
 return super.use_potion(owner,command_id,uid)
