extends "res://integration_checks/equipment40_source_gate.gd"
## Reuses every original G02 actual basic/Q/E and P1 assertion at the40 leaf.
## Additional B02 purchase uses the original shop; observer is inherited intact.
var input_partition: String="all"
var input_required: Array=["basic_q_e","p1"]
var input_complete: Array=[]

func _initialize() -> void:
 output_path="user://equipment40_b02_inputs_gate.json"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--equipment-result="):output_path=arg.trim_prefix("--equipment-result=")
  if arg.begins_with("--b02-input-group="):input_partition=arg.trim_prefix("--b02-input-group=")
 if input_partition!="all":
  if input_partition not in input_required:push_error("Unknown B02 actual input partition");quit(2);return
  input_required=[input_partition]
 run.call_deferred()

func funded_shop(label: String) -> Dictionary:
 var f: Dictionary=super.funded_shop(label)
 if f.is_empty():return {}
 if not buy(f,"final:B02"):dispose(f);return {}
 return f

func run() -> void:
 evidence={"wallet_fixtures":[],"inputs":[],"cooldown_fixtures":[],"completions":[],"aborts":[],"victory":[],"postcompletion":[],"lifecycle":[],"isolated_common":[],"movement":[],"g02_deaths":[],"pre_damage":[],"inputs_g02":[],"p1_g02":{},"route_g02":{},"extra_actor_g02":{}}
 if "basic_q_e" in input_required:
  var first: int=b02_records.size()
  g02_inputs()
  var sources: Array=[]
  for record: Dictionary in b02_records.slice(first):
   if record.event.source not in sources:sources.append(record.event.source)
  check("attack" in sources and "q1" in sources and "e1" in sources,"actual basic/Q1/E1 original deaths each issue B02")
  if G02_GROUPS[1] in g02_groups:input_complete.append("basic_q_e")
 if "p1" in input_required:
  var first: int=b02_records.size()
  g02_p1()
  var actual: Array=[]
  for record: Dictionary in b02_records.slice(first):
   if record.event.source=="yanguizhou_p1" and not record.synthetic and not record.witness.is_empty():actual.append(record)
  check(actual.size()==1 and actual[0].witness.witness.proof=="original_p1_atomic_death" and actual[0].view.active,"independent original P1 atomic death issues one actual B02 buff")
  if G02_GROUPS[2] in g02_groups:input_complete.append("p1")
 check(input_complete==input_required,"all selected B02 actual-input groups completed")
 var report: Dictionary={"suite":"equipment40_B02_original_basic_Q_E_P1_inputs","passed":failures.is_empty() and input_complete==input_required,"checks":checks,"failures":failures,"check_records":check_records,"partition":input_partition,"required_groups":input_required,"completed_groups":input_complete,"evidence":evidence,"b02_deaths":b02_records,"productionSession":true,"original_Host_factories":true,"all_inherited_G02_assertions_retained":true,"extra_actors":false,"source_pre_damage_fixture":true,"actual_input":true,"native_GUI":false,"production_ready":false}
 var file: FileAccess=FileAccess.open(output_path,FileAccess.WRITE)
 if file==null:push_error("Unable to write B02 input result");quit(2);return
 file.store_string(JSON.stringify(report,"  "));var error: Error=file.get_error();file.close()
 print("B02_ACTUAL_INPUTS ",JSON.stringify({"passed":report.passed,"checks":checks,"failures":failures,"result":output_path}))
 quit(2 if error!=OK else (0 if report.passed else 1))
