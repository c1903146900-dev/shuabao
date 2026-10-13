extends SceneTree
const Cases=preload("res://integration_checks/equipment38_helper_cases.gd")
func _initialize()->void:
 var numeric=JSON.parse_string(FileAccess.get_file_as_string("res://tests/equipment_editable_tables_20261004/outputs/equipment_tables/converted/equipment_numeric_config.json"))
 var source=JSON.parse_string(FileAccess.get_file_as_string("res://docs/equipment_source_20261004/correction_0959/equipment_system_extracted.json"))
 var result=Cases.run(numeric,source)
 result["passed"]=result.get("accepted",false)
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--equipment-result="):
   var f=FileAccess.open(arg.trim_prefix("--equipment-result="),FileAccess.WRITE)
   f.store_string(JSON.stringify(result,"  "));f.close()
 print("B04_HELPER ",JSON.stringify(result))
 quit(0 if result.passed else 2)
