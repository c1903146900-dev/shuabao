extends RefCounted
## Independent integration regressions: interleaved irreversible spend and RNG failure.
const Model = preload("res://scripts/progression/model.gd")
var failures: Array = []
var checks := 0
var serial := 0
func check(ok: bool, label: String):
 checks += 1
 if not ok: failures.append(label)
func send(m, action: String, args: Dictionary = {}) -> Dictionary:
 serial += 1
 return m.command("integration-"+str(serial),action,args)
func run() -> Dictionary:
 var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/progression/fixture.json"))
 var m = Model.new(config)
 send(m,"reward_minion",{"event_id":"fund","gold":100,"xp":0})
 send(m,"buy",{"item":"component"})
 send(m,"context",{"phase":"safe","training":true})
 send(m,"sell",{"uid":m.snapshot().inventory[0].uid})
 send(m,"buy_body")
 var before = m.snapshot()
 check(before.gold==40 and before.body.size()==1,"fixture spends sale proceeds on body")
 var rejected = m.command("blocked-undo","undo_shop")
 check(not rejected.accepted and rejected.reason=="insufficient_gold","undo sale rejects inability to repay")
 check(m.snapshot()==before,"rejected undo preserves full state including undo ledger")
 check(m.command("blocked-undo","undo_shop")==rejected and m.snapshot()==before,"replay of rejected undo has no effects")
 var clone = Model.new(config)
 check(clone.restore(JSON.parse_string(JSON.stringify(m.save()))),"interleaved ledger JSON roundtrip")
 send(m,"reward_minion",{"event_id":"fund-again","gold":50,"xp":0})
 var undo = send(m,"undo_shop")
 check(undo.accepted and m.snapshot().gold==0,"fresh undo can repay after independently earned funds")
 check(m.snapshot().body.size()==1 and m.snapshot().inventory.size()==1,"undo sale restores component but keeps body purchase")
 check(send(m,"undo_shop").accepted and m.snapshot().gold==100 and m.snapshot().inventory.is_empty(),"undo original purchase keeps exactly 50 body expense from 150 earned")
 send(m,"respec")
 check(m.snapshot().body.size()==1 and m.body_effects().AD==1 and m.snapshot().gold==100,"respec cannot refund or erase body")
 var tiny = config.duplicate(true)
 tiny.hexes={"single":{"hero":"fengli","weight":100}}
 var h=Model.new(tiny,"hero",519)
 var initial=h.snapshot()
 check(send(h,"hex_open",{"milestone":1}).reason=="pool_exhausted","exhausted offer rejected")
 check(h.snapshot()==initial,"failed draw restores RNG seen and offers")
 var a=Model.new(config,"hero",519)
 send(a,"hex_open",{"milestone":1})
 var saved=Model.new(config,"hero",1)
 check(saved.restore(JSON.parse_string(JSON.stringify(a.save()))),"RNG and offer checkpoint restore")
 var args={"milestone":1,"slot":3}
 check(a.command("refresh", "hex_refresh",args)==saved.command("refresh","hex_refresh",args) and a.snapshot()==saved.snapshot(),"refresh sequence identical after JSON checkpoint")
 var after=a.snapshot()
 a.command("refresh","hex_refresh",args)
 check(a.snapshot()==after,"same refresh request preserves RNG and quota")
 check(a.command("new-refresh","hex_refresh",args).reason=="refresh_exhausted" and a.snapshot()==after,"new ID cannot refresh same slot twice or move RNG")
 var missing=config.duplicate(true)
 missing.erase("potion_policy")
 var p=Model.new(missing)
 send(p,"reward_minion",{"event_id":"fund","gold":100,"xp":0})
 var p_before=p.snapshot()
 check(send(p,"buy",{"item":"normal"}).reason=="unresolved_policy" and p.snapshot()==p_before,"unconfigured potion experiment cannot silently become default")
 var build=Model.new(config)
 send(build,"reward_minion",{"event_id":"levels","gold":0,"xp":1700})
 for slot in Model.COSTS:
  for rank in range(Model.COSTS[slot].size()):
   send(build,"learn",{"slot":slot,"candidate":slot+"1","expected_rank":rank})
 var spent=0
 for slot in Model.COSTS:
  for rank in range(build.snapshot().skills[slot].rank):spent+=Model.COSTS[slot][rank]
 check(build.snapshot().points+spent==18 and spent==18,"independent 18-point cost conservation")
 return {"checks":checks,"failures":failures,"passed":failures.is_empty()}
