extends RefCounted
## Pure server-owned actor record. No peers, credentials, held input or Physics RIDs.
const Inputs = preload("res://scripts/actor/actor_inputs.gd")
const Address = preload("res://scripts/world/spatial_address.gd")
# Technical double-clock precision ceiling (about 136 years), not a gameplay timer.
# At this ceiling a microsecond still advances the clock; enormous finite clocks do not.
const MAX_CLOCK_SECONDS := 4294967296.0
const MAX_POSITION_COMPONENT := 2147483647.0
const DIRECTION_TOLERANCE := 0.000001
const FIELDS := ["actor_id", "layer", "position", "fallback", "updated_at", "health", "food", "energy", "last_valid_move", "food_anchor_at", "food_anchor_value", "health_anchor_value", "energy_anchor_at", "energy_anchor_value", "last_consumption_at", "dodge_started_at", "dodge_until", "invulnerable_until", "dodge_cooldown_until", "dodge_direction", "dodge_start_position", "dodge_last_position", "rooted_until", "hit_feedback_until"]
const TIMERS := ["updated_at", "food_anchor_at", "energy_anchor_at", "dodge_until", "invulnerable_until", "dodge_cooldown_until", "rooted_until", "hit_feedback_until"]

static func create(actor_id: String, layer: Dictionary, position: Vector2, fallback: Dictionary, now: float, settings: RefCounted) -> Dictionary:
	if not settings.ready or not valid_clock(now) or not position.is_finite():
		return error("INVALID_ACTOR_CREATION")
	var record := {
		"actor_id": actor_id, "layer": layer.duplicate(true), "position": pair(position), "fallback": fallback.duplicate(true),
		"updated_at": now, "health": settings.parameter("health_max"), "food": settings.parameter("food_max"), "energy": settings.parameter("energy_max"),
		"last_valid_move": [0.0, 0.0], "food_anchor_at": now, "food_anchor_value": settings.parameter("food_max"), "health_anchor_value": settings.parameter("health_max"),
		"energy_anchor_at": now, "energy_anchor_value": settings.parameter("energy_max"), "last_consumption_at": -1.0,
		"dodge_started_at": -1.0, "dodge_until": 0.0, "invulnerable_until": 0.0, "dodge_cooldown_until": 0.0, "dodge_direction": [0.0, 0.0],
		"dodge_start_position": pair(position), "dodge_last_position": pair(position), "rooted_until": 0.0, "hit_feedback_until": 0.0,
	}
	var checked := validate(record, settings, layer.get("world_id", ""), now)
	return {"ok": true, "record": record} if checked["ok"] else checked

static func validate(value: Variant, settings: RefCounted, world_id: String, maximum_clock: float) -> Dictionary:
	if value is Dictionary:
		for field in value:
			if field not in FIELDS:
				return error("ACTOR_RECORD_INCOMPATIBLE_FIELDS", "incompatible")
	if not settings.ready or not valid_clock(maximum_clock) or not exact_fields(value, FIELDS):
		return error("INVALID_ACTOR_RECORD")
	if not SandboxServerAuthority._valid_id(value["actor_id"], "entity_player_") or not Address.valid_layer(value["layer"]) or value["layer"]["world_id"] != world_id:
		return error("INVALID_ACTOR_ID_OR_LAYER")
	if not valid_pair(value["position"]) or not exact_fields(value["fallback"], ["layer", "position"]) or not Address.valid_layer(value["fallback"]["layer"]) or value["fallback"]["layer"]["world_id"] != world_id or not valid_pair(value["fallback"]["position"]):
		return error("INVALID_ACTOR_POSITION_OR_FALLBACK")
	for field in TIMERS:
		if not valid_clock(value[field]):
			return error("INVALID_ACTOR_TIMER")
	if value["updated_at"] > maximum_clock or value["food_anchor_at"] > value["updated_at"]:
		return error("ACTOR_CLOCK_AHEAD")
	for field in ["last_consumption_at", "dodge_started_at"]:
		if not Inputs.number(value[field]) or (value[field] != -1.0 and (not valid_clock(value[field]) or value[field] > value["updated_at"])):
			return error("INVALID_ACTOR_ACTION_CLOCK")
	for field in ["health", "food", "energy", "food_anchor_value", "health_anchor_value", "energy_anchor_value"]:
		var cap_name: String = "food_max" if field.begins_with("food") else ("health_max" if field.begins_with("health") else "energy_max")
		if not Inputs.number(value[field]) or value[field] < 0.0 or value[field] > settings.parameter(cap_name):
			return error("ACTOR_RESOURCE_OUTSIDE_CAP")
	for field in ["last_valid_move", "dodge_direction"]:
		if not valid_direction(value[field]):
			return error("INVALID_ACTOR_DIRECTION")
	for field in ["dodge_start_position", "dodge_last_position"]:
		if not valid_pair(value[field]):
			return error("INVALID_DODGE_POSITION")
	if value["dodge_started_at"] == -1.0:
		if value["dodge_until"] != 0.0 or value["invulnerable_until"] != 0.0 or value["dodge_cooldown_until"] != 0.0 or vector(value["dodge_direction"]) != Vector2.ZERO:
			return error("DODGE_WITHOUT_START")
	else:
		if vector(value["dodge_direction"]) == Vector2.ZERO:
			return error("DODGE_WITHOUT_DIRECTION")
		for rule in [["dodge_until", "dodge_duration_seconds"], ["invulnerable_until", "dodge_invulnerability_seconds"], ["dodge_cooldown_until", "dodge_cooldown_seconds"]]:
			if not near_number(float(value[rule[0]]), float(value["dodge_started_at"]) + settings.parameter(rule[1])):
				return error("DODGE_TIMER_CONTRACT_CHANGED")
	if value["last_consumption_at"] == -1.0:
		if value["energy_anchor_at"] > value["updated_at"]:
			return error("REGEN_DELAY_WITHOUT_CONSUMPTION")
	else:
		var delay_end: float = float(value["last_consumption_at"]) + settings.parameter("energy_regeneration_delay_seconds")
		# Settlement can re-anchor after an inactive interval without fabricating a
		# new consumption or moving any absolute action deadline.
		if value["energy_anchor_at"] < delay_end or value["energy_anchor_at"] > maxf(float(value["updated_at"]), delay_end):
			return error("ENERGY_DELAY_CONTRACT_CHANGED")
	var derived := resources_at(value, float(value["updated_at"]), settings)
	if (float(value["health"]) == 0.0) != (float(derived["health"]) == 0.0):
		return error("ACTOR_DEATH_ANCHOR_MISMATCH")
	for field in ["health", "food", "energy"]:
		if not near_number(float(value[field]), float(derived[field])):
			return error("ACTOR_RESOURCE_ANCHOR_MISMATCH")
	return {"ok": true}

static func resources_at(record: Dictionary, now: float, settings: RefCounted) -> Dictionary:
	# Analytic anchors avoid applying the final food multiplier to an entire tick,
	# and avoid accumulating food/resource subtraction once per render/physics tick.
	var decay: float = settings.parameter("food_decay_per_second")
	var loss: float = settings.parameter("starvation_health_loss_per_second")
	var zero_after: float = float(record["food_anchor_value"]) / decay if decay > 0.0 else (0.0 if record["food_anchor_value"] == 0.0 else INF)
	var death_after: float = zero_after + float(record["health_anchor_value"]) / loss if loss > 0.0 else INF
	if record["health_anchor_value"] == 0.0:
		death_after = 0.0
	var elapsed: float = minf(maxf(0.0, now - float(record["food_anchor_at"])), death_after)
	var active_until: float = minf(now, float(record["food_anchor_at"]) + death_after)
	var health: float = maxf(0.0, float(record["health_anchor_value"]) - maxf(0.0, elapsed - zero_after) * loss)
	if elapsed >= death_after:
		health = 0.0
	return {
		"health": health, "food": maxf(0.0, float(record["food_anchor_value"]) - elapsed * decay),
		"energy": minf(settings.parameter("energy_max"), float(record["energy_anchor_value"]) + maxf(0.0, active_until - float(record["energy_anchor_at"])) * settings.parameter("energy_regeneration_per_second")),
		"death_at": float(record["food_anchor_at"]) + death_after,
	}

static func advance(record: Dictionary, now: float, settings: RefCounted) -> Dictionary:
	var candidate := record.duplicate(true)
	var resources := resources_at(record, now, settings)
	for field in ["health", "food", "energy"]:
		candidate[field] = resources[field]
	candidate["updated_at"] = now
	return candidate

static func resume_resources(record: Dictionary, now: float, settings: RefCounted) -> Dictionary:
	# 011 technical boundary pending formal offline resource rules: inactive actors
	# receive neither hunger loss nor regeneration. p620 keeps action deadlines on
	# absolute server game seconds, while p629 pauses the entire unoccupied world.
	# No action timer or last-consumption timestamp is shifted here.
	var candidate := record.duplicate(true)
	candidate["updated_at"] = now
	candidate["food_anchor_at"] = now
	candidate["food_anchor_value"] = record["food"]
	candidate["health_anchor_value"] = record["health"]
	candidate["energy_anchor_value"] = record["energy"]
	var delay_end: float = float(record["last_consumption_at"]) + settings.parameter("energy_regeneration_delay_seconds") if record["last_consumption_at"] >= 0.0 else now
	candidate["energy_anchor_at"] = maxf(now, delay_end)
	return candidate

static func persistent_record(record: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for field in FIELDS:
		result[field] = record[field].duplicate(true) if record[field] is Dictionary or record[field] is Array else record[field]
	return result

static func public_record(record: Dictionary, now: float) -> Dictionary:
	# Explicit whitelist: never duplicate a profile dictionary or an authority object.
	return {
		"actor_id": record["actor_id"], "layer": record["layer"].duplicate(true), "position": record["position"].duplicate(),
		"health": record["health"], "food": record["food"], "energy": record["energy"], "alive": record["health"] > 0.0,
		"dodging": record["health"] > 0.0 and now < record["dodge_until"],
		"invulnerable": record["health"] > 0.0 and now < record["invulnerable_until"],
		"dodge_cooldown_until": record["dodge_cooldown_until"],
		"dodge_start_position": record["dodge_start_position"].duplicate(), "dodge_last_position": record["dodge_last_position"].duplicate(),
	}

static func valid_clock(value: Variant) -> bool:
	return Inputs.number(value) and value >= 0.0 and value <= MAX_CLOCK_SECONDS and float(value) + 0.000001 > float(value)

static func valid_pair(value: Variant) -> bool:
	return value is Array and value.size() == 2 and Inputs.number(value[0]) and Inputs.number(value[1]) and absf(float(value[0])) < MAX_POSITION_COMPONENT and absf(float(value[1])) < MAX_POSITION_COMPONENT

static func valid_direction(value: Variant) -> bool:
	if not valid_pair(value):
		return false
	var x := float(value[0])
	var y := float(value[1])
	if x == 0.0 and y == 0.0:
		return true
	# Historical movement and dodge directions are the eight WASD directions.
	if absf(x * x + y * y - 1.0) > DIRECTION_TOLERANCE:
		return false
	return x == 0.0 or y == 0.0 or absf(absf(x) - absf(y)) <= DIRECTION_TOLERANCE

static func exact_fields(value: Variant, fields: Array) -> bool:
	if not value is Dictionary or value.size() != fields.size():
		return false
	for field in fields:
		if not value.has(field):
			return false
	return true

static func pair(value: Vector2) -> Array:
	return [float(value.x), float(value.y)]

static func vector(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))

static func near_number(a: float, b: float) -> bool:
	# Serialization retains doubles exactly; tolerance covers analytic roundoff only.
	return absf(a - b) <= maxf(0.000000001, maxf(absf(a), absf(b)) * 0.000000000000001)

static func error(code: String, category: String = "invalid_data") -> Dictionary:
	return {"ok": false, "code": code, "category": category, "corruption": category == "invalid_data", "recoverable_corruption": category == "invalid_data"}
