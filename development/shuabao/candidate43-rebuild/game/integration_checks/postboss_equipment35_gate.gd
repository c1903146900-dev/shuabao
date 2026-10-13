extends "res://integration_checks/postboss_equipment33_gate.gd"

# Exact additional Model layer; every inherited owner/lifecycle assertion stays.
func check_model_successor(f: Dictionary, label: String) -> void:
 var script: Script = f.session.ledger.model.get_script()
 var paths: Array = ["res://equipment_distance_20261009/model.gd", "res://equipment_expansion_20261009/model.gd", "res://visual_rework_20261009/binding/postboss_model.gd", "res://tests/ink_equipment_live_20261008/content01/model.gd"]
 for path: String in paths:
  if not check(script != null and script.resource_path == path, label + ": exact equipment35 Model ancestor " + path): return
  script = script.get_base_script()
 check(FileAccess.get_sha256(POSTBOSS_BASE_MODEL_PATH) == POSTBOSS_BASE_MODEL_SHA, label + ": original content01 Model SHA retained")
