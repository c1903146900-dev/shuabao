extends RefCounted
## Read-only presentation normalization. Never owns or writes the Sim.
## Detached ink_presenter_snapshot() is the sole clock/position authority.
const VERSION="ink-visual-bridge-candidate-20261009"
var current_scope:Dictionary={}
var seen_receipts:Dictionary={}
func same_scope(row:Dictionary,scope:Dictionary)->bool:
 return not row.is_empty() and row.get("generation",-1)==scope.get("generation",-2) and row.get("room_id","")==scope.get("room_id","?")
func finite_point(v:Variant)->bool:return v is Vector3 and v.is_finite()
func _row(kind:String,id:String,row:Dictionary,now:float)->Dictionary:
 return {"kind":kind,"id":id,"source_time":now,"age":maxf(0.0,now-float(row.get("born_at",row.get("released_at",now)))),"source":row.duplicate(true)}
func normalize(snapshot:Dictionary)->Dictionary:
 var scope:Dictionary=snapshot.get("scope",{})
 var now:float=float(snapshot.get("hero_time",snapshot.get("source_time",NAN)))
 var out={"version":VERSION,"accepted":false,"scope":scope.duplicate(true),"source_time":now,"effects":[],"fallbacks":[],"transients":[]}
 if scope.is_empty() or not is_finite(now):return out
 if current_scope!=scope:current_scope=scope.duplicate(true);seen_receipts.clear()
 out.accepted=true
 for wave:Dictionary in snapshot.get("waves",[]):
  if not same_scope(wave,scope):continue
  var path:Array=wave.get("path",[])
  if path.size()<2:continue
  var row=_row("q1",str(wave.get("wave_id","")),wave,now)
  row["path"]=path.duplicate(true);row["front_distance"]=float(wave.get("front_distance",0.0));row["width"]=float(wave.get("width",0))
  out.effects.append(row)
 var pending:Dictionary=snapshot.get("q2_input",{})
 if same_scope(pending,scope) and now<float(pending.get("expires_at",-INF)):
  var path:Array=pending.get("path",[])
  if not path.is_empty():out.effects.append(_row("q2_marker",str(pending.get("cast_id","")),pending,now).merged({"a":path[0]},true))
 for river:Dictionary in snapshot.get("rivers",[]):
  if not same_scope(river,scope) or bool(river.get("river_expired",true)) or now>=float(river.get("expires_at",-INF)):continue
  var path:Array=river.get("path",[])
  if path.size()!=2:
   out.fallbacks.append({"kind":"q2","id":river.get("river_id",""),"reason":"polyline_hex_keep_existing_source_renderer"});continue
  var row=_row("q2",str(river.river_id),river,now);row.merge({"a":path[0],"b":path[1],"width":river.width,"expires_at":river.expires_at})
  # Proposed preview cue, not water, damage, collision, or delayed settlement.
  row["range_hint_proposal"]={"path":path.duplicate(true),"width":river.width,"alpha":.13*(1.0-clampf(row.age/.82,0,1)),"style":"sparse_low_contrast_ground_ticks","requires_visual_review":true}
  out.effects.append(row)
 var mountain:Dictionary=snapshot.get("mountain",{})
 if same_scope(mountain,scope) and now<float(mountain.get("expires_at",-INF)):
  out.effects.append(_row("q3",str(mountain.get("terrain_id","")),mountain,now))
 var rain:Dictionary=snapshot.get("rain",{})
 var hero:Dictionary=snapshot.get("hero",{})
 if same_scope(rain,scope) and now<float(rain.get("expires_at",-INF)) and finite_point(hero.get("position")):
  out.effects.append(_row("e1",str(rain.get("form_id","")),rain,now).merged({"position":hero.position},true))
 var boat:Dictionary=snapshot.get("boat",{})
 if same_scope(boat,scope) and not bool(boat.get("retired",true)) and finite_point(boat.get("position")) and finite_point(boat.get("direction")):
  var row=_row("e2",str(boat.get("boat_id","")),boat,now)
  row["front"]=boat.position;row["direction"]=boat.direction
  # New mesh's bow is +1.05 in local Z: physical front remains authoritative.
  row["visual_origin"]=boat.position-boat.direction.normalized()*1.05
  row["phase"]=boat.get("phase","");row["route"]=boat.get("traveled_route",[]).duplicate(true)
  out.effects.append(row)
 var frame:Dictionary=snapshot.get("frames",{})
 if same_scope(frame,scope) and not bool(frame.get("retired",true)) and finite_point(frame.get("a")):
  out.effects.append(_row("e3",str(frame.get("frame_id","")),frame,now))
 # Polling repeated snapshots must not replay burst receipts.
 for key in ["q3_finished","e1_finished","e2_finished","e3_lifecycle"]:
  for receipt:Dictionary in snapshot.get(key,[]):
   if not same_scope(receipt,scope):continue
   var event_at:float=float(receipt.get("source_time",receipt.get("finished_at",-INF)))
   if not is_finite(event_at) or event_at>now:continue
   var token="%s:%s:%s:%s"%[key,str(receipt.get("cast_id","")),str(receipt.get("event",receipt.get("reason",""))),str(event_at)]
   if seen_receipts.has(token):continue
   seen_receipts[token]=true
   if now-event_at<=.8:out.transients.append({"kind":key,"source":receipt.duplicate(true),"age":now-event_at})
 return out
