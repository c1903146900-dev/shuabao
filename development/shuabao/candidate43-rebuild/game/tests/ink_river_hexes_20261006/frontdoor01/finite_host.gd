extends "res://scripts/integration/yanguizhou_first_floor.gd"
## Instantiate the ACTUAL temporarily staged entry. Skip graphics warmup and
## file-capture output; lifecycle calls below still use the unchanged entry body.
var finite_close_reasons: Array[String]=[]
func _ready() -> void:
 set_process(false);set_process_input(false);set_process_unhandled_input(false)
func _process(_delta: float) -> void:pass
func _drawn() -> void:pass
func save_evidence(reason: String) -> void:
 finite_close_reasons.append(reason)
