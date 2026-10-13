extends "res://tests/ink_e3_ordinary_20261006/ordinary01/sim.gd"
## Isolated R1 consumer only. Existing host, shared core and P2 stay unchanged.
const PresentationFacade = preload("res://tests/ink_ultimate_presentation_20261006/r1_consumer01/clock_facade.gd")
const PresentationDirector = preload("res://tests/ink_ultimate_presentation_20261006/r1_consumer01/timed_director.gd")
const AUTHORING_PATH: String = "res://data/combat/ultimate_presentation_authoring.json"
var presentation_errors: Array[String] = []
var presentation_ends: Array = []
var presentation_actor_time: float = 0.0
var presentation_slice_receipts: Array = []
var _show_history: Dictionary = {}
var _current_show: Dictionary = {}
var _presentation_slice: Dictionary = {}
var _presentation_contacts: Dictionary = {}
var _presentation_contact_stack: Array = []
var _presentation_contact_serial: int = 0
var _presentation_enemy: Dictionary = {}
var _presentation_running: bool = false
var presentation_queued_real: float = 0.0
var presentation_precision_deferred: float = 0.0

func _init() -> void:
	super._init()
	var authoring: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(AUTHORING_PATH))
	clock = PresentationFacade.new(self, authoring)
	enemy_director = PresentationDirector.new()

func presentation_fail(reason: String) -> void:
	presentation_errors.append(reason)
	paused = true

func _hero_action_policy(action: String, aim: Vector3 = Vector3.INF) -> Dictionary:
	var result: Dictionary = super._hero_action_policy(action, aim)
	if action == "r" and hero.loadout.r == "r1" and str(result.get("reason", "")).is_empty():
		if not clock.bind_room() or not clock.domain.configuration_ready():
			return {"reason": "presentation_clock_not_ready"}
		var state: Dictionary = clock.domain.snapshot()
		if state["presentations"].has(hero.actor_id):
			return {"reason": "actor_already_presenting"}
	return result

func emit_event(kind: String, data: Dictionary = {}) -> void:
	if kind == "encounter_started" and not clock.bind_room():
		presentation_fail("encounter_scope_not_bound")
	if kind == "ink_r1_created" and _r1_current(ink_snow) and int(data.get("cast_id", -1)) == int(ink_snow.cast_id) and str(data.get("domain_id", "")) == str(ink_snow.domain_id):
		var request: Dictionary = clock.domain.snapshot()["scope"].duplicate(true)
		request.merge({"actor_id": hero.actor_id, "cast_id": str(ink_snow.cast_id), "ability_id": "yanguizhou_r1"})
		var begun: Dictionary = clock.domain.begin_presentation(request)
		if not begun.get("ok", false):
			presentation_fail("committed_r1_presentation_rejected:" + str(begun.get("reason", "")))
			return
		if begun["reason"] == "started":
			var record: Dictionary = clock.domain.snapshot()["presentations"][hero.actor_id]
			_current_show = {"token": begun["token"], "owner": hero, "context": ink_snow.context.duplicate(true), "start": float(clock.domain.snapshot()["active_real_time"]), "end": float(record["expires_at"]), "cancelled": false, "notified": false}
			_show_history[int(begun["token"]["serial"])] = _current_show
	# The token is already eligible when the original created signal is emitted.
	super.emit_event(kind, data)

func presentation_accept_slice(frame: Dictionary, receipt: Dictionary) -> void:
	var segment: Dictionary = frame["segments"][0].duplicate(true)
	segment["scope"] = receipt["scope"]
	segment["real_start"] = float(frame["active_real_time"]) - float(frame["real_dt"])
	segment["real_end"] = float(frame["active_real_time"])
	segment["world_start"] = clock.world_time - float(frame["world_dt"])
	segment["world_end"] = clock.world_time
	segment["ticket"] = receipt["id"]
	_presentation_slice = segment
	presentation_actor_time += float(segment["actor_group_dt"][hero.actor_id])
	presentation_slice_receipts.append({"ticket": receipt["id"], "real_dt": frame["real_dt"], "world_dt": frame["world_dt"], "actor_dt": segment["actor_group_dt"][hero.actor_id], "generation": encounter_generation, "room_id": room_id})
	if presentation_slice_receipts.size() > 256:
		presentation_slice_receipts.pop_front()

func step(real_delta: float) -> void:
	if _presentation_running:
		if phase == "combat" and not paused and not hero.dead and is_finite(real_delta) and real_delta > 0.0:
			# Reentrant requests are accepted by the same accumulator. The outer
			# inherited step loop drains them after this complete slice unwinds.
			real_accumulator += real_delta
			presentation_queued_real += real_delta
		return
	super.step(real_delta)

func _fixed_step(real_dt: float) -> void:
	if _presentation_running:
		if phase == "combat" and not paused and not hero.dead and real_dt > 0.0:
			real_accumulator += real_dt
			presentation_queued_real += real_dt
		return
	var scope: Dictionary = _ink_scope()
	var remaining: float = real_dt
	_presentation_running = true
	while remaining > 0.0 and _ink_scope_current(scope) and not paused and not hero.dead:
		var slice_dt: float = clock.next_budget(remaining)
		if slice_dt <= 0.0:
			presentation_fail("nonpositive_slice_budget")
			break
		var authority_now: float = clock.domain.snapshot()["active_real_time"]
		if authority_now + slice_dt <= authority_now:
			# A positive residual below this float's representable step stays in
			# the existing accumulator; it is not discarded with a chosen EPS.
			presentation_precision_deferred += remaining
			real_accumulator += remaining
			break
		var ticket: Dictionary = clock.arm(slice_dt)
		var accumulator_before: float = real_accumulator
		var queued_before: float = presentation_queued_real
		super._fixed_step(slice_dt)
		if bool(ticket["consumed"]):
			remaining = maxf(0.0, remaining - slice_dt)
		if not _ink_scope_current(scope) or hero.dead:
			break
		if paused or not bool(ticket["consumed"]):
			# Q2/E2 may already return the unadmitted slice. Return only the rest.
			var returned: float = maxf(0.0, real_accumulator - accumulator_before - (presentation_queued_real - queued_before))
			real_accumulator += maxf(0.0, remaining - returned)
			break
		_finish_show_if_due()
		if not _ink_scope_current(scope) or hero.dead:
			break
		if paused:
			real_accumulator += remaining
			break
	_presentation_running = false
	_presentation_slice = {}

func _step_player_locomotion(real_dt: float) -> void:
	var actor_dt: float = real_dt
	if not _presentation_slice.is_empty() and _ink_scope_current(_presentation_slice["scope"]):
		actor_dt = float(_presentation_slice["actor_group_dt"][hero.actor_id])
	super._step_player_locomotion(actor_dt)

func move_during_hitstop(real_dt: float, move: Vector3) -> void:
	if phase != "combat" or paused or hero.dead or real_dt <= 0.0:
		return
	if not clock.domain.snapshot()["presentations"].is_empty():
		hero.move_intent = move.limit_length(1.0)
		step(real_dt)
		return
	super.move_during_hitstop(real_dt, move)

func _finish_show_if_due() -> void:
	if _current_show.is_empty() or bool(_current_show["cancelled"]) or bool(_current_show["notified"]) or paused:
		return
	var record: Dictionary = _current_show
	if not effect_is_current(record["context"]) or not is_same(hero, record["owner"]):
		return
	if float(clock.domain.snapshot()["active_real_time"]) < float(record["end"]):
		return
	record["notified"] = true
	var receipt: Dictionary = {"cast_id": int(record["context"]["cast_id"]), "token": record["token"].duplicate(true), "presentation_end": record["end"], "world_time": clock.world_time, "generation": encounter_generation, "room_id": room_id}
	presentation_ends.append(receipt)
	common.ultimate_ready(int(record["context"]["cast_id"]))
	if effect_is_current(record["context"]) and is_same(hero, record["owner"]):
		emit_event("ink_r1_presentation_ended", receipt)

func _presentation_context(world_offset: float, kind: String) -> Dictionary:
	if _presentation_slice.is_empty() or not _ink_scope_current(_presentation_slice["scope"]):
		return {}
	var duration: float = float(_presentation_slice["world_dt"])
	var offset: float = clampf(world_offset, 0.0, duration)
	var at: float = float(_presentation_slice["real_end"]) if offset == duration else float(_presentation_slice["real_start"]) + offset / float(_presentation_slice["world_scale"])
	return {"scope": _presentation_slice["scope"], "real_at": at, "world_at": float(_presentation_slice["world_start"]) + offset, "kind": kind, "ticket": _presentation_slice["ticket"]}

func presentation_timing_needed() -> bool:
	return not _presentation_slice.is_empty() and _ink_scope_current(_presentation_slice["scope"]) and not _presentation_slice["presentation_tokens"].is_empty()

func presentation_push_contact(world_offset: float, kind: String) -> Dictionary:
	var context: Dictionary = _presentation_context(world_offset, kind)
	if not context.is_empty():
		_presentation_contact_stack.append(context)
	return context

func presentation_pop_contact(context: Dictionary) -> void:
	if not _presentation_contact_stack.is_empty() and is_same(_presentation_contact_stack.back(), context):
		_presentation_contact_stack.pop_back()

func _presentation_at(context: Dictionary) -> bool:
	if context.is_empty() or not _ink_scope_current(context.get("scope", {})) or hero.dead:
		return false
	for record: Dictionary in _show_history.values():
		if bool(record["cancelled"]) or not is_same(hero, record["owner"]) or not effect_is_current(record["context"]):
			continue
		var current_scope: Dictionary = clock.domain.snapshot()["scope"]
		var token: Dictionary = record["token"]
		if token["owner_id"] != current_scope["owner_id"] or token["room_id"] != current_scope["room_id"] or token["generation"] != current_scope["generation"]:
			continue
		if float(context["real_at"]) >= float(record["start"]) and float(context["real_at"]) < float(record["end"]):
			return true
	return false

func hero_damage_immune() -> bool:
	if super.hero_damage_immune():
		return true
	if not _presentation_contact_stack.is_empty():
		return _presentation_at(_presentation_contact_stack.back())
	return not _current_show.is_empty() and not bool(_current_show["cancelled"]) and is_same(hero, _current_show["owner"]) and effect_is_current(_current_show["context"]) and clock.domain.is_invulnerable(_current_show["token"])

func _step_enemy(enemy: Dictionary, dt: float) -> void:
	var prior: Dictionary = _presentation_enemy
	var scope: Dictionary = _ink_scope()
	var rate: float = float(r1_step_enemy_rates(enemy, dt).get("attack_rate", 1.0))
	_presentation_enemy = {"enemy": enemy, "origin": enemy.position, "state": enemy.state, "timer": enemy.timer, "dt": dt, "attack_rate": rate}
	super._step_enemy(enemy, dt)
	_presentation_enemy = prior if _ink_scope_current(scope) else {}

func presentation_enemy_contact() -> Dictionary:
	if _presentation_enemy.is_empty():
		return {}
	var entry: Dictionary = _presentation_enemy
	var offset: float = float(entry["dt"])
	if entry["state"] == "warning":
		offset = float(entry["timer"]) / maxf(0.000000001, float(entry["attack_rate"]))
	elif entry["state"] == "pounce":
		var origin: Vector3 = entry["origin"]
		var relative: Vector3 = Geometry.ground(origin - hero.position)
		var motion: Vector3 = Geometry.ground(Vector3(entry["enemy"]["position"]) - origin)
		var fraction: float = Geometry._circle_entry(Vector2(relative.x, relative.z), Vector2(motion.x, motion.z), Vector2.ZERO, float(entry["enemy"]["radius"]) + enemy_director.HERO_RADIUS)
		offset = clampf(fraction, 0.0, 1.0) * float(entry["dt"]) if is_finite(fraction) else float(entry["dt"])
	return _presentation_context(offset, "enemy_" + str(entry["state"]))

func damage_hero(amount: float, direction: Vector3 = Vector3.ZERO, control: float = 0.0, is_true: bool = false, mandatory: bool = false, metadata: Dictionary = {}) -> void:
	var context: Dictionary = _presentation_contact_stack.back() if not _presentation_contact_stack.is_empty() else presentation_enemy_contact()
	var supplied: Dictionary = metadata.duplicate(true)
	var pushed: bool = not context.is_empty() and _presentation_contact_stack.is_empty()
	if pushed:
		_presentation_contact_stack.append(context)
	if not context.is_empty():
		_presentation_contact_serial += 1
		var key: String = str(_presentation_contact_serial)
		_presentation_contacts[key] = context
		supplied["r1_presentation_contact"] = key
	var before: int = _q2_enemy_hits.size()
	super.damage_hero(amount, direction, control, is_true, mandatory, supplied)
	if not context.is_empty() and _q2_enemy_hits.size() > before:
		var queued: Dictionary = _q2_enemy_hits.back()
		if queued["metadata"].get("r1_presentation_contact", "") == supplied.get("r1_presentation_contact", ""):
			queued["time"] = context["world_at"]
	if pushed:
		presentation_pop_contact(context)

func _q2_deliver_enemy_hit(hit: Dictionary) -> void:
	var key: String = str(hit.get("metadata", {}).get("r1_presentation_contact", ""))
	var context: Dictionary = _presentation_contacts.get(key, {})
	if not context.is_empty():
		_presentation_contact_stack.append(context)
	super._q2_deliver_enemy_hit(hit)
	presentation_pop_contact(context)

func cancel_cast(id: int) -> void:
	for record: Dictionary in _show_history.values():
		if int(record["context"]["cast_id"]) == id:
			record["cancelled"] = true
			clock.domain.end_presentation(record["token"])
	super.cancel_cast(id)

func _hero_clear_transients() -> void:
	for record: Dictionary in _show_history.values():
		record["cancelled"] = true
	_show_history.clear()
	_current_show = {}
	_presentation_slice = {}
	_presentation_contacts.clear()
	_presentation_contact_stack.clear()
	_presentation_enemy = {}
	super._hero_clear_transients()

func ink_presenter_snapshot() -> Dictionary:
	var out: Dictionary = super.ink_presenter_snapshot()
	out["ultimate_presentation"] = {"actor_motion_time": presentation_actor_time, "active": not _current_show.is_empty() and clock.domain.is_invulnerable(_current_show["token"]), "token": _current_show.get("token", {}).duplicate(true), "completed": presentation_ends.duplicate(true), "world_effect_time": hero_time, "production_host_integrated": false, "real_multiplayer": false}
	return out
