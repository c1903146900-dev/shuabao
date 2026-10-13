extends RefCounted
## Detached presentation-only router. Host must feed the actual synchronous
## combat_event packet plus a fresh ink_presenter_snapshot. Never give this
## object a sim, RNG, target object, gameplay method or input event.
const Bank = preload("res://tests/ink_benchmark_audio_20261004/bank.gd")
const RULES_HASH := "aef68e35a4becc25fcfa4158cfc2d55ee538a942023f99b7e7cefb07dac7cf53"
const RELEASE_FIELDS := ["cast_id", "wave_id", "path", "path_length", "front_distance", "front_position", "front_direction", "segment_index", "width", "speed", "released_at", "source", "generation", "room_id", "travel_fraction", "hit_target_ids"]
const RECEIPT_FIELDS := ["receipt_id", "cast_id", "wave_id", "target_id", "contact_position", "target_contact_position", "contact_time", "settled_at", "direction", "segment_index", "segment_id", "actual_damage", "critical", "source", "room_id", "generation", "released_at", "path_length"]
var paused := false
var ended := false
var event_room := ""
var generation := -1
var last_sequence := -1
var retired_scopes: Dictionary = {}
var release_seen: Dictionary = {}
var receipt_seen: Dictionary = {}
var contact_seen: Dictionary = {}
var dash_seen: Dictionary = {}
var counts: Dictionary = {}
var rejected: Dictionary = {}
var history: Array = []

func _scope(room: String, gen: int) -> String:
	return "%s:%d" % [room, gen]
func _remember(book: Dictionary, key: String, value: Variant = true) -> void:
	book[key] = value
	if book.size() > 256: book.erase(book.keys()[0])
func _reject(reason: String) -> Array:
	rejected[reason] = int(rejected.get(reason, 0)) + 1
	return []
func _stop(reason: String) -> Array:
	return [{"action":"stop_all", "reason":reason}]
func set_paused(value: bool) -> Array:
	if paused == value: return []
	paused = value
	return _stop("pause") if paused else []
func clear(reason: String = "host_clear") -> Array:
	# Focus loss is not a new source generation. Retain all identity fences;
	# stopping sound must never make an old packet playable a second time.
	return _stop(reason)
func reset() -> Array:
	# A restarted sim needs a unique room ID or a higher source generation.
	if not event_room.is_empty(): _remember(retired_scopes, _scope(event_room, generation))
	event_room = ""; generation = -1; last_sequence = -1; ended = false
	release_seen.clear(); receipt_seen.clear(); contact_seen.clear(); dash_seen.clear()
	return _stop("reset")
func _matching(event: Dictionary, row: Dictionary, fields: Array) -> bool:
	for key in fields:
		if not event.has(key) or not row.has(key) or event[key] != row[key]: return false
	return true
func _find_match(event: Dictionary, rows: Array, fields: Array) -> bool:
	for row in rows:
		if row is Dictionary and _matching(event, row, fields): return true
	return false
func _variant(key: String) -> int:
	# FNV-1a over UTF-8. Does not touch gameplay RNG or Godot's hash seed.
	var value: int = 2166136261
	for byte in key.to_utf8_buffer(): value = ((value ^ int(byte)) * 16777619) & 0xffffffff
	return value % Bank.VARIANTS
func _cue(id: String, event: Dictionary, state: Dictionary, identity: String, clock: String, at: float, point: Variant) -> Dictionary:
	var variant: int = _variant(identity)
	var command := {"action":"play", "id":id, "path":Bank.path_for(id, variant), "variant_index":variant,
		"gain_db":Bank.GAIN_DB, "max_voices":Bank.MAX_VOICES, "loop":false, "pitch_scale":1.0,
		"cast_key":"%s:%d:%s" % [event_room, generation, str(event.get("cast_id", -1))],
		"identity":identity, "room_id":event_room, "generation":generation, "sequence":int(event.sequence),
		"source_clock":clock, "source_time":at, "observed_source_time":float(state.source_time),
		"settled_at":float(event.get("settled_at", state.source_time)), "world_time":float(event.get("world_time", state.world_time)),
		"receipt_id":str(event.get("receipt_id", "")), "wave_id":str(event.get("wave_id", "")),
		"position":point, "priority":2 if id in ["ink_basic_contact", "ink_basic_critical", "ink_q1_contact"] else 0 if id == "ink_q1_body" else 1}
	counts[id] = int(counts.get(id, 0)) + 1
	history.append(command.duplicate(true))
	if history.size() > 64: history.pop_front()
	return command
func consume(event: Dictionary, state: Dictionary) -> Array:
	if str(state.get("schema", "")) != "ink-q1-presenter-1" or str(state.get("rules_hash", "")) != RULES_HASH:
		return _reject("unbound_snapshot")
	var scope: Dictionary = state.get("scope", {})
	var room := str(event.get("room_id", ""))
	var gen := int(event.get("generation", -1))
	var seq := int(event.get("sequence", -1))
	if room.is_empty() or gen < 0 or seq < 0 or room != str(scope.get("room_id", "")) or gen != int(scope.get("generation", -1)):
		return _reject("scope_or_sequence")
	if retired_scopes.has(_scope(room, gen)) or (generation >= 0 and gen < generation): return _reject("retired_scope")
	var output: Array = []
	if room != event_room or gen != generation:
		if not event_room.is_empty():
			_remember(retired_scopes, _scope(event_room, generation)); output.append_array(_stop("scope_changed"))
		event_room = room; generation = gen; last_sequence = -1; ended = false
		release_seen.clear(); receipt_seen.clear(); contact_seen.clear(); dash_seen.clear()
	if seq <= last_sequence: return _reject("duplicate_or_old_sequence")
	last_sequence = seq
	var kind := str(event.get("kind", ""))
	if kind in ["encounter_finished", "hero_died", "hero_death"]:
		ended = true; output.append_array(_stop(kind)); return output
	if ended: return output
	# Preview/armed/frozen/cancel, generic damage, kills and all unsupported
	# skill families are deliberately silent. Contact owns its own sound.
	if kind not in ["ink_basic_released", "ink_q1_released", "ink_basic_contact", "ink_q1_contact", "dash"]: return output
	if bool(event.get("preview_only", false)): return _reject("preview_packet")
	var cast_id := int(event.get("cast_id", -1))
	if cast_id < 0: return _reject("missing_cast")
	if kind in ["ink_basic_released", "ink_q1_released"]:
		var q1 := kind == "ink_q1_released"
		var wave := str(event.get("wave_id", ""))
		var source := str(event.get("source", ""))
		if wave.is_empty() or (source != "q1" if q1 else source not in ["attack", "dash_attack"]): return _reject("release_family")
		var rows: Array = state.get("waves" if q1 else "basics", [])
		if not _find_match(event, rows, RELEASE_FIELDS): return _reject("release_not_in_snapshot")
		if release_seen.has(wave): return _reject("duplicate_release")
		var at := float(event.released_at)
		if not is_finite(at) or at < 0.0 or at > float(state.source_time) + .00001: return _reject("release_time")
		_remember(release_seen, wave, {"cast_id":cast_id, "source":source})
		if paused: return output
		output.append(_cue("ink_q1_release" if q1 else "ink_basic_release", event, state, wave, "hero", at, event.front_position))
		if q1: output.append(_cue("ink_q1_body", event, state, wave, "hero", at, event.front_position))
	elif kind in ["ink_basic_contact", "ink_q1_contact"]:
		var receipt := str(event.get("receipt_id", ""))
		var wave := str(event.get("wave_id", ""))
		var target := str(event.get("target_id", ""))
		var contact_key := wave + ":target:" + target
		if receipt.is_empty() or wave.is_empty() or target.is_empty(): return _reject("missing_contact_identity")
		if not release_seen.has(wave): return _reject("contact_without_release")
		if not _find_match(event, state.get("receipts", []), RECEIPT_FIELDS): return _reject("contact_not_in_snapshot")
		var release: Dictionary = release_seen[wave]
		var source := str(event.get("source", ""))
		if cast_id != int(release.cast_id) or source != str(release.source) or (source != "q1" if kind == "ink_q1_contact" else source not in ["attack", "dash_attack"]): return _reject("contact_family")
		var damage := float(event.actual_damage)
		var at := float(event.contact_time)
		var settled := float(event.settled_at)
		if not is_finite(damage) or damage <= 0.0: return _reject("nonpositive_contact")
		if not is_finite(at) or not is_finite(settled) or at < float(event.released_at) - .00001 or at > settled + .00001 or settled > float(state.source_time) + .00001: return _reject("contact_time")
		if receipt_seen.has(receipt) or contact_seen.has(contact_key): return _reject("duplicate_contact")
		_remember(receipt_seen, receipt); _remember(contact_seen, contact_key)
		if paused: return output
		var id := "ink_q1_contact" if kind == "ink_q1_contact" else "ink_basic_critical" if bool(event.critical) else "ink_basic_contact"
		output.append(_cue(id, event, state, receipt, "hero", at, event.contact_position))
	else:
		var dash_id := int(event.get("dash_id", -1))
		var at := float(event.get("real_time", -1.0))
		if dash_id < 0 or at < 0.0 or not is_finite(at) or float(event.get("duration", 0.0)) <= 0.0 or float(state.get("hero", {}).get("dash_left", 0.0)) <= 0.0: return _reject("inactive_dash")
		var key := "%s:%d:dash:%d" % [room, gen, dash_id]
		if dash_seen.has(key): return _reject("duplicate_dash")
		_remember(dash_seen, key)
		if not paused: output.append(_cue("ink_shift_scatter", event, state, key, "real", at, event.get("position", Vector3.ZERO)))
	return output
func snapshot() -> Dictionary:
	return {"scope":{"room_id":event_room,"generation":generation}, "last_sequence":last_sequence, "paused":paused, "ended":ended,
		"counts":counts.duplicate(true), "rejected":rejected.duplicate(true), "history":history.duplicate(true),
		"max_voices":Bank.MAX_VOICES, "hardware_listening":false, "runtime_or_pcm_qualification_inherited":false}
