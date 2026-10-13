extends RefCounted
## One explicitly authored act for integrated mechanic acceptance, not the full campaign.
## The free-wave arena never calls its completion API.
const ACT_ID="siege_trial_act01"
const TITLE="断门关 · 一幕试炼"
const DEFINITION={"name":TITLE,"completion_rule":"boss_defeated_and_coordinator_completed","room_count":3,"prototype_trial":true,"repeat_reward":false}
const ROOMS=[
 {"id":"outer_gate","title":"外城接敌","kind":"ordinary","roles":["minion","minion","pouncer","minion","armored","ranged","pouncer","minion"]},
 {"id":"crossfire_bastion","title":"斜堡合围","kind":"elite","roles":["armored","ranged","pitcher","support","elite","pouncer","armored","ranged","minion","minion"]},
 {"id":"citadel_heart","title":"城心破阵","kind":"boss","roles":["boss","armored","ranged","support","pouncer","ranged","pouncer"]}
]
var active:=false
var stage:=0
var cleared:Dictionary={}
var completed:=false
func enter()->void:
 active=true
func room_data()->Dictionary:
 return ROOMS[clampi(stage,0,ROOMS.size()-1)].duplicate(true)
func room_id(run_id:String)->String:
 return run_id+"/"+ACT_ID+"/"+str(room_data().id)
func roster()->Array:
 var result:Array=[]
 var kinds:Array=room_data().roles
 for i in range(kinds.size()):
  var angle:float=TAU*float(i)/kinds.size()+float(stage)*.61
  var distance:float=12.0+float(i%3)*.6
  result.append({"kind":kinds[i],"position":Vector3(sin(angle)*distance,0,cos(angle)*distance)})
 return result
func register_current_boss(sim:Node,model:RefCounted,run_id:String)->Dictionary:
 if not active or stage!=ROOMS.size()-1:return {"accepted":true,"reason":"not_boss_room"}
 for enemy in sim.enemies:
  if enemy.kind=="boss":return model.register_act_context(sim,ACT_ID,enemy.actor_id,run_id)
 return {"accepted":false,"reason":"authored_boss_missing"}
func record_clear(actual_room_id:String,run_id:String,model:RefCounted)->Dictionary:
 if not active or completed:return {"accepted":false,"reason":"act_not_active"}
 if actual_room_id!=room_id(run_id):return {"accepted":false,"reason":"wrong_trial_room"}
 cleared[actual_room_id]=true
 if stage<ROOMS.size()-1:
  stage+=1
  return {"accepted":true,"reason":"next_room","title":room_data().title}
 if cleared.size()!=ROOMS.size():return {"accepted":false,"reason":"act_rooms_incomplete"}
 var result:Dictionary=model.complete_act(ACT_ID,run_id+"/"+ACT_ID+"/complete")
 if result.accepted:completed=true
 return result
func label()->String:
 return TITLE+" · 已完成" if completed else "%s %d/3 · %s"%[TITLE,stage+1,room_data().title]

func save_to(model:RefCounted)->void:
 model.state.trial_coordinator={"active":active,"stage":stage,"cleared":cleared.duplicate(true),"completed":completed,"act_id":ACT_ID}
func restore_from(model:RefCounted)->void:
 var state:Dictionary=model.state.get("trial_coordinator",{})
 if state.get("act_id","")!=ACT_ID:return
 active=state.get("active",false);stage=int(state.get("stage",0));cleared=state.get("cleared",{}).duplicate(true);completed=state.get("completed",false)
