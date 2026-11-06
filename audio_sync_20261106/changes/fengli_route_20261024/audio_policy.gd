extends RefCounted
## Presentation-only classification; caller authenticates the synchronous source event.
## Semantic aliases share the original five banks and do not increase rate/voice budgets.
static func classify(event: Dictionary) -> Dictionary:
 if bool(event.get("replay",false)) or bool(event.get("hex_generated",false)):return {}
 var kind: String=str(event.get("kind",""))
 if kind=="passive_rescue":
  if event.has("cast_id") or not event.get("sequence") is int or int(event.sequence)<=0:return {}
  return {"cue":"p2_rescue","bank":"blink_move","claim":"passive:%d"%int(event.sequence),"identity_kind":"passive","cast_id":null,"priority":1}
 if not event.get("cast_id") is int or int(event.cast_id)<=0:return {}
 var cast_id:int=int(event.cast_id)
 var cue:String=""
 var bank:String=""
 var occurrence:int=0
 var round_id:int=0
 var lane:String="move"
 match kind:
  "attack_started", "dash_attack_started":cue="basic_move"
  "dash":
   if not event.get("dash_id") is int or int(event.dash_id)<=0:return {}
   var duration:Variant=event.get("duration")
   if not (duration is int or duration is float) or not is_finite(float(duration)) or float(duration)<=0:return {}
   cue="dash_move";bank="blink_move";lane="dash" # Existing licensed short movement bank; same voice/rate budgets.
  "q2_strike_started":
   if not event.get("strike") is int:return {}
   occurrence=int(event.strike)
   if occurrence<=0:return {}
   cue="q2_move"
  "e2_spin_started":
   if not event.get("occurrence") is int:return {}
   occurrence=int(event.occurrence)
   if occurrence<=0:return {}
   cue="e2_move"
  "e2_blink", "e2_return":cue="blink_move";lane=kind
  "q1_started", "q3_launched", "e1_projectile", "r1_release":
   cue=kind;bank="q2_move";lane=kind
  "e1_pierce_started":cue=kind;bank="blink_move";lane=kind
  "e3_started", "r1_started":cue=kind;bank="e2_move";lane=kind
  "r2_throw":
   if not event.get("round") is int or int(event.round)<=0:return {}
   round_id=int(event.round);cue=kind;bank="q2_move";lane=kind
  "damage":
   var amount:Variant=event.get("amount")
   if not (amount is int or amount is float) or not is_finite(float(amount)) or float(amount)<=0.0:return {}
   var source:String=str(event.get("source",""))
   if source not in ["attack","dash_attack","q1","q2","q3","e1_dagger","e1_pierce","e2","e2_extra","r1","r2_nail"]:return {}
   if event.get("damage_type", "ordinary")!="ordinary":return {}
   if not event.get("occurrence",0) is int:return {}
   occurrence=int(event.get("occurrence",0))
   if occurrence<0 or (source in ["q2","q3","e2","e2_extra","r2_nail"] and occurrence<=0):return {}
   if source=="r2_nail":
    if not event.get("round") is int or int(event.round)<=0:return {}
    round_id=int(event.round)
   cue="contact";lane="contact:"+source
  _:return {}
 if bank.is_empty():bank=cue
 var claim:String="%d:%s:%d"%[cast_id,lane,occurrence]
 if round_id>0:claim="%d:%s:round:%d:occurrence:%d"%[cast_id,lane,round_id,occurrence]
 return {"cue":cue,"bank":bank,"claim":claim,"identity_kind":"cast","cast_id":cast_id,"priority":2 if cue=="contact" else 1}
