extends RefCounted
## Read-only receipt/damage join for the existing bounded enemy.contact material cue.
## Produces detached display rows only. No simulation, actor, HP or control handle.
const EPS := 0.00001
var _scope := ""
var _seen: Dictionary = {}
func _key(value: Dictionary) -> String:
 return str(value.get("room_id",""))+":"+str(value.get("generation",-1))
func project(snapshot: Dictionary,fresh_events: Array) -> Array:
 var scope: Dictionary = snapshot.get("scope",{})
 var now: float = float(snapshot.get("source_time",-1.0))
 if not scope.has("room_id") or not scope.has("generation") or not is_finite(now): return []
 var next: String = _key(scope)
 if next != _scope:
  _scope = next
  _seen.clear()
 var rows: Array = []
 for value: Variant in fresh_events:
  if not value is Dictionary: continue
  var contact: Dictionary = value
  if contact.get("kind","") != "ink_q3_contact" or _key(contact) != _scope: continue
  var id: String = str(contact.get("source_event_id",""))
  var at: float = float(contact.get("source_time",-1.0))
  if id.is_empty() or _seen.has(id) or not is_finite(at) or at > now+EPS or now-at >= .075: continue
  var confirmed: bool = false
  for receipt: Dictionary in snapshot.get("q3_receipts",[]):
   if str(receipt.get("source_event_id","")) != id or _key(receipt) != _scope: continue
   confirmed = true
   for field: String in ["target_id","target_position","source_time","cast_id","segment_id","origin","direction","length","width"]:
    if receipt.get(field) != contact.get(field): confirmed = false; break
   if confirmed: break
  if not confirmed: continue
  for candidate: Variant in fresh_events:
   if not candidate is Dictionary: continue
   var damage: Dictionary = candidate
   if damage.get("kind","") != "damage" or damage.get("source","") != "q3" or _key(damage) != _scope: continue
   if bool(damage.get("replay",false)) or bool(damage.get("hex_generated",false)): continue
   if damage.get("target") != contact.get("target_id") or damage.get("cast_id") != contact.get("cast_id"): continue
   if damage.get("position") != contact.get("target_position") or damage.get("source_position") != contact.get("origin") or damage.get("direction") != contact.get("direction"): continue
   if damage.get("real_time") != contact.get("real_time") or damage.get("world_time") != contact.get("world_time"): continue
   if int(damage.get("sequence",-1)) >= int(contact.get("sequence",-1)): continue
   var amount: float = float(damage.get("amount",0.0))
   if not is_finite(amount) or amount <= 0.0: continue
   _seen[id] = at
   rows.append({"receipt_id":id,"target_id":str(contact.target_id),"actual_damage":amount,"contact_time":at,"target_position":contact.target_position,"damage_sequence":damage.sequence,"contact_sequence":contact.sequence,"source_scope":scope.duplicate(true),"display_policy":"existing enemy.contact; +12 percent original material for under 75 source ms"})
   break
 return rows
