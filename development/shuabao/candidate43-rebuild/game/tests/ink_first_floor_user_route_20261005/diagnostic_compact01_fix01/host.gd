extends "res://tests/ink_first_floor_user_route_20261005/gesture06_host01/parsefix01/host.gd"
## Diagnostic-output-only leaf. Rendering/pose/UI/input/source/F8 sampling inherit.
const ProofStore = preload("res://tests/ink_first_floor_user_route_20261005/diagnostic_compact01_fix01/proof_store.gd")
const DIAGNOSTIC_ROOT := "res://tests/ink_first_floor_user_route_20261005/diagnostic_compact01_fix01/"
var proof_store: RefCounted
var diagnostic_writes := 0
var diagnostic_bytes := 0
var diagnostic_last: Dictionary = {}

func _ensure_proof_store() -> void:
 if proof_store == null: proof_store = ProofStore.new()
 proof_store.configure(evidence_dir)
 if is_instance_valid(hero_view): proof_store.prime_actor(hero_view.proof)

func gesture_host_report() -> Dictionary:
 return {"scope":"new_user_route_navigation_and_actor_only_gesture06_leaf","installed":gesture_installed,"installation":gesture_installation,"actor_script":hero_view.get_script().resource_path if is_instance_valid(hero_view) else "","intent_state":hero_view.sample_report.get("q1_intent",{}).duplicate(true) if gesture_installed else {},"intent_consumer":IntentReporter.capture(hero_view) if gesture_installed else {},"actual_actor_sample_upper":hero_view.sample_report.get("upper","") if gesture_installed else "","handoff_instantiated":false,"new_effects_added":false,"effect_retained":"effect05","binding_sha256":FileAccess.get_sha256(GESTURE_ROOT+"source_binding.json") if FileAccess.file_exists(GESTURE_ROOT+"source_binding.json") else "PENDING","art_accepted":false,"native_input_passed":false,"full_floor_passed":false}


func diagnostic_logical_output(contents: Dictionary) -> Dictionary:
 var output: Dictionary = contents.duplicate(false)
 output["gesture06_host"] = gesture_host_report()
 output["new_user_route_host"] = user_route_report()
 output["q1_native_wip"] = flow_native_report()
 output["audio_candidate"] = {"id":"ink_composed_audio_fix01_20261005","binding":FileAccess.get_sha256(AUDIO_ROOT+"source_binding.json"),"installed":audio_candidate_installed,"router":audio_output.router.snapshot() if is_instance_valid(audio_output) and audio_output.router != null else {},"new_Q3_authored_cues":true,"hardware_listening":false,"audio_quality_accepted":false}
 output["scope"] = _session_scope()
 output["first_battle_composition"] = composition_report()
 output["normal_floor"] = {"status":"NEW_30_NODE_USER_ROUTE_CANDIDATE","binding":FileAccess.get_sha256(ROUTE_HOST_ROOT+"source_binding.json"),"ancestor_floor_binding":FileAccess.get_sha256(REWARD_ROOT+"source_binding.json"),"flow":shop_session.snapshot() if shop_session != null else {},"enemies":enemy_layer.report if is_instance_valid(enemy_layer) else {},"q3":mountain_view.get_diagnostics() if is_instance_valid(mountain_view) else {},"preview":aim_preview.sample if is_instance_valid(aim_preview) else {},"dropped_history":dropped_history.duplicate(),"reward":_commerce_evidence(),"full_floor_passed":false,"native_art_performance_passed":false,"q3_gesture_imported":_actor_is_composed() and hero_view.q3_bound,"legacy_enemy_metrics_are_empty_anchor":true}
 return output

func diagnostic_write_logical(filename: String, logical: Dictionary) -> Dictionary:
 if evidence_dir.is_empty(): return {"accepted":false,"reason":"evidence_directory_required"}
 _ensure_proof_store()
 var packed: Dictionary = proof_store.pack(logical)
 if not proof_store.errors.is_empty():
  push_error("diagnostic_proof_store_failed:"+str(proof_store.errors))
  return {"accepted":false,"reason":"proof_store_failed"}
 var storage: Dictionary = proof_store.statistics()
 storage["diagnostic_source_binding_sha256"] = FileAccess.get_sha256(DIAGNOSTIC_ROOT+"source_binding.json")
 packed["_diagnostic_storage"] = storage
 var encoded: String = JSON.stringify(packed,"  ",true,false)
 var file: FileAccess = FileAccess.open(evidence_dir.path_join(filename),FileAccess.WRITE)
 if file == null:
  push_error("diagnostic_report_write_failed:"+filename)
  return {"accepted":false,"reason":"report_write_failed"}
 file.store_string(encoded); file.flush(); file.close()
 diagnostic_writes += 1; diagnostic_bytes += encoded.to_utf8_buffer().size()
 return {"accepted":true,"bytes":encoded.to_utf8_buffer().size(),"proofs":proof_store.statistics()}

func _write_json(filename: String, contents: Dictionary) -> void:
 if evidence_dir.is_empty(): return
 # Bypass only the two proof-amplifying wrappers; assemble their same fields once.
 # F8 frame JSONL, snapshots/digests, capture rate/caps and journal policy are untouched.
 var started: int = Time.get_ticks_usec()
 var heap_before: int = int(Performance.get_monitor(Performance.MEMORY_STATIC))
 var logical: Dictionary = diagnostic_logical_output(contents)
 var result: Dictionary = diagnostic_write_logical(filename,logical)
 diagnostic_last = {"filename":filename,"accepted":result.get("accepted",false),"wall_usec":Time.get_ticks_usec()-started,"tracked_heap_before":heap_before,"tracked_heap_after":int(Performance.get_monitor(Performance.MEMORY_STATIC)),"scope":"engine tracked heap at boundaries, not per-call peak or whole-cgroup RSS causality"}
