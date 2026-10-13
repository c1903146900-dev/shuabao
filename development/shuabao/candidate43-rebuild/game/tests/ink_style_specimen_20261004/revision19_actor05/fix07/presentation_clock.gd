extends RefCounted
## Host-owned presentation time. Never owns a simulation or edits a snapshot.
var instance_id: int = -1
var scope: Dictionary = {}
var safe_elapsed: float = 0.0
var safe_serial: int = 0
var last_tick_delta: float = 0.0
var reset_serial: int = 0

func _sync(context: Dictionary) -> void:
	var next_instance: int = int(context.get("instance_id", -1))
	var next_scope: Dictionary = context.get("scope", {})
	if next_instance != instance_id or next_scope != scope:
		instance_id = next_instance; scope = next_scope.duplicate(true)
		safe_elapsed = 0.0; safe_serial = 0; last_tick_delta = 0.0; reset_serial += 1

static func eligible(context: Dictionary) -> bool:
	return int(context.get("instance_id", -1)) >= 0 and str(context.get("phase", "")) in ["preparation", "victory"] and not bool(context.get("paused", true)) and not bool(context.get("dead", true)) and not bool(context.get("loading", true)) and not bool(context.get("finished", true)) and not bool(context.get("shop_open", true))

func observe_safe_tick(delta: float, context: Dictionary) -> bool:
	_sync(context)
	if not eligible(context) or not is_finite(delta) or delta <= 0.0: return false
	safe_elapsed += delta; safe_serial += 1; last_tick_delta = delta
	return true

func capture(context: Dictionary) -> Dictionary:
	_sync(context)
	return {"schema": "safe-locomotion-presentation-1", "instance_id": instance_id,
		"scope": scope.duplicate(true), "phase": str(context.get("phase", "")),
		"eligible": eligible(context), "safe_elapsed": safe_elapsed, "safe_serial": safe_serial,
		"last_tick_delta": last_tick_delta, "reset_serial": reset_serial,
		"clock_basis": "sum of eligible actual free_move process deltas; presentation only",
		"source_time_modified": false}
