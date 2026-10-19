extends Node
## Mechanics fixture only: direct loadout and explicit director-method calls.
## No natural acquisition, reward route, visual acceptance or production seal.
@export var standalone: bool = true
const SIM_PATH := "res://tests/ink_river_hexes_20261006/ordinary01/sim.gd"
const REQUIRED := ["spawn_classification", "decoy_commit_restore", "boss_immune", "unknown_classification"]
const ORDINARY := ["minion","pouncer","armored","ranged","pitcher","support"]
var checks: Array = []
var groups: Array = []
var observations: Array = []
var serial: int = 0

func _ready() -> void:
 if standalone: _standalone.call_deferred()

func check(ok: bool, label: String) -> bool:
 checks.append({"passed":ok,"label":label})
 return ok

func fields(value: Dictionary, names: Array, label: String) -> bool:
 for name: String in names:
  if not check(value.has(name), label+" field "+name): return false
 return true

func fresh():
 var script = load(SIM_PATH)
 if not check(script != null,"real Sim entry loads"): return null
 var sim = script.new()
 add_child(sim)
 sim.auto_finish = false
 sim.ai_enabled = false
 sim.arena_half_extent = 30.0
 sim.obstacles = []
 sim.hero.position = Vector3.ZERO
 sim.hero.loadout.e = "e2"
 sim.hero.ranks.e = 1
 sim.hero.loadout.q = "q2"
 sim.hero.ranks.q = 1
 sim.hero.loadout.r = "r1"
 sim.hero.ranks.r = 1
 sim.hero.loadout.passive = "p1"
 sim.hero.ranks.passive = 0
 sim.hero.stats.ap = 100.0
 sim.hero.stats.crit_chance = 0.0
 sim.hero.stats.regen = 0.0
 sim.hero.stats.lifesteal = 0.0
 sim.hero.stats.cdr = 0.0
 serial += 1
 var admitted: Dictionary = sim.begin_encounter("h10-director-mechanics-%d"%serial,[])
 if not check(bool(admitted.get("accepted",false)),"mechanics encounter admitted"):
  sim.free()
  return null
 sim.set_hexes(["yanguizhou_h10"])
 if not check(sim.enemy_director.has_method("e2_decoy_eligible") and sim.enemy_director.has_method("e2_decoy_eligibility_reason") and sim.enemy_director.has_method("_decoy"),"director integration methods present"):
  sim.free()
  return null
 return sim

func enter_decoy(sim) -> bool:
 var launched: Dictionary = sim.request_action("e",Vector3(20,0,0))
 if not check(bool(launched.get("accepted",false)),"normal E action accepted"): return false
 if not fields(sim.ink_boat,["voyage_until"],"launched boat"): return false
 var deadline: float = float(sim.ink_boat.voyage_until)
 sim.step(maxf(0.0,deadline-sim.hero_time)+0.02)
 if not fields(sim.ink_boat,["phase","position","decoy_actor_id","decoy_until"],"unboarded decoy"): return false
 return check(sim.ink_boat.phase == "decoy","normal unboarded voyage produces decoy")

func spawn(sim, kind: String, at: Vector3) -> Dictionary:
 var enemy: Dictionary = sim.spawn_enemy(kind,at,10000.0)
 if not fields(enemy,["kind","rank_category","actor_id","position","dead"],"normal spawn "+kind): return {}
 check(enemy.kind == kind,"spawn preserves authored kind "+kind)
 return enemy

func spawn_classification() -> void:
 var sim = fresh()
 if sim == null: return
 for kind: String in ORDINARY+["elite","boss"]:
  var enemy: Dictionary = spawn(sim,kind,Vector3(15,0,0))
  if enemy.is_empty(): continue
  var expected_rank: String = "boss" if kind == "boss" else "elite" if kind == "elite" else "ordinary"
  check(enemy.rank_category == expected_rank,"real factory rank "+kind)
  check(sim.enemy_director.e2_decoy_eligible(enemy) == (kind != "boss"),"factory classification "+kind)
  observations.append({"group":"spawn_classification","kind":enemy.kind,"rank_category":enemy.rank_category,"reason":sim.enemy_director.e2_decoy_eligibility_reason(enemy)})
 sim.free()

func decoy_commit_restore() -> void:
 for kind: String in ORDINARY+["elite"]:
  var sim = fresh()
  if sim == null: continue
  if not enter_decoy(sim): sim.free(); continue
  var center: Vector3 = sim.ink_boat.position
  var actor_id: String = str(sim.ink_boat.decoy_actor_id)
  var until: float = float(sim.ink_boat.decoy_until)
  var enemy: Dictionary = spawn(sim,kind,center+Vector3(4.0 if kind in ["ranged","pitcher","support","pouncer"] else 1.0,0,0))
  if enemy.is_empty(): sim.free(); continue
  # Use the real spawn-grace transition before target eligibility.
  sim.ai_enabled = true
  sim.enemy_director.step_enemy(sim,enemy,0.80)
  sim.ai_enabled = false
  check(enemy.get("state","") == "chase","normal spawn grace reaches chase "+kind)
  sim.enemy_director._update_taunts(sim)
  if not fields(enemy,["taunted","taunt_source","target_actor_id","ink_e2_decoy_position"],"projected "+kind): sim.free(); continue
  check(enemy.taunted and str(enemy.taunt_source) == actor_id and str(enemy.target_actor_id) == actor_id,"real spawn projects current decoy "+kind)
  var target: Dictionary = sim.enemy_director._decoy(sim,enemy)
  if not fields(target,["position","actor_id"],"resolved target "+kind): sim.free(); continue
  check(Vector3(target.position).is_equal_approx(center),"target position is endpoint "+kind)
  var candidate: Dictionary = sim.enemy_director._candidate(sim,enemy)
  if fields(candidate,["target"],"candidate "+kind): check(Vector3(candidate.target).is_equal_approx(center),"new threat candidate uses endpoint "+kind)
  # Explicit mechanics seam: invoke the real director commitment implementation.
  sim.enemy_director._commit(sim,enemy)
  if not fields(enemy,["state","aim","target_point","committed_target_actor_id"],"committed "+kind): sim.free(); continue
  check(enemy.state == "warning" and str(enemy.committed_target_actor_id) == actor_id,"new warning commits decoy identity "+kind)
  check(Vector3(enemy.target_point).is_equal_approx(center),"new warning commits endpoint "+kind)
  var original_aim: Vector3 = enemy.aim
  var original_point: Vector3 = enemy.target_point
  sim.step(maxf(0.0,until-sim.hero_time)+0.02)
  sim.enemy_director._update_taunts(sim)
  check(not enemy.has("ink_e2_decoy_position") and str(enemy.get("target_actor_id","")) == str(sim.hero.actor_id),"expiry restores normal target "+kind)
  check(sim.enemy_director._decoy(sim,enemy).is_empty(),"expired decoy target rejected "+kind)
  check(Vector3(enemy.aim).is_equal_approx(original_aim) and Vector3(enemy.target_point).is_equal_approx(original_point),"already committed warning unchanged on expiry "+kind)
  sim.enemy_director._commit(sim,enemy)
  check(Vector3(enemy.target_point).is_equal_approx(sim.hero.position) and str(enemy.committed_target_actor_id) == str(sim.hero.actor_id),"next real commitment restores hero "+kind)
  observations.append({"group":"decoy_commit_restore","kind":kind,"decoy_actor_id":actor_id,"restored_target":enemy.get("target_actor_id","")})
  sim.free()

func boss_immune() -> void:
 var sim = fresh()
 if sim == null: return
 if not enter_decoy(sim): sim.free(); return
 var boss: Dictionary = spawn(sim,"boss",Vector3(sim.ink_boat.position)+Vector3(1,0,0))
 if boss.is_empty(): sim.free(); return
 sim.enemy_director._update_taunts(sim)
 check(not sim.enemy_director.e2_decoy_eligible(boss),"real Boss class immune")
 check(not boss.has("ink_e2_decoy_position") and not bool(boss.get("taunted",false)),"Boss never receives decoy projection")
 check(sim.enemy_director._decoy(sim,boss).is_empty(),"Boss target helper refuses decoy")
 # Negative fixture derived from a real Boss, never substituted into live roster.
 var forged: Dictionary = boss.duplicate(true)
 forged.rank_category = "ordinary"
 forged.taunted = true
 forged.taunt_source = sim.ink_boat.decoy_actor_id
 forged.target_actor_id = sim.ink_boat.decoy_actor_id
 forged.ink_e2_decoy_position = sim.ink_boat.position
 check(sim.enemy_director.e2_decoy_eligibility_reason(forged) == "boss_immune" and sim.enemy_director._decoy(sim,forged).is_empty(),"Boss kind wins over forged ordinary rank and target fields")
 sim.free()

func unknown_classification() -> void:
 var sim = fresh()
 if sim == null: return
 var original: Dictionary = spawn(sim,"minion",Vector3(15,0,0))
 if original.is_empty(): sim.free(); return
 # These are explicitly malformed negative copies, not invented live enemies.
 var variants: Array = []
 var missing: Dictionary = original.duplicate(true)
 missing.erase("rank_category")
 variants.append(missing)
 for rank: String in ["unknown","elite"]:
  var wrong: Dictionary = original.duplicate(true)
  wrong.rank_category = rank
  variants.append(wrong)
 var unknown_kind: Dictionary = original.duplicate(true)
 unknown_kind.kind = "unknown"
 variants.append(unknown_kind)
 for enemy: Dictionary in variants:
  check(not sim.enemy_director.e2_decoy_eligible(enemy),"malformed classification rejected")
  check(sim.enemy_director.e2_decoy_eligibility_reason(enemy) == "unknown_or_mismatched_enemy_class","malformed classification named diagnosis")
 sim.free()

func run_all() -> Dictionary:
 checks.clear(); groups.clear(); observations.clear()
 for group: String in REQUIRED:
  call(group)
  groups.append(group)
 var failures: Array = checks.filter(func(item: Dictionary): return not bool(item.passed))
 for group: String in REQUIRED:
  check(groups.count(group) == 1,"group completed exactly once: "+group)
 failures = checks.filter(func(item: Dictionary): return not bool(item.passed))
 return {"status":"PASS" if failures.is_empty() else "FAIL","scope":"explicit mechanics fixture; no acquisition or production acceptance","required_groups":REQUIRED,"completed_groups":groups,"completed_group_count":groups.size(),"check_count":checks.size(),"failure_count":failures.size(),"checks":checks,"observations":observations}

func _standalone() -> void:
 var report: Dictionary = run_all()
 var path: String = ""
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--h10-director-result="): path = arg.trim_prefix("--h10-director-result=")
 if not path.is_empty():
  var output = FileAccess.open(path,FileAccess.WRITE)
  if output != null: output.store_string(JSON.stringify(report,"  ")+"\n"); output.close()
  else: report.status = "FAIL"; report.output_error = FileAccess.get_open_error()
 print(JSON.stringify(report))
 get_tree().quit(0 if report.status == "PASS" else 1)
