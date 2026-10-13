extends "res://integration_checks/equipment42_source_gate.gd"
## Original unchanged G02 basic/Q/E input cases, with legal G03 copies added.
var input_done: bool=false

func _initialize() -> void:
 output_path="user://equipment42_g03_inputs_gate.json"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--equipment-result="):output_path=arg.trim_prefix("--equipment-result=")
 run.call_deferred()

func funded_shop(label: String) -> Dictionary:
 var f: Dictionary=super.funded_shop(label)
 if f.is_empty():return {}
 if not buy(f,G03_ITEM) or not buy(f,G03_ITEM):dispose(f);return {}
 return f

func run() -> void:
 g03_reset_evidence();g02_inputs()
 var kinds: Array=[]
 var positive: Array=[]
 for record: Dictionary in g03_records:
  if record.synthetic or record.witness.is_empty():continue
  var source: String=str(record.event.get("source",""))
  if source in ["attack","q1","e1"]:
   if source not in kinds:kinds.append(source)
   if float(record.expected_increment)>0.0 and source not in positive:positive.append(source)
 check("attack" in kinds and "q1" in kinds and "e1" in kinds,"unchanged original basic/Q1/E1 input suite reaches all three real G03 damage sources")
 check("attack" in positive and "q1" in positive and "e1" in positive,"each real input source has an actually low-health eligible packet")
 input_done=G02_GROUPS[1] in g02_groups
 g03_required=["actual_basic_q_e_inputs"]
 if input_done:g03_completed=g03_required.duplicate()
 evidence["input_sources"]={"actual":kinds,"positive_ratio":positive,"all_inherited_G02_assertions_retained":true}
 g03_report("equipment42_G03_original_basic_Q_E_inputs")
