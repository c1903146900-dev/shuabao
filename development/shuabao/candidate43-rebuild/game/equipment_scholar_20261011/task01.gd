extends RefCounted
## Pure proposal only. Its evidence must be verified by the live same-stack Sim
## bridge again inside the Model command. Public booleans never grant authority.
const ITEM_ID := "final:G01"
const TASK_ID := "task:G01"
const MAX_EXACT := 9007199254740991
const FAMILIES := ["q1","q2","q3","e1","e2","e3"]
static func valid_tuning(t: Dictionary) -> bool:
 if t.size()!=5 or t.get("stage_id")!="task:G01:1" or not t.get("reward_skill_points") is int or t.get("reward_skill_points")!=0: return false
 if not t.get("threshold") is int or t.threshold<=0 or t.threshold>MAX_EXACT: return false
 return _number(t.get("evolved_ap")) and float(t.evolved_ap)>=0.0 and _number(t.get("evolved_cdr")) and float(t.evolved_cdr)>=0.0 and float(t.evolved_cdr)<=100.0
static func select_unique(inventory: Array, definitions: Dictionary) -> Dictionary:
 var out: Dictionary={"equipped":false,"equipment_id":ITEM_ID,"task_id":TASK_ID,"owned_copies":0,"tuning":{}}
 var definition: Variant=definitions.get(ITEM_ID)
 if not definition is Dictionary or not _true(definition.get("mechanism_prepared")) or not definition.get("taskG01") is Dictionary or not valid_tuning(definition.taskG01): return out
 var seen: Dictionary={}
 for item: Variant in inventory:
  if not item is Dictionary:return _empty()
  if item.get("id")!=ITEM_ID:continue
  if not item.get("uid") is int or item.uid<0 or not item.get("count") is int or item.count<=0 or seen.has(item.uid):return _empty()
  if out.owned_copies>9223372036854775807-item.count:return _empty()
  seen[item.uid]=true;out.owned_copies+=item.count
 out.equipped=out.owned_copies>0
 if out.equipped:out.tuning=definition.taskG01.duplicate(true)
 return out
static func evaluate(selection: Dictionary, progress: Variant, completed: Variant, claims: Dictionary, scope: Dictionary, evidence: Dictionary) -> Dictionary:
 if not _true(selection.get("equipped")) or selection.get("equipment_id")!=ITEM_ID or not selection.get("tuning") is Dictionary or not valid_tuning(selection.tuning):return _deny("g01_not_equipped")
 if not selection.get("owned_copies") is int or selection.owned_copies<=0:return _deny("g01_invalid_copies")
 if not valid_scope(scope):return _deny("g01_invalid_scope")
 if not progress is int or progress<0 or progress>selection.tuning.threshold or not completed is bool:return _deny("g01_invalid_progress")
 if completed or progress==selection.tuning.threshold:return _deny("g01_already_completed")
 if claims.size()!=2 or claims.get("scope")!=scope or not claims.get("casts") is Dictionary:return _deny("g01_invalid_claims")
 for key: Variant in claims.casts:
  if not key is String or not key.is_valid_int() or int(key)<=0 or not claims.casts[key] is bool or not claims.casts[key]:return _deny("g01_invalid_claim")
 if evidence.get("schema")!="g01_original_effect_v1" or evidence.get("scope")!=scope or evidence.get("family") not in FAMILIES:return _deny("g01_invalid_effect")
 if not evidence.get("cast_id") is int or evidence.cast_id<=0 or not evidence.get("effect_serial") is int or evidence.effect_serial<=0:return _deny("g01_invalid_identity")
 if not _true(evidence.get("successful_release")) or not _true(evidence.get("actual_effect")):return _deny("g01_no_effect")
 var key: String=str(evidence.cast_id)
 if claims.casts.has(key):return _deny("g01_cast_already_counted")
 var after: int=mini(selection.tuning.threshold,progress+1)
 return {"eligible":true,"reason":"","equipment_id":ITEM_ID,"task_id":TASK_ID,"cast_key":key,"progress_before":progress,"progress_after":after,"completed":after==selection.tuning.threshold,"stage_id":"task:G01:1" if after==selection.tuning.threshold else "","reward_key":"task:G01:permanent_evolution" if after==selection.tuning.threshold else "","reward_skill_points":0}
static func valid_scope(scope: Dictionary)->bool:
 return scope.size()==4 and _text(scope.get("run_id")) and _text(scope.get("actor_id")) and scope.get("generation") is int and scope.generation>=0 and _text(scope.get("room_id"))
static func _number(v: Variant)->bool:return (v is int or v is float) and is_finite(float(v))
static func _text(v: Variant)->bool:return v is String and not v.strip_edges().is_empty()
static func _empty()->Dictionary:return {"equipped":false,"equipment_id":ITEM_ID,"task_id":TASK_ID,"owned_copies":0,"tuning":{}}
static func _deny(reason: String)->Dictionary:return {"eligible":false,"reason":reason}
static func _true(v: Variant)->bool:return v is bool and v
