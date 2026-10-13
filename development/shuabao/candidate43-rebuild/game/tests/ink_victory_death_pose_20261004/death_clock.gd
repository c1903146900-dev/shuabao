extends RefCounted
## Presentation-only cursor. Inputs are copied facts, never a simulation object.
var binding: Dictionary = {}
var safe_seen: float = 0.0
var serial_seen: int = 0
var source_seen: float = -1.0
var safe_age: float = 0.0
var pose_time: float = 0.0
var flash: float = 0.0
var report: Dictionary = {}

func clear() -> void:
	binding.clear(); safe_seen = 0.0; serial_seen = 0; source_seen = -1.0
	safe_age = 0.0; pose_time = 0.0; flash = 0.0; report.clear()

func sample(identity: Dictionary, source_time: float, native_age: float,
		context: Dictionary, blocked: bool, contact_time: float, duration: float) -> Dictionary:
	var elapsed: float = float(context.get("safe_elapsed", 0.0))
	var serial: int = int(context.get("safe_serial", 0))
	if not is_finite(source_time) or not is_finite(native_age) or not is_finite(elapsed) or not is_finite(duration) or duration <= 0.0 or elapsed < 0.0 or serial < 0:
		return {"status": "HOLD_invalid_clock", "pose_override": false}
	var reset: bool = identity != binding or source_time < source_seen or elapsed < safe_seen or serial < serial_seen
	var phase: String = str(context.get("phase", ""))
	var can_finish: bool = not blocked and phase == "victory" and bool(context.get("eligible", false)) and context.get("schema", "") == "safe-locomotion-presentation-1"
	var delta: float = 0.0
	if reset:
		binding = identity.duplicate(true); safe_age = 0.0
		pose_time = clampf(native_age, 0.0, duration)
	elif not blocked and phase == "combat":
		# Existing combat death cursor is source-derived, exactly as before.
		safe_age = 0.0; pose_time = clampf(native_age, 0.0, duration)
	elif can_finish:
		if serial > serial_seen:
			delta = minf(maxf(0.0, elapsed - safe_seen), maxf(0.0, duration - native_age - safe_age))
		safe_age += delta
		pose_time = clampf(native_age + safe_age, 0.0, duration)
	if reset or (not blocked and (phase == "combat" or can_finish)):
		var contact_age: float = source_time - contact_time + safe_age
		flash = 0.12 if contact_age >= 0.0 and contact_age < 0.075 else 0.0
	# Consume observations even while blocked; no deferred/catch-up pause time.
	safe_seen = elapsed; serial_seen = serial; source_seen = source_time
	report = {"status": "dead_visual_only", "binding": binding.duplicate(true),
		"source_time": source_time, "native_death_age": native_age, "death_pose_time": pose_time,
		"death_length": duration, "death_finished": pose_time >= duration,
		"safe_death_elapsed": safe_age, "accepted_safe_delta": delta,
		"safe_serial": serial, "safe_elapsed": elapsed, "lifecycle_reset": reset,
		"frozen": blocked or (phase != "combat" and not can_finish),
		"pose_override": phase != "combat", "hit_flash": flash,
		"clock_basis": "source death age plus observed eligible victory free_move deltas",
		"source_time_modified": false, "source_state_modified": false}
	return report.duplicate(true)
