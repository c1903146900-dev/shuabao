extends RefCounted
## New Lv1 authority only. Deliberately no configure_test, set_level or fallback hero.
const Catalog = preload("res://tests/ink_first_floor_flow_20261004/ink_catalog.gd")
const Model = preload("res://tests/ink_first_floor_flow_20261004/ink_run_model.gd")
var definitions: Dictionary = {}
var model: RefCounted
var serial := 0
var readiness: Dictionary = {"accepted":false, "reason":"not_initialized"}

func initialize(capabilities: Dictionary, table_path: String, allow_provisional: bool = false) -> Dictionary:
 if model != null: return {"accepted":false, "reason":"already_initialized"}
 readiness = Catalog.build(capabilities, table_path, allow_provisional)
 if not readiness.accepted: return readiness.duplicate(true)
 definitions = readiness.definitions
 model = Model.new(definitions, "yanguizhou")
 model.set_supported_hooks(readiness.hooks)
 return {"accepted":true, "reason":"", "state":snapshot()}

func command(action: String, args: Dictionary = {}) -> Dictionary:
 if model == null: return {"ok":false, "reason":"ink_ledger_unavailable", "state":{}}
 serial += 1
 var result: Dictionary = model.command("ink-context-%d" % serial, action, args)
 return {"ok":result.accepted, "reason":result.reason, "state":snapshot()}

func snapshot() -> Dictionary:
 if model == null: return {}
 var state: Dictionary = model.snapshot()
 var slots: Dictionary = {}
 for slot in state.skills:
  slots[slot] = {"skill":state.skills[slot].candidate, "rank":state.skills[slot].rank}
 var earned: int = int(state.level) + int(state.get("bonus_sp", 0))
 return {"level":state.level, "earned":earned, "spent":earned-int(state.points), "leveling_earned":state.level, "bonus_earned":int(state.get("bonus_sp", 0)), "available":state.points, "slots":slots, "in_combat":state.phase == "combat", "at_training_node":state.training, "refundable_transactions":state.allocations.size(), "authority":"ink_run_model_source_candidate"}

func begin_encounter() -> Dictionary: return command("context", {"phase":"combat"})
func end_encounter() -> Dictionary: return command("context", {"phase":"safe"})
func invest(slot: String, candidate: String) -> Dictionary:
 if model == null: return {"ok":false, "reason":"ink_ledger_unavailable", "state":{}}
 return command("learn", {"slot":slot, "candidate":candidate, "expected_rank":model.state.skills.get(slot, {}).get("rank", -1)})
func undo_last_investment() -> Dictionary: return command("undo_skill")
func reset_at_training() -> Dictionary: return command("respec")
func set_training_node(present: bool) -> Dictionary:
 if model == null: return {"ok":false, "reason":"ink_ledger_unavailable", "state":{}}
 if model.state.phase == "combat": return {"ok":false, "reason":"cannot_enter_training_in_combat", "state":snapshot()}
 return command("context", {"phase":"safe", "training":present})
