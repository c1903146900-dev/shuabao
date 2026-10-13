extends "res://integration_checks/d03_source_gate.gd"
func _initialize() -> void:
 output_path="user://d03_war_regression.json"
 war_groups=["lifecycle"]
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--elixir-result="):output_path=arg.trim_prefix("--elixir-result=")
  if arg.begins_with("--elixir-group="):
   var group: String=arg.trim_prefix("--elixir-group=")
   if group not in ["lifecycle","replacement"]:quit(2);return
   war_groups=[group]
 run.call_deferred()
func run() -> void:
 g03_reset_evidence()
 if "commerce" in war_groups:war_commerce()
 if "full_slots" in war_groups:war_full_slots()
 if "lifecycle" in war_groups:war_lifecycle()
 if "replacement" in war_groups:war_replacement()
 await process_frame
 check(war_done==war_groups,"all requested finite war groups complete")
 var report: Dictionary={"passed":failures.is_empty(),"checks":checks,"check_records":check_records,"failures":failures,"groups":war_done,"records":war_records,"wallet_fixture":true,"source_damage_fixture_for_settlement":true,"natural_play":false,"GUI_verified":false,"Windows_verified":false,"source_binding_sha256":FileAccess.get_sha256("res://visual_rework_20261009/binding/source_binding.json")}
 var file: FileAccess=FileAccess.open(output_path,FileAccess.WRITE)
 if file==null:quit(2);return
 file.store_string(JSON.stringify(report,"  "));var error: Error=file.get_error();file.close()
 quit(0 if report.passed and error==OK else 2)
