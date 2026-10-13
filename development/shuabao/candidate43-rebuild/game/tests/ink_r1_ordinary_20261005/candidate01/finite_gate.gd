extends SceneTree
## Finite source/API mechanics fixtures only. No ordinary R unlock, XP/SP grant,
## natural leveling, native input, presentation acceptance or full-floor claim.
const Sim = preload("res://tests/ink_r1_ordinary_20261005/candidate01/sim.gd")
const Director = preload("res://tests/ink_r1_ordinary_20261005/candidate01/enemy_director.gd")
const PreviousSim = preload("res://tests/ink_e1_ordinary_20261005/candidate01/sim.gd")
const PreviousDirector = preload("res://tests/ink_enemy_navigation_fix01_20261005/enemy_director.gd")
const OrdinaryCatalog = preload("res://tests/ink_e1_ordinary_20261005/candidate01/catalog.gd")
const Model = preload("res://scripts/progression/model.gd")
const Design = preload("res://data/final_design/catalog.gd")
const RADII := [11.0, 11.54, 12.5, 14.0]
const DURATIONS := [6.0, 6.7, 8.2, 10.5]
const COOLDOWNS := [140.0, 131.0, 116.0, 96.0]
const REDUCTIONS := {"ordinary":[.70,.73,.79,.88], "elite":[.40,.44,.52,.65], "boss":[.25,.28,.35,.45]}
## Class constants construct instances; Script-resource reflection uses typed values.
var sim_script: GDScript = Sim
var director_script: GDScript = Director
var previous_director_script: GDScript = PreviousDirector
var checks: int = 0
var failures: Array[String] = []
var groups: Array[String] = []
var observations: Dictionary = {}
var serial: int = 0
var output_path: String = "user://ink_r1_minimal_core_finite.json"

func _initialize() -> void:
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--r1-result="): output_path = arg.trim_prefix("--r1-result=")
 run.call_deferred()

func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok:
  failures.append(label)
  push_error(label)

func near(actual: float, expected: float, label: String, tolerance: float = .00001) -> void:
 check(is_finite(actual) and is_finite(expected) and absf(actual-expected) <= tolerance, label)

func fixture(rank: int = 1, baseline: bool = false):
 # Direct actor setup is an isolated mechanics fixture, never a player route.
 serial += 1
 var sim = PreviousSim.new() if baseline else Sim.new()
 if baseline: sim.enemy_director = PreviousDirector.new()
 root.add_child(sim)
 sim.auto_finish = false
 sim.ai_enabled = false
 sim.arena_half_extent = 100.0
 sim.obstacles = []
 sim.hero.position = Vector3.ZERO
 sim.hero.loadout.q = "q3"; sim.hero.ranks.q = 1
 sim.hero.loadout.e = "e1"; sim.hero.ranks.e = 1
 sim.hero.loadout.r = "r1"; sim.hero.ranks.r = rank
 sim.hero.stats.cdr = 0.0
 sim.hero.stats.crit_chance = 0.0
 sim.hero.stats.regen = 0.0
 sim.hero.stats.defence = 0.0
 check(sim.begin_encounter("r1-explicit-mechanics-fixture-%d" % serial, []).accepted, "fixture encounter initialized")
 sim.set_hexes([])
 return sim

func target(sim, position: Vector3, kind: String = "minion", category: String = "ordinary") -> Dictionary:
 var enemy: Dictionary = sim.spawn_enemy(kind, position, 100000.0)
 enemy.state = "chase"
 enemy.timer = 5.0
 enemy.rank_category = category
 enemy.defence = 0.0
 return enemy

func cast(sim, point: Vector3 = Vector3.ZERO, command: String = "") -> Dictionary:
 var result: Dictionary = sim.request_action("r", point, command)
 check(result.accepted, "explicit fixture R1 API accepted: " + str(result.get("reason", "")))
 return result

func stable_admission_state(sim) -> PackedByteArray:
 return var_to_bytes([sim.cast_serial, sim.hero.cooldowns, sim.hero.position, sim.hero.aim_point, sim.hero.facing, sim.hero_time, sim.real_time, sim.clock.world_time, sim.ink_snow, sim.ink_r1_finished])

func reject_without_effect(sim, point: Vector3, label: String) -> Dictionary:
 var before: PackedByteArray = stable_admission_state(sim)
 var result: Dictionary = sim.request_action("r", point)
 check(not result.accepted, label + " rejected")
 check(before == stable_admission_state(sim), label + " does not cast, spend CD, retarget or advance time")
 return result

func rates(sim, enemy: Dictionary, reduction: float, in_domain: bool, label: String) -> void:
 var before: PackedByteArray = var_to_bytes([enemy, sim.ink_snow, sim.hero.cooldowns, sim.hero_time])
 var result: Dictionary = sim.r1_enemy_rates(enemy)
 check(bool(result.in_domain) == in_domain, label + " membership")
 near(float(result.reduction), reduction, label + " reduction")
 near(float(result.move_rate), 1.0-reduction, label + " move rate")
 near(float(result.attack_rate), 1.0-reduction, label + " attack rate")
 check(before == var_to_bytes([enemy, sim.ink_snow, sim.hero.cooldowns, sim.hero_time]), label + " read-only query")

func run() -> void:
 progression_and_closed_ordinary_scope()
 admission_and_preview()
 source_values_and_membership()
 director_movement_and_timers()
 warning_threat_and_release()
 independent_world_clocks()
 pause_lifetime_and_cleanup()
 coexistence_and_victory()
 var report: Dictionary = {
  "suite":"ink_r1_minimal_core_finite", "passed":failures.is_empty(), "checks":checks,
  "failures":failures, "groups":groups, "observations":observations,
  "scope":"explicit pure-model and isolated source/director fixtures; no ordinary R1 learning or natural XP route",
  "ordinary_R1_opened":false, "ordinary_XP_or_SP_granted":false,
  "natural_leveling_verified":false, "native_input":false, "full_floor":false,
  "R2_opened":false, "H13_H16_opened":false, "art_audio_accepted":false,
  "sim_sha256":FileAccess.get_sha256(sim_script.resource_path),
  "director_sha256":FileAccess.get_sha256(director_script.resource_path),
  "gate_sha256":FileAccess.get_sha256(get_script().resource_path)
 }
 var file := FileAccess.open(output_path, FileAccess.WRITE)
 if file != null:
  file.store_string(JSON.stringify(report, "  "))
  file.close()
 else:
  check(false, "finite report output writable")
  report.passed = false
  report.checks = checks
  report.failures = failures
 print("INK_R1_MINIMAL_CORE_REPORT ", JSON.stringify(report))
 quit(0 if failures.is_empty() else 1)

func progression_and_closed_ordinary_scope() -> void:
 # Minimal pure-model definitions avoid the production catalog adapter entirely.
 # The 7SP below is explicitly a cost-arithmetic fixture, not obtainable Lv6 XP.
 var definitions: Dictionary = {"version":"r1-pure-cost-fixture", "hero_id":"yanguizhou", "candidates":{"R":["R1","R2"]}, "hexes":{}, "r_gates":[6,11,16,18]}
 var model = Model.new(definitions, "r1-cost-fixture", 1)
 check(model.state.level == 1 and model.state.points == 1 and model.state.xp == 0 and model.state.gold == 0, "original model starts Lv1 with 1SP and zero XP/gold")
 check(Model.COSTS.R == [1,2,2,2], "original R costs remain 1/2/2/2")
 check(Model.LEVELING_SP_BUDGET == 18 and Model.FULL_BUILD_COST == 23 and Model.MAX_LEVEL == 18, "original 18 base SP, 23 full-build cost, Lv18 cap")
 var total_cost: int = 0
 for slot: String in Model.COSTS:
  for cost: int in Model.COSTS[slot]: total_cost += cost
 check(total_cost == 23, "sum of all original rank costs is 23")
 model.state.level = 5; model.state.points = 7
 var before: PackedByteArray = var_to_bytes(model.snapshot())
 var denied: Dictionary = model.command("pure-lv5", "learn", {"slot":"R", "candidate":"R1", "expected_rank":0})
 check(not denied.accepted and denied.reason == "level_gate" and before == var_to_bytes(model.snapshot()), "pure fixture first R learn before Lv6 is atomically rejected")
 model.state.level = 6
 var remaining: int = 7
 for rank: int in range(4):
  var learned: Dictionary = model.command("pure-lv6-%d" % rank, "learn", {"slot":"R", "candidate":"R1", "expected_rank":rank})
  remaining -= int(Model.COSTS.R[rank])
  check(learned.accepted and model.state.level == 6 and model.state.skills.R.rank == rank+1 and model.state.points == remaining, "pure fixture same Lv6 R rank %d uses only original cost" % (rank+1))
 var capped: Dictionary = model.command("pure-cap", "learn", {"slot":"R", "candidate":"R1", "expected_rank":4})
 check(not capped.accepted and capped.reason == "rank_cap", "R rank5 remains unavailable")
 var poor = Model.new(definitions, "r1-insufficient-fixture", 2)
 poor.state.level = 6; poor.state.points = 2
 check(poor.command("poor-first", "learn", {"slot":"R", "candidate":"R1", "expected_rank":0}).accepted and poor.state.points == 1, "pure Lv6 first rank spends exactly one point")
 before = var_to_bytes(poor.snapshot())
 denied = poor.command("poor-next", "learn", {"slot":"R", "candidate":"R1", "expected_rank":1})
 check(not denied.accepted and denied.reason == "insufficient_points" and before == var_to_bytes(poor.snapshot()), "second rank requires two actual fixture points")
 check("R1" not in OrdinaryCatalog.FIRST_SLICE_ALLOWED_CANDIDATES and "R2" not in OrdinaryCatalog.FIRST_SLICE_ALLOWED_CANDIDATES, "ordinary catalog still opens neither R candidate")
 for id: String in ["h13","h14","h15","h16"]:
  check("hex.final_design.yanguizhou_%s.v1" % id not in OrdinaryCatalog.FIRST_SLICE_HEX_HOOKS, "ordinary hook remains closed: " + id)
 var sim = fixture()
 check(sim.enemy_director.get_script().resource_path == director_script.resource_path, "candidate constructor installs its exact local director")
 check(director_script.get_base_script().resource_path == previous_director_script.resource_path, "candidate director retains the current navigation parent")
 for id: String in ["yanguizhou_h13","yanguizhou_h14","yanguizhou_h15","yanguizhou_h16"]:
  check(not sim._hero_hex_status(id).active, "source does not activate unimplemented personal hook: " + id)
 sim.free()
 observations["progression_fixture"] = {"level":6, "injected_fixture_points":7, "rank_costs":[1,2,2,2], "ordinary_reward_calls":0, "natural_leveling_claim":false}
 groups.append("pure_original_progression_and_ordinary_scope_closed")

func admission_and_preview() -> void:
 var sim = fixture()
 var before: PackedByteArray = stable_admission_state(sim)
 var preview: Dictionary = sim.r1_preview(Vector3(12,17,0))
 check(preview.accepted and preview.preview_only and preview.position == Vector3(12,0,0), "manual preview grounds finite aim and accepts exact 12m range")
 near(float(preview.placement_range), 12.0, "preview source placement range")
 near(float(preview.radius), 11.0, "preview source radius")
 near(float(preview.duration), 6.0, "preview source duration")
 check(preview.rank == 1 and before == stable_admission_state(sim), "preview cannot create domain or CD")
 reject_without_effect(sim, Vector3(12.01,0,0), "outside placement range")
 for point: Vector3 in [Vector3.INF, Vector3(NAN,0,0), Vector3(0,INF,0), Vector3(0,0,NAN)]:
  check(not sim.r1_preview(point).accepted, "non-finite preview rejected")
  reject_without_effect(sim, point, "non-finite cast aim")
 sim.hero.ranks.r = 0
 check(not sim.r1_preview(Vector3.ZERO).accepted, "unlearned preview rejected")
 reject_without_effect(sim, Vector3.ZERO, "unlearned R1")
 sim.hero.ranks.r = 1; sim.hero.loadout.r = "r2"
 reject_without_effect(sim, Vector3.ZERO, "unimplemented R2")
 sim.hero.loadout.r = "r1"; sim.hero.stun_left = .4
 check(reject_without_effect(sim, Vector3.ZERO, "controlled new R1").reason == "controlled", "new R1 retains control gate")
 sim.hero.stun_left = 0.0; sim.paused = true
 reject_without_effect(sim, Vector3.ZERO, "paused new R1")
 sim.paused = false
 check(sim.request_action("e").accepted, "E1 fixture entered")
 check(reject_without_effect(sim, Vector3.ZERO, "E1 form new R1").reason == "rain_form_forbids_action", "existing E1 explicitly refuses new R")
 sim.request_action("e_release")
 var accepted: Dictionary = cast(sim, Vector3(12,0,0), "r1-deduplicated")
 var id: int = int(accepted.get("cast_id", -1))
 var count: int = sim.cast_serial
 var cd: float = sim.hero.cooldowns.r
 var duplicate: Dictionary = sim.request_action("r", Vector3(12,0,0), "r1-deduplicated")
 check(duplicate.accepted and int(duplicate.cast_id) == id and sim.cast_serial == count and int(sim.ink_snow.cast_id) == id, "same command cannot duplicate R1 source")
 near(sim.hero.cooldowns.r, cd, "duplicate command does not restart cooldown")
 reject_without_effect(sim, Vector3.ZERO, "second R during source cooldown")
 sim.free()
 groups.append("read_only_preview_and_admission_negative_gates")

func source_values_and_membership() -> void:
 for rank: int in range(1,5):
  var sim = fixture(rank)
  var enemy: Dictionary = target(sim, Vector3(2,0,0))
  var hp: float = enemy.hp
  var gold: int = sim.hero.gold
  var xp: float = sim.hero.xp_progress
  cast(sim)
  var state: Dictionary = sim.ink_snow
  near(float(state.radius), RADII[rank-1], "source domain radius rank %d" % rank)
  near(float(state.expires_at)-float(state.born_at), DURATIONS[rank-1], "source duration rank %d" % rank)
  near(float(sim.hero.cooldowns.r), COOLDOWNS[rank-1], "source cooldown rank %d" % rank)
  near(Design.parameter("yanguizhou", "R1-1", rank), 12.0, "immutable source placement range")
  near(Design.parameter("yanguizhou", "R1-2", rank), RADII[rank-1], "immutable source radius")
  near(Design.parameter("yanguizhou", "R1-3", rank), DURATIONS[rank-1], "immutable source lifetime")
  near(Design.parameter("yanguizhou", "R1-7", rank), COOLDOWNS[rank-1], "immutable source cooldown")
  for category: String in REDUCTIONS:
   enemy.rank_category = category
   var reduction: float = REDUCTIONS[category][rank-1]
   rates(sim, enemy, reduction, true, "rank %d category %s" % [rank,category])
   # Explicit geometry fixture: 15m is exactly representable by Vector3.
   # Do not introduce an epsilon to compensate for a rounded .46m actor radius.
   var original_radius: float = enemy.radius
   enemy.radius = 15.0-float(state.radius)
   enemy.position = Vector3(15,0,0)
   rates(sim, enemy, reduction, true, "inclusive XZ volume-contact boundary")
   enemy.position.x += .01
   rates(sim, enemy, 0.0, false, "outside XZ volume-contact boundary")
   enemy.radius = original_radius
   enemy.position = Vector3(2,0,0)
  near(float(state.normal_reduction), REDUCTIONS.ordinary[rank-1], "domain ordinary parameter")
  near(float(state.elite_reduction), REDUCTIONS.elite[rank-1], "domain elite parameter")
  near(float(state.boss_reduction), REDUCTIONS.boss[rank-1], "domain boss parameter")
  enemy.kind = "boss"; enemy.rank_category = "ordinary"
  rates(sim, enemy, REDUCTIONS.ordinary[rank-1], true, "boss kind with ordinary category follows category")
  enemy.kind = "minion"; enemy.rank_category = "boss"
  rates(sim, enemy, REDUCTIONS.boss[rank-1], true, "minion kind with boss category follows category")
  enemy.rank_category = "unknown"
  rates(sim, enemy, 0.0, false, "unknown rank category has no domain effect")
  enemy.rank_category = "ordinary"
  rates(sim, enemy.duplicate(true), 0.0, false, "detached same-ID enemy cannot acquire effect")
  enemy.state = "spawn"
  rates(sim, enemy, 0.0, false, "spawn grace remains outside domain rates")
  enemy.state = "chase"; enemy.dead = true
  rates(sim, enemy, 0.0, false, "dead enemy cannot acquire effect")
  enemy.dead = false
  if rank == 1:
   # Corrupt-target negative fixtures are isolated from normal actor setup.
   var saved_position: Vector3 = enemy.position
   var saved_radius: float = enemy.radius
   enemy.position = Vector3(NAN,0,0)
   rates(sim, enemy, 0.0, false, "non-finite enemy position fails closed")
   enemy.position = saved_position
   for invalid_radius: float in [NAN,-.1]:
    enemy.radius = invalid_radius
    rates(sim, enemy, 0.0, false, "non-finite or negative enemy radius fails closed")
   enemy.radius = saved_radius
   rates(sim, enemy, .7, true, "restored valid target regains only normal domain rates")
  sim.step(.2)
  near(enemy.hp, hp, "R1 creates no damage")
  check(sim.hero.gold == gold and sim.hero.xp_progress == xp, "R1 source creates no gold or XP")
  sim.free()
 groups.append("four_ranks_three_categories_identity_geometry_and_zero_damage")

func director_movement_and_timers() -> void:
 var sim = fixture()
 var base = fixture(1, true)
 var enemy: Dictionary = target(sim, Vector3(5,0,0))
 var ordinary: Dictionary = target(base, Vector3(5,0,0))
 cast(sim)
 sim.ai_enabled = true; base.ai_enabled = true
 for actor: Dictionary in [enemy,ordinary]:
  actor.timer = 1.0; actor.slow_left = 1.5; actor.slow_amount = .4
  actor.guard_broken_left = .8; actor.guard_flash_left = .8; actor.threat_left = .9
  actor.nav_left = 1.0; actor.nav_points = []
 var speed: float = enemy.speed
 var origin: Vector3 = enemy.position
 sim.enemy_director.step_enemy(sim, enemy, .2)
 base.enemy_director.step_enemy(base, ordinary, .2)
 near(origin.distance_to(enemy.position), origin.distance_to(ordinary.position)*.3, "domain movement multiplies existing 40% slow independently", .0001)
 near(enemy.timer, .94, "chase timer advances at attack rate")
 near(ordinary.timer, .8, "baseline chase timer still uses world dt")
 near(enemy.speed, speed, "director restores original enemy speed")
 near(enemy.slow_amount, .4, "domain does not overwrite existing slow magnitude")
 for field: String in ["slow_left","guard_broken_left","guard_flash_left","threat_left","nav_left","wait_age"]:
  near(float(enemy[field]), float(ordinary[field]), "independent real-lifetime field: " + field)
 rates(sim, enemy, .7, true, "rate query excludes separately owned existing slow")
 enemy.position = Vector3(30,0,0); enemy.timer = 1.0
 origin = enemy.position
 sim.enemy_director.step_enemy(sim, enemy, .2)
 near(origin.distance_to(enemy.position), speed*.6*.2, "leaving domain immediately restores movement with pre-existing slow", .0001)
 near(enemy.timer, .8, "leaving domain immediately restores attack timer")
 near(enemy.slow_amount, .4, "leaving domain cannot erase existing slow")
 for phase_name: String in ["chase","warning","recover"]:
  enemy.position = Vector3(5,0,0); enemy.state = phase_name; enemy.timer = 1.0
  enemy.warning_duration = 1.0; enemy.threat_left = 2.0
  sim.enemy_director.step_enemy(sim, enemy, .2)
  near(enemy.timer, .94, "only named attack phase scales timer: " + phase_name)
 enemy.state = "spawn"; enemy.timer = .72
 sim.enemy_director.step_enemy(sim, enemy, .2)
 near(enemy.timer, .52, "spawn grace timer uses unscaled world dt")
 enemy.state = "chase"; enemy.timer = 1.0; enemy.stun_left = .5; enemy.slow_left = .5
 enemy.was_controlled = true; enemy.guard_broken_left = .5; enemy.guard_flash_left = .5
 sim.enemy_director.step_enemy(sim, enemy, .2)
 near(enemy.stun_left, .3, "stun expires in world time")
 near(enemy.slow_left, .3, "existing slow expires in world time")
 near(enemy.timer, 1.0, "controlled enemy does not advance attack timer")
 near(enemy.guard_broken_left, .3, "guard break expires during control in world time")
 sim.free(); base.free()
 sim = fixture(); enemy = target(sim, Vector3(5,0,0), "pouncer")
 cast(sim); sim.ai_enabled = true
 enemy.state = "pounce"; enemy.timer = .40; enemy.aim = Vector3.FORWARD
 enemy.slow_left = 1.0; enemy.slow_amount = .4; enemy.did_hit = false
 origin = enemy.position
 for index: int in range(4):
  sim.enemy_director.step_enemy(sim, enemy, .1)
  if index < 3:
   check(enemy.state == "pounce", "pounce remains active before original .40 world-second deadline")
   near(enemy.timer, .40-float(index+1)*.1, "pounce active timer never multiplies attack or move rate")
 check(enemy.state == "recover", "pounce recovers at original .40 world seconds")
 near(origin.distance_to(enemy.position), 15.0*.6*.3*.40, "pounce displacement includes move rate and independent slow exactly once", .0001)
 near(enemy.slow_left, .6, "pounce keeps original slow lifespan")
 near(enemy.slow_amount, .4, "pounce restores original slow value after local move scaling")
 sim.free()
 groups.append("director_local_movement_attack_phases_and_independent_status_clocks")

func warning_threat_and_release() -> void:
 var timings: Array = []
 for rank: int in [1,4]:
  var sim = fixture(rank)
  var enemy: Dictionary = target(sim, Vector3(5,0,0))
  cast(sim); sim.ai_enabled = true
  sim.enemy_director._commit(sim, enemy)
  var warning: float = enemy.timer
  var elapsed: float = 0.0
  var held: bool = true
  for tick: int in range(250):
   if enemy.state != "warning": break
   sim.enemy_director.step_enemy(sim, enemy, .02)
   elapsed += .02
   if enemy.state == "warning": held = held and sim.enemy_director.active_threat_weight(sim) >= int(enemy.threat_weight)
  var expected: float = warning/(1.0-float(REDUCTIONS.ordinary[rank-1]))
  check(held, "slowed warning retains threat budget until actual release")
  check(enemy.state == "recover" and enemy.attack_index == 1, "finite slowed warning really releases once")
  check(elapsed+0.00001 >= expected and elapsed <= expected+.02001, "actual warning cadence matches attack rate without global dt scaling")
  check(sim.enemy_director.active_threat_weight(sim) == 0, "melee release/recovery clears its retained warning token")
  timings.append({"rank":rank,"warning_seconds":warning,"expected_seconds":expected,"observed_world_seconds":elapsed})
  sim.free()
 # A controlled warning relinquishes its threat immediately as before.
 var sim = fixture()
 var enemy: Dictionary = target(sim, Vector3(5,0,0))
 cast(sim); sim.ai_enabled = true
 sim.enemy_director._commit(sim, enemy)
 enemy.stun_left = .4
 sim.enemy_director.step_enemy(sim, enemy, .02)
 check(enemy.state == "recover" and enemy.threat_left == 0.0 and enemy.attack_index == 0, "control interrupts warning and clears retained threat without attack")
 sim.free()
 observations["warning_cadence_fixture"] = timings
 groups.append("actual_warning_release_and_threat_token_lifetime")

func independent_world_clocks() -> void:
 var sim = fixture()
 var enemy: Dictionary = target(sim, Vector3(5,0,2), "ranged")
 cast(sim); sim.ai_enabled = true
 sim.enemy_director.encounter_generation = sim.encounter_generation
 sim.enemy_director.time = 1.0; sim.enemy_director.commit_gap_left = .4
 sim.hero.cast_state.exposed = {"left":2.0,"duration":2.0,"multiplier":1.2}
 sim.enemy_director.begin_step(sim, .2)
 near(sim.enemy_director.time, 1.2, "global director advances at world dt")
 near(sim.enemy_director.commit_gap_left, .2, "global commit gap is not slowed")
 near(sim.hero.cast_state.exposed.left, 1.8, "existing hero status lifetime is not slowed")
 enemy.aim = Vector3.RIGHT; enemy.target_point = Vector3(30,0,2)
 sim.enemy_director._shoot(sim, enemy)
 var projectile: Dictionary = sim.projectiles.back()
 var origin: Vector3 = projectile.position
 var left: float = projectile.left
 sim.enemy_director.step_projectiles(sim, .2)
 near(origin.distance_to(projectile.position), 11.5*.2, "enemy projectile movement is not snow-scaled", .0001)
 near(projectile.left, left-.2, "enemy projectile lifetime is not snow-scaled")
 sim.zones.append({"team":"enemy","owner":enemy.actor_id,"position":Vector3(40,0,0),"radius":1.0,"left":2.0,"tick_left":1.0,"tick_interval":.6,"damage":1.0,"threat_weight":1})
 sim.enemy_director.step_hostile_zones(sim, .2)
 near(sim.zones[0].left, 1.8, "existing hostile zone lifetime remains world-time")
 near(sim.zones[0].tick_left, .8, "existing hostile zone ticks remain world-time")
 var frozen: PackedByteArray = var_to_bytes([enemy, projectile, sim.zones, sim.enemy_director.time, sim.enemy_director.commit_gap_left])
 sim.paused = true
 sim.enemy_director.begin_step(sim, .2)
 sim.enemy_director.step_enemy(sim, enemy, .2)
 sim.enemy_director.step_projectiles(sim, .2)
 sim.enemy_director.step_hostile_zones(sim, .2)
 check(frozen == var_to_bytes([enemy, projectile, sim.zones, sim.enemy_director.time, sim.enemy_director.commit_gap_left]), "all inherited director paths still respect pause")
 sim.free()
 groups.append("global_director_projectiles_zones_and_statuses_not_rescaled")

func pause_lifetime_and_cleanup() -> void:
 var sim = fixture()
 var enemy: Dictionary = target(sim, Vector3(5,0,0))
 cast(sim)
 var id: int = sim.ink_snow.cast_id
 var deadline: float = sim.ink_snow.expires_at
 var cd: float = sim.hero.cooldowns.r
 var start: float = sim.hero_time
 var core_steps: int = sim.ink_core_steps
 check(not sim.hero_damage_immune() and not sim.hero_control_immune() and not sim.r1_active and sim._presentation.is_empty(), "R1 never creates ultimate immunity or presentation state")
 near(sim.clock.scale_factor(), 1.0, "R1 never creates global slow motion")
 sim.paused = true; sim.step(1.0); sim.move_during_hitstop(.2, Vector3.RIGHT)
 near(sim.hero_time, start, "pause freezes source lifetime")
 near(sim.hero.cooldowns.r, cd, "pause freezes original cooldown")
 check(sim.ink_core_steps == core_steps and sim.ink_r1_finished.is_empty(), "pause executes no hidden fixed steps or finish")
 sim.paused = false; sim.move_during_hitstop(.1, Vector3.RIGHT)
 near(sim.hero_time, start, "existing hitstop freezes domain source clock")
 near(sim.hero.cooldowns.r, cd, "existing hitstop freezes R cooldown")
 check(sim.hero.position.x > 0.0 and not sim.ink_snow.is_empty(), "hero still walks normally during existing hitstop")
 sim.hero.move_intent = Vector3.ZERO
 sim.hero.stun_left = .4
 sim.step(.2)
 check(not sim.ink_snow.is_empty(), "new hero control does not cancel existing domain")
 near(float(sim.ink_snow.expires_at), deadline, "new control does not extend domain deadline")
 rates(sim, enemy, .7, true, "existing domain continues during hero control")
 sim.hero.stun_left = 0.0
 sim.step(5.8)
 check(sim.ink_snow.is_empty() and sim.ink_r1_finished.size() == 1, "natural domain deadline settles once")
 if sim.ink_r1_finished.size() == 1:
  var receipt: Dictionary = sim.ink_r1_finished[0]
  check(receipt.reason == "natural_expiry" and int(receipt.cast_id) == id, "natural receipt preserves cast and exact finish reason")
  near(float(receipt.finished_at), deadline, "natural receipt records exact source deadline")
 check(bool(sim._casts[id].finished), "natural expiry finishes the accepted source cast")
 check(sim.ink_core_steps-core_steps == 300, "six seconds uses exactly 300 inherited fixed steps")
 near(sim.hero.cooldowns.r, cd-6.0, "natural expiry never resets cooldown")
 rates(sim, enemy, 0.0, false, "expired domain ceases immediately")
 sim.step(.1)
 check(sim.ink_r1_finished.size() == 1, "extra steps cannot duplicate natural finish")
 sim.free()
 sim = fixture(); cast(sim)
 cd = sim.hero.cooldowns.r
 sim.clock.enter("explicit-external-slow-fixture", 1.0)
 var world_rate: float = sim.clock.scale_factor()
 sim.step(.2)
 near(sim.hero_time, .2*world_rate, "domain follows existing hero/world clock under an external slow")
 near(sim.hero.cooldowns.r, cd-.2*world_rate, "domain and original cooldown share inherited source clock")
 check(not sim.ink_snow.is_empty(), "external slow does not erase domain")
 sim.free()
 # Explicit temporal seam fixture: a half-tick deadline, not a new rank duration.
 sim = fixture(); enemy = target(sim, Vector3(5,0,0)); cast(sim)
 sim.ink_snow.expires_at = sim.hero_time+.01
 sim.ai_enabled = true; enemy.timer = 1.0
 var origin: Vector3 = enemy.position
 var speed: float = enemy.speed
 sim.step(.02)
 near(origin.distance_to(enemy.position), speed*(.01*.3+.01), "expiry-crossing tick applies slow only during live half", .0001)
 near(enemy.timer, 1.0-(.01*.3+.01), "expiry-crossing attack timer applies only live-half reduction")
 check(sim.ink_snow.is_empty() and sim.ink_r1_finished.size() == 1, "half-tick temporal fixture retires once")
 sim.free()
 for boundary: String in ["cancel","death","room"]:
  sim = fixture(); enemy = target(sim, Vector3(5,0,0)); cast(sim)
  id = sim.ink_snow.cast_id; cd = sim.hero.cooldowns.r
  var old_enemy: Dictionary = enemy
  if boundary == "cancel":
   sim.cancel_cast(id); sim.cancel_cast(id)
   check(not sim.cast_is_current(id), "cancel invalidates original cast")
  elif boundary == "death":
   sim.damage_hero(1000000.0, Vector3.ZERO, 0.0, true, true)
   check(sim.hero.dead, "true-death fixture reaches inherited death path")
  else:
   sim.end_encounter("fixture-room-boundary")
   check(sim.begin_encounter("fixture-replacement-room", []).accepted, "new-room fixture enters replacement generation")
   rates(sim, old_enemy, 0.0, false, "old enemy cannot retain domain across room generation")
  check(sim.ink_snow.is_empty() and sim.ink_r1_finished.is_empty(), boundary + " clears without inventing natural finish")
  near(sim.hero.cooldowns.r, cd, boundary + " retains original R cooldown")
  rates(sim, old_enemy, 0.0, false, boundary + " has no surviving rate effect")
  sim.free()
 groups.append("pause_hitstop_external_time_natural_expiry_partial_tick_and_cleanup")

func coexistence_and_victory() -> void:
 var sim = fixture()
 target(sim, Vector3(30,0,0))
 cast(sim)
 var snow_id: int = sim.ink_snow.cast_id
 var deadline: float = sim.ink_snow.expires_at
 check(sim.request_action("q", Vector3(6,0,0)).accepted, "Q3 remains usable while R1 domain exists")
 check(sim.request_action("e").accepted, "E1 remains usable while R1 domain exists")
 check(not sim.ink_snow.is_empty() and int(sim.ink_snow.cast_id) == snow_id, "Q/E do not replace existing R1 owner")
 near(float(sim.ink_snow.expires_at), deadline, "Q/E never refresh existing R1 deadline")
 sim.request_action("e_release")
 sim.free()
 sim = fixture()
 var enemy: Dictionary = target(sim, Vector3(1,0,0))
 cast(sim)
 var hp: float = sim.hero.hp
 sim.damage_hero(10.0, Vector3.ZERO, 0.0, true)
 near(hp-sim.hero.hp, 10.0, "R1 does not reduce incoming damage")
 check(not sim._hero_victory_pending(), "damage-free R1 does not add a victory-pending source")
 sim.auto_finish = true
 sim.damage_enemy(enemy, 1000000.0, "r1-gate-explicit-fixture-kill", 0, true)
 sim._check_victory()
 check(sim.phase == "victory" and sim.ink_snow.is_empty(), "last-enemy death ends encounter without waiting for snow duration")
 check(sim.ink_r1_finished.is_empty(), "victory cleanup does not pretend domain naturally expired")
 sim.free()
 sim = fixture()
 enemy = target(sim, Vector3(30,0,0))
 cast(sim)
 check(sim.request_action("e").accepted, "coexistence fixture starts inherited damage-producing E1")
 check(sim._hero_victory_pending(), "inherited E1 victory-pending behavior remains intact")
 sim.auto_finish = true
 sim.damage_enemy(enemy, 1000000.0, "r1-gate-existing-pending-fixture", 0, true)
 sim._check_victory()
 check(sim.phase == "combat" and not sim.ink_rain.is_empty(), "snow does not remove an existing E1 pending gate")
 sim.request_action("e_release")
 sim._check_victory()
 check(sim.phase == "victory", "existing E1 settles victory while unfinished R1 adds no delay")
 sim.free()
 groups.append("Q_E_coexistence_no_immunity_and_unchanged_victory_pending")
