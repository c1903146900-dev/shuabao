extends "res://integration_checks/d03_source_gate.gd"
## Original training12 bodies reused unchanged against the new bound Session.
var prior_partition: String="commerce"
func _initialize() -> void:
 output_path="user://d03_prior_regression.json"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--elixir-result="):output_path=arg.trim_prefix("--elixir-result=")
  if arg.begins_with("--prior-group="):prior_partition=arg.trim_prefix("--prior-group=")
 if prior_partition not in ["commerce","panel_signals"]:quit(2);return
 run.call_deferred()
func run() -> void:
 g03_reset_evidence();training12_required=[prior_partition]
 if prior_partition=="commerce":training12_commerce()
 else:training12_panel_signals()
 await process_frame
 check(training12_done==training12_required,"original prior group complete")
 var report: Dictionary={"passed":failures.is_empty(),"checks":checks,"check_records":check_records,"failures":failures,"records":training12_records,"groups":training12_done,"wallet_fixture":true,"original_training_function_bodies_unchanged":true,"natural_play":false,"GUI_verified":false,"source_binding_sha256":FileAccess.get_sha256("res://visual_rework_20261009/binding/source_binding.json")}
 var file: FileAccess=FileAccess.open(output_path,FileAccess.WRITE)
 if file==null:quit(2);return
 file.store_string(JSON.stringify(report,"  "));var error: Error=file.get_error();file.close();quit(0 if report.passed and error==OK else 2)
