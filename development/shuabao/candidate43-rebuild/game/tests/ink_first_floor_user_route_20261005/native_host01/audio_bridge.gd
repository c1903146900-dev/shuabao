extends "res://tests/ink_first_floor_user_route_20261005/native_host01/composed_bridge.gd"
## Opt-in audio presentation candidate; no simulation/input/timing/AI changes.
const CandidateAudioRouter = preload("res://tests/ink_composed_audio_fix01_20261005/router.gd")
const OriginalAudioRouter = preload("res://tests/ink_benchmark_audio_20261004/router.gd")
const AUDIO_ROOT := "res://tests/ink_composed_audio_fix01_20261005/"
var audio_candidate_installed: bool = false
func _start_encounter() -> void:
 # Original AudioOutput is already ready; preserve its exact bus, players,
 # capture, voice budget and stream loading. Install only before first source.
 if shop_session == null and not audio_candidate_installed:
  if is_instance_valid(audio_output) and audio_output.get_script() == AudioOutput and audio_output.router != null and audio_output.router.get_script() == OriginalAudioRouter and audio_output.router.event_room.is_empty() and audio_output.router.history.is_empty():
   audio_output.router = CandidateAudioRouter.new()
   audio_candidate_installed = true
  else:
   push_error("audio_candidate_requires_exact_fresh_original_output_and_router")
 super._start_encounter()

func _request_next_room() -> void:
 if _mainprep_required or finished or shop_session == null: return
 var checked: Dictionary = shop_session.next_room_preflight()
 if checked.accepted: checked = enemy_layer.preflight(checked.node.payload)
 if not checked.accepted: _transition_result("enter_selected_node",checked); return
 var result: Dictionary = shop_session.enter_selected_node()
 if result.accepted:
  enemy_layer.reset_scope(); enemy_layer.reader.capture(sim)
  q1_view.reset_visuals(); mountain_view.reset_visuals(); q3_pending.clear(); h02_pending.clear(); seen_receipts.clear()
  if is_instance_valid(h02_view): h02_view.reset_visuals()
  audio_output.set_paused(sim.paused)
 _transition_result("enter_selected_node",result)
 _refresh(0.0)

func _write_json(filename: String,contents: Dictionary) -> void:
 var output: Dictionary = contents.duplicate(true)
 output["audio_candidate"] = {"id":"ink_composed_audio_fix01_20261005","binding":FileAccess.get_sha256(AUDIO_ROOT+"source_binding.json"),"installed":audio_candidate_installed,"router":audio_output.router.snapshot() if is_instance_valid(audio_output) and audio_output.router != null else {},"new_Q3_authored_cues":true,"hardware_listening":false,"audio_quality_accepted":false}
 super._write_json(filename,output)
