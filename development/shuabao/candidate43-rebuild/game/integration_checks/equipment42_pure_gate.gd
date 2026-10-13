extends SceneTree
## Pure-contract fixture only. These dictionaries do not authenticate live Sim
## events; source/Host tests must separately establish the witness interface.
const Task = preload("res://equipment_blood_trial_20261009/task03.gd")
var checks: Array = []
var failed: Array = []
var output_path: String = "user://equipment42_g03_pure_gate.json"

func _initialize() -> void:
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--equipment-result="): output_path = arg.trim_prefix("--equipment-result=")
 run.call_deferred()

func check(ok: bool, label: String) -> void:
 checks.append({"accepted":ok,"label":label})
 if not ok: failed.append(label)

func scope() -> Dictionary:
 return {"run_id":"pure-run","actor_id":"player","generation":1,"room_id":"room-a"}
func tuning() -> Dictionary:
 return {"health_threshold":35.0,"threshold":500.0,"stage_id":"task:G03:1","reward_skill_points":1}
func definitions() -> Dictionary:
 return {Task.ITEM_ID:{"mechanism_prepared":true,"taskG03":tuning()}}
func selected(copies: int = 1) -> Dictionary:
 return Task.select_unique([{"id":Task.ITEM_ID,"uid":1,"count":copies}],definitions())
func claims(s: Dictionary) -> Dictionary:
 return {"scope":s.duplicate(true),"sequences":{}}
func evidence(amount: float = 100.0, hp: float = 349.0, maximum: float = 1000.0, sequence: int = 1) -> Dictionary:
 var s: Dictionary = scope()
 var event: Dictionary = {"kind":"damage","source":"q1","target":"enemy-a","cast_id":1,"sequence":sequence,"generation":s.generation,"room_id":s.room_id,"amount":amount}
 var commit: Dictionary = {"target":"enemy-a","rank_category":"ordinary","target_hp_before":amount+100.0,"target_hp_after":100.0,"amount":amount,"owner_actor_id":"yanguizhou","owner_hp":hp,"owner_max_hp":maximum}
 var witness: Dictionary = {"scope":s,"proof":"original_damage_hp_commit","commit_serial":sequence,"source":"q1","target":"enemy-a","cast_id":1}
 for flag: String in Task.FLAGS: witness[flag] = true
 return {"schema":Task.SCHEMA,"event":event,"commit":commit,"witness":witness}
func evaluate(e: Dictionary, progress: float = 0.0, completed: bool = false) -> Dictionary:
 return Task.evaluate(selected(),progress,completed,claims(scope()),scope(),e)

func run() -> void:
 check(Task.valid_tuning(tuning()),"original35percent and500multiples tuning")
 var one: Dictionary = evaluate(evidence())
 check(one.get("eligible",false) and one.ratio == 0.1 and one.progress_after == 0.1 and not one.completed,"one actual100 over commit max1000 accumulates0.1 not100")
 check(not evaluate(evidence(100.0,350.0)).eligible,"exact35percent pauses")
 check(not evaluate(evidence(100.0,351.0)).eligible,"above35percent pauses")
 check(evaluate(evidence(100.0,349.0),23.5).progress_after == 23.6,"fractional progress resumes without clearing")
 var two: Dictionary = Task.evaluate(selected(2),0.0,false,claims(scope()),scope(),evidence())
 check(two.eligible and two.progress_after == one.progress_after,"double equipment count does not multiply task ratio")
 var first: Dictionary = evaluate(evidence(100.0,300.0,1000.0))
 var second: Dictionary = evaluate(evidence(100.0,300.0,2000.0,2),first.progress_after)
 check(is_equal_approx(second.progress_after,0.15),"different commit maxHP denominators sum per packet")
 var boundary: Dictionary = evaluate(evidence(500.0,300.0,1000.0),499.5)
 check(boundary.eligible and boundary.progress_after == 500.0 and boundary.completed and boundary.reward_skill_points == 1,"499.5 plus0.5 completes exactly once")
 check(boundary.stage_id == "task:G03:1" and boundary.reward_key == "task:G03:permanent_sp","original one-stage one-SP reward keys")
 var rounded: Dictionary = Task.accumulate(499.99999999999994,0.0,0.00000000000004,500.0)
 check(not rounded.completed and rounded.progress == 500.0 and rounded.carry < 0.0,"upward rounding alone cannot finish an insufficient500-multiple total")
 var resumed: Dictionary = Task.accumulate(rounded.progress,rounded.carry,0.00000000000002,500.0)
 check(resumed.completed and resumed.progress == 500.0 and resumed.carry == 0.0,"retained sub-ULP carry participates in next real increment")
 var wide: Dictionary = Task.accumulate(0.1,0.0,499.9,500.0)
 check(not wide.completed and wide.progress == 500.0 and wide.carry < 0.0,"wide addition retains below-threshold binary remainder")
 var wide_resume: Dictionary = Task.evaluate(selected(),wide.progress,false,claims(scope()),scope(),evidence(),wide.carry)
 check(wide_resume.eligible and wide_resume.completed,"high equals threshold with negative carry remains live for the next real packet")
 check(not evaluate(evidence(),500.0,true).eligible,"already complete cannot award twice")
 check(not evaluate(evidence(),500.0,false).eligible,"inconsistent threshold state rejected")
 var capped: Dictionary = evaluate(evidence(10000.0,300.0,1000.0),499.0)
 check(capped.progress_after == 500.0,"completion saturates at500")
 var seen: Dictionary = claims(scope());seen.sequences[1] = true
 check(not Task.evaluate(selected(),0.0,false,seen,scope(),evidence()).eligible,"exact source event identity deduplicates")
 seen.sequences = {2:true}
 check(Task.evaluate(selected(),0.0,false,seen,scope(),evidence()).eligible,"nested newer sequence does not discard an earlier outer packet")
 var missing: Dictionary = Task.select_unique([],definitions())
 check(not Task.evaluate(missing,123.5,false,claims(scope()),scope(),evidence()).eligible,"sold-out state freezes retained progress")
 check(evaluate(evidence(),123.5).progress_after == 123.6,"repurchase resumes retained fractional progress")
 var room_e: Dictionary = evidence();room_e.event.room_id = "room-b";room_e.witness.scope.room_id = "room-b"
 var room_scope: Dictionary = scope();room_scope.room_id = "room-b"
 check(Task.evaluate(selected(),123.5,false,claims(room_scope),room_scope,room_e).eligible,"new actual room retains run progress with new claims")
 check(not Task.evaluate(selected(),0.0,false,claims(scope()),scope(),room_e).eligible,"old/wrong room witness rejected")
 for rank: String in ["ordinary","elite","boss"]:
  var e: Dictionary = evidence();e.commit.rank_category = rank
  check(evaluate(e).eligible,"all original ranks accepted: " + rank)
 for flag: String in Task.FLAGS:
  var e: Dictionary = evidence();e.witness[flag] = false
  check(not evaluate(e).eligible,"missing internal proof rejected: " + flag)
 var public_only: Dictionary = evidence().event
 check(not evaluate(public_only).eligible,"public damage dictionary is not internal evidence")
 for value: float in [0.0,-1.0,INF,NAN]:
  var e: Dictionary = evidence();e.commit.amount = value;e.event.amount = value
  check(not evaluate(e).eligible,"invalid or zero effective damage rejected: " + str(value))
 for value: float in [0.0,-1.0,INF,NAN]:
  var e: Dictionary = evidence();e.commit.owner_max_hp = value
  check(not evaluate(e).eligible,"invalid commit denominator rejected: " + str(value))
 var dead: Dictionary = evidence();dead.commit.owner_hp = 0.0
 check(not evaluate(dead).eligible,"dead owner cannot create qualifying progress")
 var drift: Dictionary = evidence();drift.commit.target_hp_after = 101.0
 check(not evaluate(drift).eligible,"actual committed target HP delta must match amount")
 var zero_delta: Dictionary = evidence();zero_delta.commit.target_hp_before = 100.0;zero_delta.commit.target_hp_after = 100.0;zero_delta.commit.amount = 0.0000000001;zero_delta.event.amount = 0.0000000001
 check(not evaluate(zero_delta).eligible,"tiny amount within subtraction tolerance cannot prove zero actual HP loss")
 var overkill: Dictionary = evidence();overkill.commit.target_hp_before = 25.0;overkill.commit.target_hp_after = 0.0;overkill.commit.amount = 25.0;overkill.event.amount = 25.0
 check(evaluate(overkill).ratio == 0.025,"effective source HP loss already caps overkill")
 var replay: Dictionary = evidence();replay.event.replay = true
 check(evaluate(replay).eligible,"G03 adds no unauthored replay-flag exclusion to real commits")
 for lethal: bool in [false,true]:
  var e: Dictionary = evidence();e.event.source = "yanguizhou_p1";e.event.p1_supplement = true;e.event.final_damage_already_settled = true;e.witness.source = "yanguizhou_p1";e.witness.proof = "original_p1_atomic_hp_commit"
  if lethal: e.commit.target_hp_before = 100.0;e.commit.target_hp_after = 0.0
  check(evaluate(e).eligible,"independent atomic P1 contract accepts " + ("lethal" if lethal else "nonlethal"))
 var fake_p1: Dictionary = evidence();fake_p1.event.source = "yanguizhou_p1";fake_p1.witness.source = "yanguizhou_p1"
 check(not evaluate(fake_p1).eligible,"ordinary proof cannot impersonate independent P1 atomic path")
 var malformed: Dictionary = tuning();malformed.health_threshold = 0.0
 check(not Task.valid_tuning(malformed),"zero health threshold tuning rejected")
 var malformed_inventory: Array = [{"id":Task.ITEM_ID,"uid":1,"count":1},{"id":Task.ITEM_ID,"uid":1,"count":1}]
 check(not Task.select_unique(malformed_inventory,definitions()).equipped,"duplicate item identity fails closed")
 var result: Dictionary = {"schema":"g03-pure-helper-contract-v1","accepted":failed.is_empty(),"checks":checks,"failures":failed,"count":checks.size(),"runtime_source_authentication_tested":false,"engine_scope":"pure helper only"}
 var output: FileAccess = FileAccess.open(output_path,FileAccess.WRITE)
 if output != null: output.store_string(JSON.stringify(result,"  "))
 print(JSON.stringify({"accepted":failed.is_empty(),"count":checks.size(),"failures":failed}))
 quit(0 if failed.is_empty() else 1)
