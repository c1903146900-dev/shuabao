extends "res://tests/ink_e1_audio_20261008/candidate01/router.gd"
## One shared output router. Families are detached consumers, never new buses.
const BoatAudio=preload("res://tests/ink_e2_audio_20261008/candidate01/consumer.gd")
var terminal_closed: bool = false
const RiverAudio=preload("res://tests/ink_q2_audio_20261008/candidate01/consumer.gd")
const FrameAudio=preload("res://tests/ink_e3_audio_20261008/candidate01/consumer.gd")
const UltimateAudio=preload("res://tests/ink_ultimate_audio_20261008/candidate01/consumer.gd")
var family_consumers: Dictionary={"e2":BoatAudio.new(),"q2":RiverAudio.new(),"e3":FrameAudio.new(),"ultimate":UltimateAudio.new()}
func _append_unique_stops(output: Array, extra: Array) -> void:
 for command: Dictionary in extra:
  if command.get("action","")=="stop_all":
   var found: bool=false
   for existing: Dictionary in output:
    if existing.get("action","")=="stop_all":found=true;break
   if found:continue
  output.append(command)
func consume(event: Dictionary,state: Dictionary) -> Array:
 if terminal_closed:return []
 var output: Array=super.consume(event,state)
 for consumer: RefCounted in family_consumers.values():
  _append_unique_stops(output,consumer.consume(event,state))
 return output
func set_paused(value: bool) -> Array:
 var output: Array=super.set_paused(value)
 for consumer: RefCounted in family_consumers.values():
  _append_unique_stops(output,consumer.set_paused(value))
 return output
func clear(reason: String="host_clear") -> Array:
 var output: Array=super.clear(reason)
 for consumer: RefCounted in family_consumers.values():
  _append_unique_stops(output,consumer.clear(reason))
 return output
func close_all(reason: String="exit") -> Array:
 terminal_closed=true
 ended=true
 var output: Array=super.clear(reason)
 for consumer: RefCounted in family_consumers.values():
  _append_unique_stops(output,consumer.close(reason))
 return output
func reset() -> Array:
 terminal_closed=false
 var output: Array=super.reset()
 for consumer: RefCounted in family_consumers.values():
  _append_unique_stops(output,consumer.reset())
 return output
func snapshot() -> Dictionary:
 var output: Dictionary=super.snapshot()
 output["terminal_closed"]=terminal_closed
 output["composition"]="one_bus_all_authored_Q_E_R_and_basic_shift"
 output["families"]={}
 for name: String in family_consumers:
  var report: Dictionary=family_consumers[name].snapshot()
  output.families[name]=report
  for id: String in report.counts:output.counts[id]=int(output.counts.get(id,0))+int(report.counts[id])
 return output
