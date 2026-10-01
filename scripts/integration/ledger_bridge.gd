extends RefCounted
## The catalog-backed run model is the only XP, currency and skill-point authority.
const Model = preload("res://scripts/integration/run_model.gd")
var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/progression/prototype/catalog.json"))
var model = Model.new(definitions,"fengli")
var serial := 0
func _init() -> void:
 # Capabilities have concrete consumers; never restore them from saves.
 model.set_supported_hooks(preload("res://scripts/integration/consumers.gd").HOOKS)
func command(action: String, args: Dictionary = {}) -> Dictionary:
 serial += 1
 var r: Dictionary = model.command("integration-context-%d" % serial, action, args)
 return {"ok":r.accepted,"reason":r.reason,"state":snapshot()}
func snapshot() -> Dictionary:
 var s: Dictionary = model.snapshot()
 var slots := {}
 for slot in s.skills: slots[slot] = {"skill":s.skills[slot].candidate,"rank":s.skills[slot].rank}
 return {"level":s.level,"earned":s.level,"available":s.points,"slots":slots,"in_combat":s.phase == "combat","at_training_node":s.training,"refundable_transactions":s.allocations.size(),"authority":"integration/run_model.gd"}
func begin_encounter() -> Dictionary:
 return command("context",{"phase":"combat"})
func end_encounter() -> Dictionary:
 return command("context",{"phase":"safe"})
func invest(slot: String, candidate: String) -> Dictionary:
 return command("learn",{"slot":slot,"candidate":candidate,"expected_rank":model.snapshot().skills[slot].rank})
func undo_last_investment() -> Dictionary:
 return command("undo_skill")
func reset_at_training() -> Dictionary:
 return command("respec")
func set_training_node(present: bool) -> Dictionary:
 return command("context",{"phase":"safe","training":present})
