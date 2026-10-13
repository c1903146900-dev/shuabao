extends RefCounted
## Owns diagnostic output only. All inputs are detached/read-only observations.
const Policy=preload("res://tests/ink_shop_ui_host_20261004/journal01/sample_policy.gd")
const PERIODIC_BYTES_LIMIT: int=32*1024*1024
var policy=Policy.new()
var event_stream: FileAccess
var input_stream: FileAccess
var lifecycle_stream: FileAccess
var directory: String=""
var opened: bool=false
var closed: bool=false
var frame_rows: int=0
var periodic_bytes: int=0
var total_frame_bytes: int=0
var periodic_budget_suppressed: int=0
var event_rows: int=0
var input_rows: int=0
var pause_rows: int=0
var lifecycle_rows: int=0
var errors: Array=[]
var last_source_scope: Dictionary={}
var last_ledger: Dictionary={}
var last_wall_usec: int=0
func open_streams(path: String,scope: String) -> void:
 if opened:return
 opened=true;directory=path
 event_stream=FileAccess.open(path.path_join("combat_events.jsonl"),FileAccess.WRITE)
 input_stream=FileAccess.open(path.path_join("received_inputs.jsonl"),FileAccess.WRITE)
 lifecycle_stream=FileAccess.open(path.path_join("journal_lifecycle.jsonl"),FileAccess.WRITE)
 for pair in [["combat_events",event_stream],["received_inputs",input_stream],["lifecycle",lifecycle_stream]]:
  if pair[1]==null:errors.append(str(pair[0])+"_open_failed")
 lifecycle({"type":"opened","scope":scope,"complete":false,"source_physics_modified":false,"periodic_hz_max":10,"periodic_bytes_limit":PERIODIC_BYTES_LIMIT,"boundary_and_paused_changes_unsampled":true,"F8_F9":"original full capture unchanged"})
func observe_frame(stream: FileAccess,wall_usec: int,draw: int,full: Dictionary,ink: Dictionary,actor: Dictionary,ledger: Dictionary,scope: Dictionary) -> void:
 if closed or not opened:return
 last_wall_usec=wall_usec;last_source_scope=scope.duplicate(true);last_ledger=ledger.duplicate(true)
 var paused: bool=bool(full.get("paused",true))
 var signature: String=""
 if paused:
  var digest=HashingContext.new();digest.start(HashingContext.HASH_SHA256)
  digest.update(var_to_bytes(_paused_payload([full,ink,actor,ledger])));signature=digest.finish().hex_encode()
 var reason: String=policy.choose(wall_usec,paused,scope,signature)
 if not Policy.retained(reason):return
 if reason=="periodic" and periodic_bytes>=PERIODIC_BYTES_LIMIT:
  periodic_budget_suppressed+=1;return
 var row: Dictionary={"wall_usec":wall_usec,"draw_index":draw,"snapshot":ink,"hero":full.get("hero",{}),"enemies":full.get("enemies",[]),"paused":paused,"actor_sample":actor,"progression":full.get("progression",{}),"ledger":ledger,"journal_reason":reason,"journal_scope":scope,"journal_row":frame_rows+1,"sampling":"periodic<=10Hz; explicit boundary/paused state changes retained separately; not per-frame evidence"}
 var bytes: PackedByteArray=(JSON.stringify(json_safe(row))+"\n").to_utf8_buffer()
 if reason=="periodic" and periodic_bytes+bytes.size()>PERIODIC_BYTES_LIMIT:
  periodic_budget_suppressed+=1;return
 if stream==null:errors.append("source_frame_stream_missing");return
 stream.store_buffer(bytes);stream.flush()
 if stream.get_error()!=OK:errors.append("source_frame_write_error");return
 frame_rows+=1;total_frame_bytes+=bytes.size()
 if reason=="periodic":periodic_bytes+=bytes.size()
func combat(event: Dictionary,wall_usec: int,ledger: Dictionary) -> void:
 if closed or not opened:return
 var row: Dictionary={"serial":event_rows+1,"wall_usec":wall_usec,"event":event,"event_room_id":event.get("room_id",""),"event_generation":event.get("generation",-1),"ledger_after_authority":ledger}
 if _line(event_stream,row,"combat_event"):event_rows+=1
func drain_inputs(inputs: Array,pauses: Array) -> void:
 if closed or not opened:return
 while input_rows<inputs.size():
  if not _line(input_stream,{"serial":input_rows+1,"input":inputs[input_rows]},"input"):break
  input_rows+=1
 while pause_rows<pauses.size():
  if not _line(lifecycle_stream,{"type":"pause","serial":pause_rows+1,"receipt":pauses[pause_rows]},"pause"):break
  pause_rows+=1
func lifecycle(row: Dictionary) -> void:
 if closed or not opened:return
 if _line(lifecycle_stream,row,"lifecycle"):lifecycle_rows+=1
func summary() -> Dictionary:
 return {"schema":"ink-diagnostic-journal-1","opened":opened,"closed":closed,"frame_rows":frame_rows,"periodic_hz_max":10,"periodic_bytes":periodic_bytes,"periodic_bytes_limit":PERIODIC_BYTES_LIMIT,"periodic_budget_suppressed":periodic_budget_suppressed,"periodic_capture_complete":periodic_budget_suppressed==0,"total_frame_bytes":total_frame_bytes,"policy_counts":policy.counts.duplicate(true),"combat_event_rows":event_rows,"input_rows":input_rows,"pause_rows":pause_rows,"lifecycle_rows":lifecycle_rows,"errors":errors.duplicate(true),"last_wall_usec":last_wall_usec,"last_scope":last_source_scope.duplicate(true),"last_ledger":last_ledger.duplicate(true),"source_mutations":0,"native_UI_acceptance":false,"performance_acceptance":false,"guard_interruption_rule":"missing final journal_summary/session_result means incomplete; never inferred normal close"}
func finish(reason: String) -> void:
 if closed or not opened:return
 lifecycle({"type":"host_save_evidence","reason":reason,"complete":true,"ledger":last_ledger,"counts":summary()})
 for stream in [event_stream,input_stream,lifecycle_stream]:
  if stream!=null:stream.flush();stream.close()
 closed=true
 var output=FileAccess.open(directory.path_join("journal_summary.json"),FileAccess.WRITE)
 if output!=null:
  var report: Dictionary=summary();report["close_reason"]=reason;report["normal_F10"]=reason=="F10"
  output.store_string(JSON.stringify(json_safe(report),"  "));output.flush();output.close()
func _line(stream: FileAccess,row: Dictionary,label: String) -> bool:
 if stream==null:errors.append(label+"_stream_missing");return false
 stream.store_line(JSON.stringify(json_safe(row)));stream.flush()
 if stream.get_error()!=OK:errors.append(label+"_write_error");return false
 return true
static func json_safe(value: Variant) -> Variant:
 if value is Vector3:return [value.x,value.y,value.z] if value.is_finite() else "nonfinite_Vector3"
 if value is Vector2:return [value.x,value.y]
 if value is Dictionary:
  var result: Dictionary={}
  for key in value:result[str(key)]=json_safe(value[key])
  return result
 if value is Array:
  var result: Array=[]
  for item in value:result.append(json_safe(item))
  return result
 return value

static func _paused_payload(value: Variant) -> Variant:
 # Exclude observation envelope/counters only. Gameplay revision, HP, input,
 # source phase and safe presentation elapsed/serial remain substantive state.
 if value is Dictionary:
  var clean: Dictionary={}
  for key in value:
   if str(key) in ["wall_usec","draw_index","frame_post_draw_index","engine_process_frame","engine_drawn_frame","journal_row","journal_reason","journal_scope","recording_count","observed_draw_count"]:continue
   clean[key]=_paused_payload(value[key])
  return clean
 if value is Array:
  var clean: Array=[]
  for item in value:clean.append(_paused_payload(item))
  return clean
 return value
