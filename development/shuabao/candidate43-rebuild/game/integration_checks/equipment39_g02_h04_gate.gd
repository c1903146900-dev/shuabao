extends "res://integration_checks/equipment39_h04_regression_gate.gd"
## PREPARED ONLY. All existing H04/B01 source assertions remain inherited.
## The only new held item is genuine G02; B01 stat deltas use its actual paid
## baseline. No actor/Hex/rank/task/HP/AI/position field is assigned.
var g02_h04_observations: Array = []

func _initialize() -> void:
 output_path = "user://equipment39_g02_h04_gate.json"
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--equipment-result="): output_path = argument.trim_prefix("--equipment-result=")
 run.call_deferred()

func funded_shop(label: String) -> Dictionary:
 var f: Dictionary = super.funded_shop(label)
 if f.is_empty(): return {}
 if not buy(f, "final:G02"):
  dispose(f); return {}
 f.baseline = authority(f) # Real G02 purchase precedes inherited B01 purchases.
 f["g02_h04_holder"] = true
 check(f.session.ledger.model.equipment_runtime_status("final:G02").get("runtime_complete", false) and f.sim.g02_model_is_bound(f.session.ledger.model), "same original G02 source/Model binding")
 return f

func on_event(event: Dictionary, f: Dictionary) -> void:
 var record: Dictionary = {}
 if event.get("kind", "") == "kill" and f.get("g02_h04_holder", false):
  record = {"event":event.duplicate(true), "before":f.session.ledger.model._g02_state().duplicate(true), "witness":f.sim.verify_g02_kill_attribution(f.session.ledger.model, event, f.session.run_id), "original_roster":str(event.target) in f.session.expected_enemies, "owned_copies":owned_count(f, "final:G02")}
 super.on_event(event, f) # The inherited observer submits to Session once.
 if record.is_empty(): return
 record["after"] = f.session.ledger.model._g02_state().duplicate(true)
 # Parent H04 includes a saved-event replay. Only the live original emission
 # can carry a new witness and advance G02; the replay remains unchanged.
 if not record.witness.is_empty():
  check(record.original_roster and record.owned_copies == 1, "actual H04 target enters original Session with G02 held")
  check(int(record.after.progress) == int(record.before.progress) + 1, "original H04 kill adds one ordinary G02 equivalent")
 else:
  check(record.after == record.before, "H04 replay without a live witness cannot advance G02")
 g02_h04_observations.append(record)

func finish() -> void:
 # Retain the original complete H04 contract and assertion accounting.
 check(h04_completed == H04_GROUPS, "all three dedicated H04 groups reached")
 var genuine: Array = g02_h04_observations.filter(func(row: Dictionary): return not row.witness.is_empty())
 check(genuine.size() == 2, "G02 observes exactly two genuine original H04 deaths")
 for row: Dictionary in genuine:
  check(row.event.source == H04_SOURCE and row.witness.get("witness", {}).get("proof", "") == "original_damage_death", "G02 H04 attribution uses actual original damage death frame")
 if genuine.size() == 2:
  check(int(genuine[0].before.progress) == 0 and int(genuine[1].after.progress) == 2 and not genuine[1].after.completed, "same Q2 cast counts both distinct original targets once for G02")
 check(check_records.size() == checks, "every dedicated H04 assertion retained")
 var report: Dictionary = {"suite":"equipment39_g02_b01_original_h04", "passed":failures.is_empty() and h04_completed == H04_GROUPS and genuine.size() == 2, "runtime_status":"EXECUTED", "checks":checks, "failures":failures, "check_records":check_records, "required_groups":H04_GROUPS, "completed_groups":h04_completed, "original_h04_evidence":evidence, "g02_deaths":g02_h04_observations, "source_binding_sha256":FileAccess.get_sha256(Binding.BINDING_PATH), "productionSession":true, "actual_Q2_H04_input":true, "all_prior_H04_assertions_inherited":true, "default_seed_original_Hex_commands":true, "wallet_fixture":true, "source_nonlethal_pre_damage_fixture":true, "extra_actors":false, "native_GUI":false, "natural_play":false, "threshold500_tested_here":false, "production_ready":false}
 var file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
 if file == null: push_error("Unable to write G02 H04 result"); quit(2); return
 file.store_string(JSON.stringify(report, "  "))
 var write_error: Error = file.get_error(); file.close()
 print("EQUIPMENT39_G02_H04 ", JSON.stringify({"passed":report.passed, "checks":checks, "failures":failures, "result":output_path}))
 quit(2 if write_error != OK else (0 if report.passed else 1))
