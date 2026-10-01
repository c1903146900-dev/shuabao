extends SceneTree
const Model = preload("res://scripts/integration/run_model.gd")
var count := 0
var failures := []
func check(value: bool, label: String) -> void:
 count += 1
 if not value:
  push_error(label)
  failures.append(label)
func _initialize() -> void:
 var defs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/progression/prototype/catalog.json"))
 var m = Model.new(defs,"fengli")
 m.set_supported_hooks(["stats.v1","stat.AD.v1"])
 var grant := {"event_id":"one","room":"room1","gold":1000,"xp":1000000}
 check(m.command("r1","reward_minion",grant).accepted,"grant")
 var earned: Dictionary = m.snapshot()
 check(earned.level == 18 and earned.points == 18 and earned.granted_level_ids.size() == 18,"level is sole point source and cap18")
 check(m.command("r1","reward_minion",grant).accepted and m.snapshot() == earned,"same request idempotent")
 check(not m.command("r2","reward_minion",grant).accepted and m.snapshot() == earned,"same reward different request rejected atomically")
 check(not m.command("invalid","reward_minion",{"event_id":"bad","gold":1,"xp":1,"points":1}).accepted and m.snapshot() == earned,"extra points refused atomically")
 for pair in [["P","P1",3],["Q","Q1",5],["E","E1",5],["R","R1",1]]:
  for rank in range(pair[2]): check(m.command("learn-%s-%s"%[pair[0],rank],"learn",{"slot":pair[0],"candidate":pair[1],"expected_rank":rank}).accepted,"learn authorized rank")
 check(m.snapshot().points == 4,"14 spent plus4 available equals18")
 check(not m.command("r_gate","learn",{"slot":"R","candidate":"R1","expected_rank":1}).accepted and m.snapshot().points == 4,"unresolved R gate remains closed")
 check(m.command("buy","buy",{"item":"iron_blade"}).accepted and m.aggregate_effects().stats.AD == 8,"only enabled AD catalog entry")
 for action in ["buy_body","hex_open","use_item"]:
  var before: Dictionary = m.snapshot()
  check(not m.command("closed-"+action,action,{}).accepted and m.snapshot() == before,"stage closed "+action)
 var unsupported := 0
 for id in m.shop_catalog():
  if not m.shop_catalog()[id].availability.supported:
   var before: Dictionary = m.snapshot()
   check(not m.command("buy-"+id,"buy",{"item":id}).accepted and m.snapshot() == before,"unsupported atomic rejection "+id)
   unsupported += 1
 check(unsupported > 10,"unsupported paths actually covered")
 var before_death: Dictionary = m.snapshot()
 var penalty := {"event_id":"room1/true_dead/1"}
 check(m.command("death","death_penalty",penalty).accepted,"death penalty")
 var after_death: Dictionary = m.snapshot()
 check(after_death.xp == int(floor(before_death.xp*0.7)) and after_death.level == 18 and after_death.points == 4 and after_death.gold == before_death.gold,"penalty only current XP")
 check(m.command("death","death_penalty",penalty).accepted and m.snapshot() == after_death,"repeated death request unchanged")
 check(not m.command("death2","death_penalty",penalty).accepted and m.snapshot() == after_death,"repeated death event unchanged")
 print("RUN_AUTHORITY_REPORT ",JSON.stringify({"checks":count,"unsupported_items":unsupported,"failures":failures}))
 quit(0 if failures.is_empty() else 1)
