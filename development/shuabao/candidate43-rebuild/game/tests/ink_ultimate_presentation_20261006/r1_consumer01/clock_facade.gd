extends RefCounted
## Legacy-shaped readback. Only the inherited core's step call consumes time.
const Authority = preload("res://scripts/combat/ultimate_presentation_clock.gd")
var domain
var world_time: float = 0.0
var world_offset: float = 0.0
var tickets: int = 0
var advances: int = 0
var ticket: Dictionary = {}
var _owner: WeakRef
var _authoring: Dictionary = {}

func _init(sim, authoring: Dictionary) -> void:
	_owner = weakref(sim)
	_authoring = authoring.duplicate(true)
	domain = Authority.new(_scope(), _authoring)

func _scope() -> Dictionary:
	var sim = _owner.get_ref()
	return {"owner_id": "yanguizhou-consumer:" + str(sim.get_instance_id()), "room_id": sim.room_id, "generation": sim.encounter_generation}

func bind_room() -> bool:
	var expected: Dictionary = _scope()
	if domain.snapshot()["scope"] == expected:
		return domain.configuration_ready()
	world_offset = world_time
	return domain.reset_scope(expected)

func clear() -> void:
	for record: Dictionary in domain.snapshot()["presentations"].values():
		domain.end_presentation(record["token"])
	# Keep the in-flight ticket: a terminal callback must not erase its receipt.

func scale_factor() -> float:
	return 1.0 if domain.snapshot()["presentations"].is_empty() else float(_authoring["world_slow_factor"])

func next_budget(available: float) -> float:
	var state: Dictionary = domain.snapshot()
	var result: float = available
	for record: Dictionary in state["presentations"].values():
		result = minf(result, maxf(0.0, float(record["expires_at"]) - float(state["active_real_time"])))
	return result

func arm(real_dt: float) -> Dictionary:
	tickets += 1
	var sim = _owner.get_ref()
	ticket = {"id": tickets, "scope": sim._ink_scope(), "real_dt": real_dt, "consumed": false, "frame": {}}
	return ticket

func step(real_dt: float, active: bool) -> float:
	var sim = _owner.get_ref()
	if not active or sim.paused or ticket.is_empty() or not sim._ink_scope_current(ticket["scope"]):
		return 0.0
	if ticket.is_empty() or bool(ticket.get("consumed", false)) or absf(real_dt - float(ticket["real_dt"])) > 0.000000001:
		sim.presentation_fail("core_time_ticket_mismatch")
		return 0.0
	var frame: Dictionary = domain.advance(real_dt, [sim.hero.actor_id], false)
	if not frame.get("ok", false) or frame["segments"].size() != 1:
		sim.presentation_fail("core_slice_not_single_or_invalid")
		return 0.0
	ticket["consumed"] = true
	ticket["frame"] = frame
	advances += 1
	world_time = world_offset + float(frame["world_time"])
	sim.presentation_accept_slice(frame, ticket)
	return float(frame["world_dt"])
