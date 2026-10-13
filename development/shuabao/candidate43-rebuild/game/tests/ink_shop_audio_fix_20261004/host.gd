extends "res://tests/ink_shop_ui_host_20261004/style27/parsefix01/host.gd"
## Presentation-only lifecycle correction. start_next_room synchronously emits
## the new scope; Router.consume already retires/stops the old scope. A reset
## after that callback would retire the new scope and mute every later cue.
## No reset on rejection, and no global audio/pause/router policy is relaxed.
func _request_next_room() -> void:
 if shop_session==null or _mainprep_required:return
 var result: Dictionary=shop_session.start_next_room()
 if result.accepted:
  shown_enemy_id="";seen_receipts.clear();q1_view.reset_visuals();audio_output.set_paused(sim.paused)
 _record_session_action("next_room",result)
 _refresh_session_controls(true)
