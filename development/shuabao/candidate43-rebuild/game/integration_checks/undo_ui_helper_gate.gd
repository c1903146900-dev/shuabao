extends SceneTree
## Independent table fixtures only. These rows do not claim lifecycle coverage.
const PANEL_PATH := "res://visual_rework_20261009/transaction_panel.gd"
var output_path: String = "user://undo_ui_helper_gate.json"
var failures: Array = []
var records: Array = []

func _initialize() -> void:
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--undo-helper-result="): output_path = arg.trim_prefix("--undo-helper-result=")
 run.call_deferred()

func run() -> void:
 var panel: Script = load(PANEL_PATH)
 if panel == null: push_error("Missing explicit candidate transaction panel"); quit(2); return
 var cases: Array = [
  {"label":"empty", "rows":[], "blocked":true, "reason":"undo_boundary"},
  {"label":"one ordinary", "rows":[{"sealed":false}], "blocked":false, "reason":""},
  {"label":"missing flag defaults to unsealed in isolated UI helper", "rows":[{}], "blocked":false, "reason":""},
  {"label":"one used", "rows":[{"sealed":true,"seal_reason":"already_used"}], "blocked":true, "reason":"already_used"},
  {"label":"older ordinary newer sealed", "rows":[{"sealed":false},{"sealed":true,"seal_reason":"already_used"}], "blocked":false, "reason":""},
  {"label":"older sealed newer ordinary", "rows":[{"sealed":true,"seal_reason":"already_used"},{"sealed":false}], "blocked":false, "reason":""},
  {"label":"only middle ordinary", "rows":[{"sealed":true},{"sealed":false},{"sealed":true}], "blocked":false, "reason":""},
  {"label":"all sealed use latest reason", "rows":[{"sealed":true,"seal_reason":"already_used"},{"sealed":true,"seal_reason":"reward_already_claimed"}], "blocked":true, "reason":"reward_already_claimed"},
  {"label":"HP dependency preserved", "rows":[{"sealed":true,"seal_reason":"hp_consumption_dependency"}], "blocked":true, "reason":"hp_consumption_dependency"},
  {"label":"missing sealed reason fallback", "rows":[{"sealed":true}], "blocked":true, "reason":"already_used"}
 ]
 for row: Dictionary in cases:
  var before: PackedByteArray = var_to_bytes(row.rows)
  var actual: Dictionary = panel.undo_ui_status(row.rows)
  var passed: bool = actual.get("blocked") == row.blocked and actual.get("reason") == row.reason and before == var_to_bytes(row.rows)
  records.append({"label":row.label,"passed":passed,"expected":{"blocked":row.blocked,"reason":row.reason},"actual":actual,"input_unchanged":before==var_to_bytes(row.rows)})
  if not passed: failures.append(row.label)
 var report: Dictionary = {"suite":"undo_ui_isolated_helper_tables","passed":failures.is_empty(),"checks":records.size(),"failures":failures,"records":records,"actual_lifecycle_coverage":false,"synthetic_record_tables":true}
 var file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
 if file == null: push_error("Cannot write helper result"); quit(2); return
 file.store_string(JSON.stringify(report,"  "))
 var error: Error = file.get_error()
 file.close()
 print("UNDO_UI_HELPER_TABLES ",JSON.stringify(report))
 quit(2 if error != OK else (0 if report.passed else 1))
