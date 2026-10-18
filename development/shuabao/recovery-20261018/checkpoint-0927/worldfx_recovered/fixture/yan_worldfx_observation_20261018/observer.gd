extends Node
## Passive test fixture. Never emits combat events, drives input, or changes source state.
var entry: Node
var host: Node
var source: Node
var controller: Node
var attach_receipt: Dictionary = {}
var ordinal: int = 0
var before_attach_events: int = 0
var before_attach_kinds: Dictionary = {}
var ready_skill_events_before_attach: int = 0
var kind_counts: Dictionary = {}
var skill_counts: Dictionary = {}
var first_event: Dictionary = {}
var first_skill_event: Dictionary = {}
var pending: Array[Dictionary] = []
var samples: Array[Dictionary] = []
var failures: Array[String] = []
var binding_started_before_attach: bool = false

func attach_to_entry(value: Node) -> void:
	entry = value
	process_priority = -1000
	entry.worldfx_attached.connect(_attached)

func _field(object: Object, key: String) -> Variant:
	if not is_instance_valid(object): return null
	for property: Dictionary in object.get_property_list():
		if str(property.name) == key: return object.get(key)
	return null

func _disconnect_source() -> void:
	if is_instance_valid(source):
		for sink: Callable in [_before_event, _after_event]:
			if source.is_connected("combat_event", sink): source.disconnect("combat_event", sink)

func _bind_source(next: Node) -> void:
	if source == next: return
	if is_instance_valid(source): print_snapshot("source_replaced")
	_disconnect_source()
	source = next
	controller = null
	attach_receipt = {}
	ordinal = 0
	before_attach_events = 0
	before_attach_kinds.clear()
	ready_skill_events_before_attach = 0
	kind_counts.clear(); skill_counts.clear(); first_event.clear(); first_skill_event.clear()
	pending.clear(); samples.clear(); failures.clear()
	binding_started_before_attach = false
	if is_instance_valid(source) and source.has_signal("combat_event"):
		source.connect("combat_event", _before_event)
		binding_started_before_attach = true

func _process(_delta: float) -> void:
	if not is_instance_valid(entry): return
	var next_host: Variant = entry.get("active_room")
	if not is_instance_valid(next_host): return
	host = next_host
	var next_source: Variant = _field(host, "sim")
	if is_instance_valid(next_source): _bind_source(next_source)

func _attached(value: Node3D, receipt: Dictionary) -> void:
	host = entry.get("active_room")
	var prior_source: Node = source
	_bind_source(host.get("sim"))
	if prior_source != source:
		binding_started_before_attach = false
		failures.append("observer_started_late_delivery_order_unproven")
	controller = value
	attach_receipt = receipt.duplicate(true)
	var sink := Callable(controller, "_event")
	var matches: int = 0
	for connection: Dictionary in source.get_signal_connection_list("combat_event"):
		if connection.callable == sink: matches += 1
	if controller.get("source") != source or matches != 1: failures.append("exact_one_original_sink_required")
	# This callback is installed after the original controller sink; before/after
	# samples verify aggregate delivery, not uninstrumented per-view callbacks.
	source.connect("combat_event", _after_event)
	print_snapshot("attached")

func _skill(event: Dictionary) -> String:
	var kind: String = str(event.get("kind", ""))
	for key: String in ["q1", "q2", "q3", "e1", "e2", "e3", "r1", "r2"]:
		if kind.begins_with("ink_" + key + "_") or str(event.get("source", "")) == key: return key.to_upper()
	return "UNCLASSIFIED"

func _before_event(event: Dictionary) -> void:
	ordinal += 1
	var skill: String = _skill(event)
	var row: Dictionary = {"ordinal": ordinal, "kind": str(event.get("kind", "")), "skill": skill, "phase": str(source.get("phase"))}
	for key: String in ["sequence", "source_time", "generation", "room_id", "cast_id", "wave_id", "boat_id", "frame_id", "domain_id", "terrain_id", "reason", "h09", "h10"]:
		var value: Variant = event.get(key)
		if value is String or value is int or value is bool or (value is float and is_finite(value)): row[key] = value
	if not is_instance_valid(controller):
		before_attach_events += 1
		before_attach_kinds[row.kind] = int(before_attach_kinds.get(row.kind, 0)) + 1
		if skill != "UNCLASSIFIED" and is_instance_valid(host) and not bool(host.get("_mainprep_required")) and not bool(host.get("_mainprep_pending")):
			ready_skill_events_before_attach += 1
		return
	row["counter_before"] = int(controller.get("observed_events"))
	pending.append(row)

func _after_event(event: Dictionary) -> void:
	if pending.is_empty(): failures.append("after_without_before"); return
	var row: Dictionary = pending.pop_front()
	row["counter_after"] = int(controller.get("observed_events"))
	row["one_controller_delivery"] = row.counter_after == row.counter_before + 1 and row.kind == str(event.get("kind", ""))
	if not row.one_controller_delivery: failures.append("controller_delivery_mismatch:%s" % row.ordinal)
	kind_counts[row.kind] = int(kind_counts.get(row.kind, 0)) + 1
	if row.skill != "UNCLASSIFIED": skill_counts[row.skill] = int(skill_counts.get(row.skill, 0)) + 1
	row["view_state_after_event"] = _view_state()
	if samples.size() < 128: samples.append(row.duplicate(true))
	if first_event.is_empty():
		first_event = row.duplicate(true)
		print("WORLD_FX_FIRST_EVENT ", JSON.stringify(first_event))
	if row.skill != "UNCLASSIFIED" and first_skill_event.is_empty():
		first_skill_event = row.duplicate(true)
		print("WORLD_FX_FIRST_SKILL_EVENT ", JSON.stringify(first_skill_event))

func _size_or_value(value: Variant) -> Variant:
	if value is Dictionary or value is Array: return value.size()
	if value is String or value is bool or value is int: return value
	return null

func _listeners() -> Array:
	var result: Array = []
	if not is_instance_valid(source): return result
	for connection: Dictionary in source.get_signal_connection_list("combat_event"):
		var sink: Callable = connection.callable
		var target: Object = sink.get_object()
		if not is_instance_valid(target): continue
		result.append({"instance_id": target.get_instance_id(), "method": str(sink.get_method()),
			"script": target.get_script().resource_path if target.get_script() != null else "", "flags": connection.flags})
	return result

func _view_state() -> Dictionary:
	var result: Dictionary = {}
	if not is_instance_valid(controller): return result
	for key: String in ["q1", "q2", "q3", "e2", "e3", "r1", "r2"]:
		var view: Variant = controller.get(key)
		if not is_instance_valid(view): result[key] = {"exists": false}; continue
		var row: Dictionary = {"exists": true, "script": view.get_script().resource_path, "has_receive_source": view.has_method("receive_source"), "has_present_source": view.has_method("present_source")}
		for field: String in ["_drawn", "rows", "seen_events", "wakes", "bursts", "seen", "transient", "identity", "flakes", "peaks", "warnings", "fallback_required"]:
			var value: Variant = _field(view, field)
			if value != null: row[field] = _size_or_value(value)
			if value is Dictionary and field in ["_drawn", "rows", "seen_events", "seen"]: row[field + "_keys"] = value.keys().slice(0, 16)
		result[key] = row
	result["e1"] = {"mode": "INHERITED_SOURCE_PRESENTER_NOT_WORLD_FX_CHILD"}
	for key: String in ["q2_river_view", "e2_boat_view"]:
		var legacy: Variant = _field(host, key)
		result[key] = {"valid": is_instance_valid(legacy), "visible": bool(legacy.get("visible")) if is_instance_valid(legacy) else false}
	return result

func snapshot() -> Dictionary:
	return {"scope": "PASSIVE_WIRING_OBSERVATION_ONLY", "art_acceptance": "NOT_REVIEWED", "native_input_proven": false,
		"attachment": attach_receipt.duplicate(true), "observer_started_before_attach": binding_started_before_attach,
		"source_events_before_attach": before_attach_events, "ready_skill_events_before_attach": ready_skill_events_before_attach,
		"before_attach_event_kinds": before_attach_kinds.duplicate(true), "current_source_listeners": _listeners(),
		"events_by_kind": kind_counts.duplicate(true), "classified_skill_events": skill_counts.duplicate(true),
		"first_event": first_event.duplicate(true), "first_skill_event": first_skill_event.duplicate(true),
		"view_state": _view_state(), "samples": samples.duplicate(true), "failures": failures.duplicate(),
		"not_observed_is_not_pass": true, "per_view_callback_delivery_claimed": false}

func print_snapshot(label: String) -> void:
	print("WORLD_FX_OBSERVATION ", label, " ", JSON.stringify(snapshot()))

func _exit_tree() -> void:
	print_snapshot("observer_exit")
	_disconnect_source()
