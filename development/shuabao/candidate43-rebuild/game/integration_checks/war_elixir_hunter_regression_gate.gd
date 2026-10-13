extends "res://integration_checks/elixir04_source_gate.gd"
## Unmodified original hunter full-slots/lifecycle methods; the original commerce
## group intentionally asserts01 remains closed and is superseded by war admission.
func _initialize() -> void:
 output_path="user://war_hunter_regression.json"
 hunter_groups=["full_slots","lifecycle"]
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--elixir-result="):output_path=arg.trim_prefix("--elixir-result=")
  if arg.begins_with("--elixir-group="):
   var group: String=arg.trim_prefix("--elixir-group=")
   if group not in ["full_slots","lifecycle"]:quit(2);return
   hunter_groups=[group]
 run.call_deferred()
func check_model_successor(f: Dictionary,label: String) -> void:
 var script: Script=f.session.ledger.model.get_script()
 for path: String in ["res://elixir_war_20261009/model.gd","res://elixir_hunter_20261009/model.gd","res://formal_training_20261009/model.gd","res://equipment_regeneration_20261009/model.gd","res://equipment_blood_trial_20261009/model.gd","res://equipment_lifeline_20261009/model.gd","res://equipment_pursuit_20261009/model.gd","res://equipment_training_20261009/model.gd",B04_MODEL,G06_MODEL,B01_MODEL,DISTANCE_MODEL_PATH,POSTBOSS_MODEL_PATH,POSTBOSS_PRIOR_MODEL_PATH,POSTBOSS_BASE_MODEL_PATH]:
  if not check(script!=null and script.resource_path==path,label+": exact model ancestor "+path):return
  script=script.get_base_script()
 check(FileAccess.get_sha256(POSTBOSS_BASE_MODEL_PATH)==POSTBOSS_BASE_MODEL_SHA,label+": original Model retained")
