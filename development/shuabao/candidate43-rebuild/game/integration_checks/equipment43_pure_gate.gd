extends SceneTree
## Pure arithmetic/selection contract. This does not prove source-clock binding.
const Passive = preload("res://equipment_regeneration_20261009/passive24.gd")
var checks: Array = []
var failures: Array = []
var output_path := "user://equipment43_e03_pure_gate.json"
func _initialize() -> void:
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--equipment-result="): output_path = arg.trim_prefix("--equipment-result=")
 run.call_deferred()
func check(ok: bool, label: String) -> void:
 checks.append({"accepted":ok,"label":label})
 if not ok: failures.append(label)
func selection(copies: int = 1) -> Dictionary:
 return Passive.select_unique([{"id":"final:E03","uid":1,"count":copies}],{"final:E03":{"mechanism_prepared":true,"passive24":{"combat_time":6.0,"regen_bonus":100.0}}})
func context(now: float, started: float = 0.0) -> Dictionary:
 return {"bound":true,"combat":true,"owner_alive":true,"clock":"original_common_actor_time","now":now,"combat_started_at":started,"episode":1,"generation":1,"room_id":"room-a"}
func interval(begin: float, end: float) -> Dictionary:
 return {"start":begin,"end":end,"duration":end-begin,"episode":1,"generation":1,"room_id":"room-a"}
func run() -> void:
 check(Passive.valid_tuning({"combat_time":6.0,"regen_bonus":100.0}),"original timing and percentage tuning")
 check(not Passive.inspect(selection(),context(5.999999999)).active,"strictly below6 remains inactive")
 check(Passive.inspect(selection(),context(6.0)).active,"exact6 instant status becomes active")
 check(Passive.inspect(selection(),context(7.0)).factor == 2.0,"after6 doubles natural regen rate")
 var ending: Dictionary = Passive.inspect(selection(),context(6.0),interval(5.98,6.0))
 check(ending.factor == 2.0 and ending.applied_factor == 1.0 and ending.active_interval == 0.0,"tick ending at6 has no retroactive extra healing")
 var crossing: Dictionary = Passive.inspect(selection(),context(6.01),interval(5.99,6.01))
 check(crossing.interval_weighted and is_equal_approx(crossing.applied_factor,1.5),"5.99 to6.01 enhances only last half interval")
 var after: Dictionary = Passive.inspect(selection(),context(6.02),interval(6.0,6.02))
 check(after.applied_factor == 2.0,"whole interval beginning at6 receives full bonus")
 check(Passive.inspect(selection(2),context(7.0)).factor == 2.0,"two copies do not multiply unique passive")
 check(selection(2).owned_copies == 2,"static item copies remain counted")
 var safe: Dictionary = context(20.0);safe.combat = false
 check(Passive.inspect(selection(),safe).factor == 1.0,"actual combat end immediately disables effect")
 var dead: Dictionary = context(20.0);dead.owner_alive = false
 check(Passive.inspect(selection(),dead).factor == 1.0,"dead owner cannot retain effect")
 var paused: Dictionary = context(7.0);paused.paused = true
 check(Passive.inspect(selection(),paused).factor == 2.0,"paused combat does not remove already active instantaneous effect")
 check(not Passive.inspect(selection(),context(105.99,100.0)).active,"new combat uses fresh start within cumulative run clock")
 check(Passive.inspect(selection(),context(106.0,100.0)).active,"fresh combat becomes active only at its own6seconds")
 var generation: Dictionary = context(7.0);generation.generation = 2
 check(Passive.inspect(selection(),generation).active,"same combat start is independent of generation")
 var missing: Dictionary = Passive.select_unique([],{})
 check(Passive.inspect(missing,context(7.0)).factor == 1.0,"sold-out selection has no retained buff")
 check(not Passive.inspect(selection(),context(1.0)).active,"newly started encounter does not inherit old buff")
 check(Passive.inspect(selection(),context(7.0)).applied_factor == 2.0,"public status without interval is instantaneous")
 var unbound: Dictionary = context(7.0);unbound.bound = false
 check(Passive.inspect(selection(),unbound).factor == 1.0,"unbound clock context fails closed")
 var wrong_clock: Dictionary = context(7.0);wrong_clock.clock = "real_time"
 check(Passive.inspect(selection(),wrong_clock).factor == 1.0,"real_time is not accepted as buff clock")
 check(Passive.inspect(selection(),context(INF)).factor == 1.0,"nonfinite clock fails closed")
 var result: Dictionary = {"schema":"e03-pure-contract-v1","accepted":failures.is_empty(),"checks":checks,"count":checks.size(),"failures":failures,"real_source_clock_binding_tested":false}
 var file: FileAccess = FileAccess.open(output_path,FileAccess.WRITE)
 if file != null: file.store_string(JSON.stringify(result,"  "))
 print(JSON.stringify({"accepted":failures.is_empty(),"count":checks.size(),"failures":failures}))
 quit(0 if failures.is_empty() else 1)
