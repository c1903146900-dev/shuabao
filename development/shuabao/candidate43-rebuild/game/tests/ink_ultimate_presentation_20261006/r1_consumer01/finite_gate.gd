extends SceneTree
const Sim = preload("res://tests/ink_ultimate_presentation_20261006/r1_consumer01/sim.gd")
const Baseline = preload("res://tests/ink_e3_ordinary_20261006/ordinary01/sim.gd")
const BASE: String = "res://tests/ink_ultimate_presentation_20261006/r1_consumer01/"
const GROUPS: Array = ["r1_commit_and_world_channels", "actor_overlap_and_shift", "hostile_event_endpoints", "pause_remainder_and_reentry", "cast_and_room_retirement", "baseline_and_world_projectiles"]
var checks: int = 0
var failures: Array[String] = []
var completed: Array[String] = []
var observations: Dictionary = {}
var serial: int = 0
var output_path: String = ""

func _initialize() -> void:
	output_path = OS.get_environment("INK_R1_PRESENTATION_CONSUMER_REPORT")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--consumer-result="):
			output_path = argument.trim_prefix("--consumer-result=")
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func near(actual: float, expected: float, label: String) -> void:
	check(is_finite(actual) and absf(actual - expected) < 0.00005, label + " actual=" + str(actual) + " expected=" + str(expected))

func fresh(baseline: bool = false):
	serial += 1
	var sim = Baseline.new() if baseline else Sim.new()
	root.add_child(sim)
	sim.auto_finish = false
	sim.ai_enabled = false
	sim.obstacles = []
	sim.arena_half_extent = 50.0
	sim.hero.position = Vector3.ZERO
	sim.hero.loadout.r = "r1"; sim.hero.ranks.r = 1
	sim.hero.loadout.e = "e3"; sim.hero.ranks.e = 1
	sim.hero.loadout.q = "q1"; sim.hero.ranks.q = 1
	sim.hero.loadout.passive = "p1"; sim.hero.ranks.passive = 0
	sim.hero.stats.regen = 0.0; sim.hero.stats.defence = 0.0
	sim.hero.stats.crit_chance = 0.0; sim.hero.stats.lifesteal = 0.0
	check(sim.begin_encounter("r1-presentation-fixture-" + str(serial), []).accepted, "real inherited encounter begins")
	sim.set_hexes([])
	return sim

func cast(sim) -> Dictionary:
	var result: Dictionary = sim.request_action("r", Vector3.ZERO, "r1-command")
	check(result.get("accepted", false), "real R1 action accepted")
	return result

func clean(sim, label: String) -> void:
	check(sim.presentation_errors.is_empty(), label + " no consumer hold")
	check(sim.clock.advances == sim.ink_core_steps, label + " one authority advance per actual core slice")

func finish_group(group: String) -> void:
	completed.append(group)
	print("INK_R1_PRESENTATION_CONSUMER_GROUP ", group)

func external(sim, actor_id: String = "local-B") -> Dictionary:
	var request: Dictionary = sim.clock.domain.snapshot()["scope"].duplicate(true)
	request.merge({"actor_id": actor_id, "cast_id": "fixture-local-only", "ability_id": "yanguizhou_r2"})
	var result: Dictionary = sim.clock.domain.begin_presentation(request)
	check(result.get("ok", false), "explicit local external presenter fixture begins")
	return result.get("token", {})

func r1_commit_and_world_channels() -> void:
	var sim = fresh()
	var seen: Dictionary = {}
	sim.combat_event.connect(func(event: Dictionary):
		if event.kind == "ink_r1_created":
			seen["immune"] = sim.hero_damage_immune()
			seen["field"] = not sim.ink_snow.is_empty()
			seen["cd"] = sim.hero.cooldowns.r
			seen["token"] = sim._current_show.get("token", {}).duplicate(true)
	)
	var result: Dictionary = cast(sim)
	check(seen.get("immune", false) and seen.get("field", false) and float(seen.get("cd", 0.0)) > 0.0, "created callback sees field, original cooldown and presentation immunity together")
	check(not sim.r1_active and sim._presentation.is_empty(), "no legacy whole-field immunity flag")
	var deadline: float = sim.ink_snow.expires_at
	var initial_cd: float = sim.hero.cooldowns.r
	sim.add_shield("world-buff", 20.0, 4.0)
	sim.hero.slow_left = 3.0; sim.hero.slow_amount = 0.0
	sim.step(1.0)
	near(sim.hero_time, 0.25, "skill time remains world")
	near(sim.clock.world_time, 0.25, "single authoritative slow world")
	near(sim.hero.cooldowns.r, initial_cd - 0.25, "R1 cooldown follows world during own show")
	near(sim.hero.shields["world-buff"].left, 3.75, "buff/shield uses world")
	near(sim.hero.slow_left, 2.75, "ordinary status uses world")
	near(sim.common.runtime.time, 0.25, "common world clock")
	near(sim.common.runtime.actor_time, 0.25, "common owner numeric clock remains world")
	near(sim.presentation_actor_time, 1.0, "separate actor presentation clock normal")
	check(not sim.hero_damage_immune(), "own immunity ends after short window")
	check(not sim.ink_snow.is_empty() and not bool(sim._casts[int(result.cast_id)].finished), "short show ending keeps original field and cast alive")
	check(sim.presentation_ends.size() == 1, "one presentation-end event")
	near(sim.ink_snow.expires_at, deadline, "field original deadline unchanged")
	var snapshot: Dictionary = sim.ink_presenter_snapshot()
	near(snapshot.source_time, 0.25, "world effect presentation source remains world")
	near(snapshot.ultimate_presentation.actor_motion_time, 1.0, "new actor view channel is separate")
	sim.step(0.2)
	near(sim.hero_time, 0.45, "field resumes normal world after last show")
	near(sim.hero.cooldowns.r, initial_cd - 0.45, "show end never restarts cooldown")
	check(sim.presentation_ends.size() == 1, "no duplicate show end")
	sim.step(deadline - sim.hero_time + 0.04)
	check(sim.ink_snow.is_empty() and sim.ink_r1_finished.size() == 1, "original world deadline finishes field once")
	clean(sim, "R1 channels")
	observations["commit"] = seen
	sim.free()
	finish_group("r1_commit_and_world_channels")

func actor_overlap_and_shift() -> void:
	var sim = fresh()
	cast(sim)
	sim.hero.move_intent = Vector3.RIGHT
	var speed: float = sim.hero.speed()
	sim.step(0.2)
	near(sim.hero.position.x, speed * 0.2, "presenter locomotion normal")
	var other: Dictionary = external(sim)
	sim.step(0.8)
	near(sim.hero.position.x, speed, "both presenters normal until A expires")
	check(not sim.hero_damage_immune() and sim.clock.domain.is_invulnerable(other), "A exits while B still presenting")
	var at: float = sim.hero.position.x
	sim.step(0.2)
	near(sim.hero.position.x - at, speed * 0.05, "A ordinary locomotion returns to slow group")
	near(sim.clock.world_time, 0.3, "overlap does not multiply world slow")
	sim.step(0.2)
	check(not sim.clock.domain.is_invulnerable(other), "B finishes its own independent window")
	at = sim.hero.position.x
	sim.step(0.2)
	near(sim.hero.position.x - at, speed * 0.2, "last exit restores ordinary movement")
	clean(sim, "actor overlap")
	sim.free()
	sim = fresh()
	external(sim)
	var dash: Dictionary = sim.request_action("shift", Vector3.RIGHT * 20.0)
	check(dash.accepted, "original Shift service accepts")
	var duration: float = sim.hero.dash_left
	var distance: float = sim._dash_state.distance
	var initial_cd: float = sim.hero.cooldowns.shift
	var iframe: float = sim.dash_iframe_left
	sim.step(0.04)
	near(sim.hero.dash_left, duration - 0.01, "nonpresenter Shift duration uses actor group dt")
	near(sim.hero.position.x, distance / duration * 0.01, "nonpresenter Shift movement uses actor group dt")
	near(sim.dash_iframe_left, maxf(0.0, iframe - 0.01), "Shift own action iframe follows its motion clock")
	near(sim.hero.cooldowns.shift, initial_cd - 0.01, "Shift cooldown remains world")
	clean(sim, "Shift")
	sim.free()
	finish_group("actor_overlap_and_shift")

func ending_fixture():
	var sim = fresh()
	cast(sim)
	sim.step(0.98)
	return sim

func final_world_budget(sim) -> float:
	return (float(sim._current_show.end) - float(sim.clock.domain.snapshot().active_real_time)) * 0.25

func add_zone(sim, due: float) -> void:
	sim.zones.append({"team": "enemy", "owner": "timing-zone", "position": Vector3.ZERO, "radius": 2.0, "left": 2.0, "duration": 2.0, "damage": 10.0, "tick_left": due, "tick_interval": 1.0})

func hostile_event_endpoints() -> void:
	for fraction: float in [0.5, 1.0]:
		var sim = ending_fixture()
		var hp: float = sim.hero.hp
		add_zone(sim, final_world_budget(sim) * fraction)
		sim.step(0.02)
		near(sim.hero.hp, hp if fraction < 1.0 else hp - 10.0, "zone event before vs at exact presentation end " + str(fraction))
		check(not sim.hero_damage_immune(), "zone endpoint leaves no lingering immunity")
		clean(sim, "zone endpoint")
		sim.free()
	for fraction: float in [0.5, 1.0]:
		var sim = ending_fixture()
		var budget: float = final_world_budget(sim)
		var hp: float = sim.hero.hp
		var speed: float = 0.125 / (budget * fraction)
		sim.projectiles.append({"id": "timed-bolt", "position": Vector3(1.125,0,0), "origin": Vector3(1.125,0,0), "direction": Vector3.LEFT, "speed": speed, "left": 2.0, "duration": 2.0, "damage": 10.0, "owner": "timing-enemy", "team": "enemy", "type": "hex_bolt", "role": "support", "radius": 0.35, "height": 0.0, "target_point": Vector3.ZERO, "threat_weight": 1})
		sim.step(0.02)
		near(sim.hero.hp, hp if fraction < 1.0 else hp - 12.0, "bolt collision before vs at end uses matching exposure and damage clock " + str(fraction))
		check(sim.hero.cast_state.has("exposed") == (fraction == 1.0), "hex status obeys same event-time immunity")
		check(sim.projectiles.is_empty(), "original projectile consumed at collision")
		clean(sim, "bolt endpoint")
		sim.free()
	for fraction: float in [0.5, 1.0]:
		var sim = ending_fixture()
		var enemy: Dictionary = sim.spawn_enemy("minion", Vector3(1,0,0), 10000.0)
		enemy.state = "warning"; enemy.aim = Vector3.LEFT; enemy.damage = 10.0
		var rate: float = sim.r1_enemy_rates(enemy).attack_rate
		enemy.timer = final_world_budget(sim) * fraction * rate
		enemy.warning_duration = 0.5
		var hp: float = sim.hero.hp
		sim.ai_enabled = true
		sim.step(0.02)
		near(sim.hero.hp, hp if fraction < 1.0 else hp - 10.0, "snow-slowed warning event has exact world time " + str(fraction))
		check((sim.hero.stun_left > 0.0) == (fraction == 1.0), "control follows same warning timestamp")
		clean(sim, "warning endpoint")
		sim.free()
	finish_group("hostile_event_endpoints")

func pause_remainder_and_reentry() -> void:
	var sim = fresh()
	cast(sim)
	sim.step(0.2)
	var before: Dictionary = sim.clock.domain.snapshot()
	var cd: float = sim.hero.cooldowns.r
	sim.paused = true
	sim.step(20.0)
	sim.move_during_hitstop(1.0, Vector3.RIGHT)
	check(sim.clock.domain.snapshot() == before, "pause freezes authority and presentation")
	near(sim.hero.cooldowns.r, cd, "pause freezes cooldown")
	check(sim.hero.position == Vector3.ZERO, "pause blocks all movement paths")
	sim.paused = false
	sim.step(0.8)
	check(not sim.hero_damage_immune(), "resume consumes only original remaining show")
	sim.free()
	sim = fresh()
	cast(sim)
	var a: Dictionary = sim.spawn_enemy("minion", Vector3(-3,0,0), 10000.0)
	var b: Dictionary = sim.spawn_enemy("minion", Vector3(3,0,0), 10000.0)
	a.state = "chase"; b.state = "chase"
	var pauses: Dictionary = {"count": 0}
	sim.combat_event.connect(func(event: Dictionary):
		if event.kind == "damage" and event.get("source", "") == "e3" and int(pauses.count) < 2:
			pauses.count += 1
			sim.paused = true
	)
	check(sim.request_e3("first", Vector3(-3,0,0)).accepted, "real E3 first placement")
	check(sim.request_e3("second", Vector3(3,0,0)).accepted and sim.paused, "real E3 first packet pauses")
	check(sim.clock.advances == 0, "action-time pause has not advanced clock")
	sim.paused = false
	sim.step(0.02)
	check(sim.paused and int(pauses.count) == 2, "resumed E3 second packet pauses before core")
	check(sim.clock.advances == 0, "pre-core old packet does not consume presentation")
	near(sim.real_accumulator, 0.02, "unadmitted budget returned once")
	sim.paused = false
	sim.step(0.02)
	near(sim.clock.domain.snapshot().active_real_time, 0.04, "resume consumes old admitted request plus new request once")
	near(sim.hero_time, 0.01, "old batch resume never repeats world time")
	check(sim.ink_e3_finished.size() == 1, "old E3 terminal is once only")
	clean(sim, "pre-core remainder")
	sim.free()
	sim = fresh()
	var reentry: Dictionary = {"calls": 0}
	sim.combat_event.connect(func(event: Dictionary):
		if event.kind == "ink_r1_presentation_ended" and int(reentry.calls) == 0:
			reentry.calls = 1
			sim.step(0.04)
	)
	cast(sim)
	sim.step(1.0)
	check(int(reentry.calls) == 1 and not sim.paused, "actual presentation callback step is accepted without prohibition")
	near(sim.presentation_queued_real, 0.04, "reentrant budget recorded")
	near(sim.clock.domain.snapshot().active_real_time, 1.04, "reentrant step budget drains once after unwind")
	near(sim.hero_time, 0.29, "reentrant post-presentation world recovers")
	check(sim.presentation_ends.size() == 1, "reentrant request cannot repeat end token")
	clean(sim, "reentry")
	sim.free()
	finish_group("pause_remainder_and_reentry")

func cast_and_room_retirement() -> void:
	var sim = fresh()
	var result: Dictionary = cast(sim)
	var token: Dictionary = sim._current_show.token.duplicate(true)
	sim.step(0.4)
	var request: Dictionary = sim.clock.domain.snapshot().scope.duplicate(true)
	request.merge({"actor_id": sim.hero.actor_id, "cast_id": str(result.cast_id), "ability_id": "yanguizhou_r1"})
	var replay: Dictionary = sim.clock.domain.begin_presentation(request)
	check(replay.ok and replay.reason == "duplicate", "exact cast replay is idempotent in consumer")
	sim.step(0.6)
	check(not sim.hero_damage_immune(), "replay did not extend immunity")
	check(sim.presentation_ends.size() == 1, "one end after replay")
	sim.end_encounter("fixture_end")
	check(sim.clock.domain.snapshot().presentations.is_empty(), "room retirement clears presentations")
	check(sim.begin_encounter("consumer-next-room", []).accepted, "next actual room begins")
	near(sim.clock.world_time, 0.25, "legacy cumulative world offset retained across room")
	sim.hero.cooldowns.r = 0.0
	var next: Dictionary = sim.request_action("r", Vector3.ZERO, "new-room-r")
	check(next.accepted and sim.hero_damage_immune(), "new room owns new R1 token")
	check(not sim.clock.domain.end_presentation(token) and sim.hero_damage_immune(), "old room token cannot end new actor show")
	sim.cancel_cast(int(next.cast_id))
	check(not sim.hero_damage_immune() and sim.ink_snow.is_empty(), "exact cast cancel retires field and presentation")
	sim.step(0.04)
	near(sim.clock.scale_factor(), 1.0, "cancel restores single world")
	clean(sim, "retirement")
	sim.free()
	sim = fresh()
	var callback: Dictionary = {"immune_before": false}
	sim.combat_event.connect(func(event: Dictionary):
		if event.kind == "ink_r1_created":
			callback.immune_before = sim.hero_damage_immune()
			sim.end_encounter("created_callback_retired")
	)
	var aborted: Dictionary = cast(sim)
	check(callback.immune_before and aborted.get("cancelled_during_callback", false), "created callback may retire already protected cast")
	check(sim.clock.domain.snapshot().presentations.is_empty() and not sim.hero_damage_immune(), "callback retirement never resurrects token")
	check(sim.presentation_ends.is_empty(), "cancelled presentation does not emit natural end")
	sim.free()
	finish_group("cast_and_room_retirement")

func baseline_and_world_projectiles() -> void:
	var baseline = fresh(true)
	var sim = fresh()
	for current in [baseline, sim]:
		current.hero.move_intent = Vector3.RIGHT
		current.hero.cooldowns.q = 5.0
		current.step(0.2)
	near(sim.hero_time, baseline.hero_time, "no-R world behavior preserved")
	near(sim.hero.position.x, baseline.hero.position.x, "no-R locomotion preserved")
	near(sim.hero.cooldowns.q, baseline.hero.cooldowns.q, "no-R cooldown behavior preserved")
	check(sim.ink_core_steps == baseline.ink_core_steps, "no-R fixed-step count preserved")
	baseline.free(); sim.free()
	sim = fresh()
	cast(sim)
	var attack: Dictionary = sim.request_action("attack", Vector3.RIGHT * 20.0)
	check(attack.accepted and sim.ink_basics.size() == 1, "real hero basic world projectile released during presentation")
	var wave: Dictionary = sim.ink_basics[0]
	var speed: float = wave.speed
	sim.projectiles.append({"id": "away-bolt", "position": Vector3(10,0,10), "origin": Vector3(10,0,10), "direction": Vector3.RIGHT, "speed": 8.0, "left": 2.0, "duration": 2.0, "damage": 10.0, "owner": "departed-enemy", "team": "enemy", "type": "bolt", "radius": 0.14, "height": 0.0, "target_point": Vector3(20,0,10), "threat_weight": 1})
	sim.step(0.08)
	near(wave.front_distance, speed * 0.02, "presenter-owned basic flight remains world speed")
	near(sim.projectiles[0].position.x, 10.16, "enemy/orphan projectile uses same world dt")
	near(sim.projectiles[0].left, 1.98, "projectile lifetime uses world dt")
	near(sim.hero_time, 0.02, "hero effects world source after flight")
	near(sim.presentation_actor_time, 0.08, "actor animation channel independent of flight")
	clean(sim, "world projectiles")
	observations["world_projectiles"] = {"hero_distance": wave.front_distance, "enemy_x": sim.projectiles[0].position.x, "actor_time": sim.presentation_actor_time, "world_time": sim.hero_time}
	sim.free()
	finish_group("baseline_and_world_projectiles")

func run() -> void:
	var binding: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE + "source_binding.json"))
	var observed: Dictionary = {}
	for path: String in binding.runtime_map:
		observed[path] = FileAccess.get_sha256("res://" + path)
		check(observed[path] == binding.runtime_map[path].sha256, "source-bound runtime " + path)
	r1_commit_and_world_channels()
	actor_overlap_and_shift()
	hostile_event_endpoints()
	pause_remainder_and_reentry()
	cast_and_room_retirement()
	baseline_and_world_projectiles()
	check(completed == GROUPS, "six exact consumer groups completed")
	check(not output_path.is_empty(), "explicit consumer report destination")
	var report: Dictionary = {"suite": "ink_r1_presentation_consumer01", "passed": failures.is_empty(), "failures": failures, "checks": checks, "completed": completed, "observations": observations, "source_binding_sha256": FileAccess.get_sha256(BASE + "source_binding.json"), "observed_runtime_sha256": observed, "production_integration": false, "real_multiplayer": false, "art_acceptance": false, "scope": "LOCAL_R1_SIM_CONSUMER_ONLY"}
	if not output_path.is_empty():
		var file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
		if file == null:
			failures.append("consumer report could not be written")
			report.passed = false
		else:
			file.store_string(JSON.stringify(report, "  ") + "\n")
	print("INK_R1_PRESENTATION_CONSUMER_REPORT ", JSON.stringify(report))
	quit(0 if report.passed else 1)
