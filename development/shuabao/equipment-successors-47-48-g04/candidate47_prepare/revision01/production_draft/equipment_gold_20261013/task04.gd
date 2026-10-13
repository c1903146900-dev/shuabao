extends RefCounted
## Pure proposal. Gold is the committed original reward receipt's amount.
## This module never credits currency or accepts gameplay evidence by itself.
const ITEM_ID := "final:G04"
const TASK_ID := "task:G04"
const MAX_EXACT := 9007199254740991

static func valid_tuning(t: Dictionary) -> bool:
 if t.size()!=5 or not t.get("thresholds") is Array or t.thresholds.size()!=3 or not t.get("reward_skill_points") is int or t.reward_skill_points!=0:return false
 var previous: int=0
 for threshold: Variant in t.thresholds:
  if not threshold is int or threshold<=previous or threshold>MAX_EXACT:return false
  previous=threshold
 for field: String in ["move_per_stage","regen_per_stage","cdr_per_stage"]:
  if not _number(t.get(field)) or float(t[field])<0.0:return false
 return float(t.move_per_stage)*3.0<=100.0 and float(t.cdr_per_stage)*3.0<=100.0

static func select_unique(inventory: Array, definitions: Dictionary) -> Dictionary:
 var out: Dictionary={"equipped":false,"equipment_id":ITEM_ID,"task_id":TASK_ID,"owned_copies":0,"tuning":{}}
 var definition: Variant=definitions.get(ITEM_ID)
 if not definition is Dictionary or definition.get("mechanism_prepared")!=true or not definition.get("taskG04") is Dictionary or not valid_tuning(definition.taskG04):return out
 var seen: Dictionary={}
 for item: Variant in inventory:
  if not item is Dictionary:return _empty()
  if item.get("id")!=ITEM_ID:continue
  if not item.get("uid") is int or item.uid<0 or not item.get("count") is int or item.count<=0 or seen.has(item.uid):return _empty()
  if out.owned_copies>MAX_EXACT-item.count:return _empty()
  seen[item.uid]=true;out.owned_copies+=item.count
 out.equipped=out.owned_copies>0
 if out.equipped:out.tuning=definition.taskG04.duplicate(true)
 return out

static func evaluate(selection: Dictionary, progress: Variant, stages: Variant, credited_gold: Variant) -> Dictionary:
 if selection.get("equipment_id")!=ITEM_ID or selection.get("equipped")!=true or not selection.get("owned_copies") is int or selection.owned_copies<=0 or not selection.get("tuning") is Dictionary or not valid_tuning(selection.tuning):return _deny("g04_not_equipped")
 var thresholds: Array=selection.tuning.thresholds
 var cap: int=int(thresholds.back())
 if not progress is int or progress<0 or progress>cap or not stages is int or stages<0 or stages>3 or stages!=stage_count(progress,thresholds):return _deny("g04_invalid_progress")
 if not credited_gold is int or credited_gold<0 or credited_gold>MAX_EXACT:return _deny("g04_invalid_credited_gold")
 if stages==3:return _deny("g04_already_completed")
 if credited_gold==0:return _deny("g04_zero_gold")
 # Saturation avoids addition overflow and matches completed-task projection.
 var after: int=progress+mini(credited_gold,cap-progress)
 var after_stages: int=stage_count(after,thresholds)
 var newly_completed: Array=[]
 for stage: int in range(stages+1,after_stages+1):newly_completed.append(stage)
 return {"eligible":true,"reason":"","equipment_id":ITEM_ID,"task_id":TASK_ID,"credited_gold":credited_gold,"progress_before":progress,"progress_after":after,"stages_before":stages,"stages_after":after_stages,"new_stages":newly_completed,"completed":after_stages==3,"reward_skill_points":0}

static func stage_count(progress: int, thresholds: Array) -> int:
 var out: int=0
 for threshold: Variant in thresholds:
  if progress>=int(threshold):out+=1
 return out
static func _number(v: Variant)->bool:return (v is int or v is float) and is_finite(float(v))
static func _empty()->Dictionary:return {"equipped":false,"equipment_id":ITEM_ID,"task_id":TASK_ID,"owned_copies":0,"tuning":{}}
static func _deny(reason: String)->Dictionary:return {"eligible":false,"reason":reason}
