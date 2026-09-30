class_name CombatHUDAdapter
extends RefCounted
## Read-only presentation boundary. Caller remains authoritative for all game state.
signal request_emitted(request: Dictionary)
signal snapshot_changed(snapshot: Dictionary)
signal feedback_emitted(event: Dictionary)
var state: Dictionary = {}
var serial := 0
var session_id := str(Time.get_ticks_usec())

func present(snapshot: Dictionary) -> void:
	state = snapshot.duplicate(true)
	snapshot_changed.emit(state.duplicate(true))

func feedback(event: Dictionary) -> void:
	feedback_emitted.emit(event.duplicate(true))

func request(action: String, payload: Dictionary = {}) -> void:
	serial += 1
	var command := payload.duplicate(true)
	command.merge({"action": action, "actor_id": state.get("actor_id", "local"),
		"command_id": "ui-%s-%s-%d" % [state.get("actor_id", "local"), session_id, serial],
		"state_revision": state.get("revision", 0)}, true)
	request_emitted.emit(command)
