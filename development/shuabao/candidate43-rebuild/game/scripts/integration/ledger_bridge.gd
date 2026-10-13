extends RefCounted
## The catalog-backed run model is the only XP, currency and skill-point authority.
const Model = preload("res://scripts/integration/run_model.gd")
var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/progression/prototype/catalog.json"))
var model: RefCounted
var serial := 0
func _init(hero_id: String = "fengli") -> void:
 if hero_id == "xuanlei": definitions = preload("res://scripts/progression/xuanlei_catalog.gd").build()
 elif hero_id == "fengli": definitions = preload("res://scripts/progression/fengli_catalog.gd").build()
 model = preload("res://scripts/integration/fengli_run_model.gd").new(definitions,hero_id) if hero_id == "fengli" else Model.new(definitions,hero_id)
 # Capabilities are runtime declarations tied to actual consumers, never restored.
 model.set_supported_hooks(preload("res://scripts/integration/consumers.gd").hooks_for(hero_id))
func command(action: String, args: Dictionary = {}) -> Dictionary:
 serial += 1
 var r: Dictionary = model.command("integration-context-%d" % serial, action, args)
 return {"ok":r.accepted,"reason":r.reason,"state":snapshot()}
func snapshot() -> Dictionary:
 var s: Dictionary = model.snapshot()
 var slots := {}
 for slot in s.skills: slots[slot] = {"skill":s.skills[slot].candidate,"rank":s.skills[slot].rank}
 return {"level":s.level,"earned":s.level+int(s.get("bonus_sp",0)),"leveling_earned":s.level,"bonus_earned":int(s.get("bonus_sp",0)),"available":s.points,"slots":slots,"in_combat":s.phase == "combat","at_training_node":s.training,"refundable_transactions":s.allocations.size(),"authority":"integration/run_model.gd"}
func begin_encounter() -> Dictionary:
 return command("context",{"phase":"combat"})
func end_encounter() -> Dictionary:
 return command("context",{"phase":"safe"})
func invest(slot: String, candidate: String) -> Dictionary:
 return command("learn",{"slot":slot,"candidate":candidate,"expected_rank":model.snapshot().skills[slot].rank})
func undo_last_investment() -> Dictionary:
 return command("undo_skill")
func reset_at_training() -> Dictionary:
 return command("respec")
func set_training_node(present: bool) -> Dictionary:
 return command("context",{"phase":"safe","training":present})

# Only invoke on a newly-created bridge. Never mutate the retained formal authority.
func configure_test(spec: Dictionary) -> Dictionary:
 if model.state.revision != 0: return {"accepted":false,"reason":"test_requires_fresh_authority"}
 var before: Dictionary = model.save()
 model.state.test_mode = true
 var reason := _configure_test(spec)
 if not reason.is_empty(): model.restore(before)
 return {"accepted":reason.is_empty(),"reason":reason}

func _configure_test(spec: Dictionary) -> String:
 var level: int = int(spec.get("level",18))
 if level < 1 or level > 18: return "invalid_level"
 model.state.level = level
 model.state.points = level
 model.state.granted_level_ids = range(1,level+1)
 model.state.training = true
 for slot in ["P","Q","E","R"]:
  var skill: Dictionary = spec.get("skills",{}).get(slot,{"candidate":slot+"1","rank":0})
  var rank: int = int(skill.get("rank",0))
  if rank < 0 or rank > model.COSTS[slot].size(): return "rank_cap"
  for i in range(rank):
   var result: Dictionary = model.command("test-skill-%s-%d" % [slot,i],"learn",{"slot":slot,"candidate":skill.get("candidate",""),"expected_rank":i})
   if not result.accepted: return result.reason
 if spec.get("items",[]).size() > 6: return "inventory_full"
 for id in spec.get("items",[]):
  if not definitions.items.has(id): return "missing_definition"
  if not model._item_support(id): return "unsupported_effect"
  var definition: Dictionary = definitions.items[id]
  var kind: String = definition.get("kind","equipment")
  for existing in model.state.inventory:
   var existing_kind: String = definitions.items[existing.id].get("kind","equipment")
   if kind in ["normal","special"] and existing_kind in ["normal","special"] and kind != existing_kind: return "recovery_mutex"
  var stacked := false
  if kind == "normal":
   for existing in model.state.inventory:
    if existing.id == id:
     if existing.count >= 5: return "normal_cap"
     existing.count += 1
     existing.invested += int(definition.price)
     stacked = true
     break
  if stacked: continue
  model.state.inventory.append({"uid":model.state.next_item,"id":id,"count":1,"invested":int(definition.price)})
  model.state.next_item += 1
 var hexes: Array = spec.get("hexes",[])
 if hexes.size() > 5: return "invalid_hex_count"
 for id in hexes:
  if not definitions.hexes.has(id): return "invalid_hex"
  if id in model.state.selected_hex: return "already_selected"
  if not model.support(definitions.hexes[id]).supported: return "unsupported_effect"
  model.state.selected_hex.append(id)
 # Every earned milestone is explicitly satisfied for this sandbox specification.
 for milestone in model.MILESTONES:
  if milestone <= level: model.state.offers[str(milestone)] = {"slots":[],"selected":"test_override","refresh_used":[],"excluded":[]}
 model.state.gold = 50000
 model.state.shop_undo.clear()
 model.state.allocations.clear()
 model.state.revision += 1
 return ""
