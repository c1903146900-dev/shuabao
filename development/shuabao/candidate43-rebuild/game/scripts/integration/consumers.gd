extends RefCounted
## Local synchronous coordinator. Never emits a consumable request before validation.
const T = preload("res://data/combat/tuning.gd")
const HOOKS = ["stats.v1","stat.AD.v1","stat.attack_speed.v1","stat.max_hp.v1","stat.cooldown_reduction.v1","recovery.v1"]
var receipts := {}
static func hooks_for(hero_id: String) -> Array:
 if hero_id == "fengli":
  var wind_hooks:Array=["stats.v1","recovery.v1","equipment.task_completion.v1"]
  for stat in ["AD","AP","attack_speed","max_hp","defense","move_speed","crit_chance","cooldown_reduction","lifesteal","tenacity","penetration","hp_regen"]:wind_hooks.append("stat."+stat+".v1")
  for id in preload("res://scripts/progression/fengli_catalog.gd").RUNTIME_HEXES:wind_hooks.append("hex.final_design.fengli_"+id.to_lower()+".v1")
  for number in range(1,31):wind_hooks.append("hex.final_design.common_g%02d.v1"%number)
  return wind_hooks
 if hero_id != "xuanlei": return HOOKS.duplicate()
 var hooks: Array = ["stats.v1","recovery.v1","equipment.task_completion.v1","hex.final_design.common_g17.v1"]
 for stat in ["AD","AP","attack_speed","max_hp","defense","move_speed","crit_chance","cooldown_reduction","lifesteal","tenacity","penetration","hp_regen"]: hooks.append("stat."+stat+".v1")
 var tuning = load("res://data/combat/xuanlei_tuning.gd")
 for entry in tuning.hex_catalog(): hooks.append("hex.final_design."+entry.id+".v1")
 for number in range(1,31):
  var hook:String="hex.final_design.common_g%02d.v1"%number
  if hook not in hooks:hooks.append(hook)
 return hooks
func sync_stats(sim: Node, model: RefCounted) -> void:
 if sim.has_method("set_common_model"):sim.set_common_model(model)
 var base := {"AD":T.INITIAL.hero_ad,"AP":0.0,"attack_speed":T.INITIAL.hero_as,"crit_chance":0.0,"cooldown_reduction":0.0,"max_hp":T.INITIAL.hero_hp,"defense":0.0,"move_speed":T.INITIAL.hero_speed,"lifesteal":0.0,"tenacity":0.0,"penetration":0.0,"hp_regen":0.5}
 if model.state.hero_id == "xuanlei":
  var tuning = load("res://data/combat/xuanlei_tuning.gd")
  var source: Dictionary = tuning.hero_stats()
  for key in base:
   var mapped: String = {"AD":"ad","AP":"ap","cooldown_reduction":"cdr","defense":"defence","hp_regen":"regen"}.get(key,key)
   base[key] = source.get(mapped,base[key])
 if model.state.hero_id == "fengli" and model.config.has("final_design_version"):
  var source:Dictionary=preload("res://data/combat/fengli_tuning.gd").hero_stats()
  for key in base:
   var mapped:String={"AD":"ad","AP":"ap","cooldown_reduction":"cdr","defense":"defence","hp_regen":"regen"}.get(key,key)
   base[key]=source.get(mapped,base[key])
 var projected: Dictionary = model.project_stats(base)
 if sim.has_method("set_projected_stats"):
  sim.set_projected_stats(projected)
  if sim.has_method("set_hexes"): sim.set_hexes(model.aggregate_effects().hexes)
 else:
  for pair in [["AD","ad"],["attack_speed","attack_speed"],["max_hp","max_hp"],["cooldown_reduction","cdr"]]: sim.hero.stats[pair[1]] = projected[pair[0]]
 # Raising the maximum never heals; reducing it can only clamp down.
 sim.hero.hp = minf(sim.hero.hp,sim.hero.stats.max_hp)
func use_recovery(sim: Node, model: RefCounted, id: String, uid: int) -> Dictionary:
 if id.is_empty(): return {"accepted":false,"reason":"missing_command_id"}
 if receipts.has(id):
  if receipts[id].uid != uid: return {"accepted":false,"reason":"command_id_conflict"}
  return receipts[id].result.duplicate(true)
 var command := "consume:"+id
 # Prevent a replacement coordinator from replaying an already applied model receipt.
 if model.receipts.has(command): return {"accepted":false,"reason":"already_consumed"}
 if sim.transaction_active: return {"accepted":false,"reason":"transaction_in_progress"}
 if sim.hero.dead: return {"accepted":false,"reason":"not_alive"}
 if sim.phase not in ["preparation","victory","combat"]: return {"accepted":false,"reason":"unsafe_phase"}
 if sim.phase=="combat" and (sim.paused or model.snapshot().phase!="combat"): return {"accepted":false,"reason":"encounter_frozen"}
 if sim.phase in ["preparation","victory"] and model.snapshot().phase!="safe": return {"accepted":false,"reason":"unsafe_phase"}
 if sim.hero.hp >= sim.hero.stats.max_hp: return {"accepted":false,"reason":"full_health"}
 var item := ""
 for entry in model.snapshot().inventory:
  if entry.uid == uid: item = entry.id
 if item.is_empty(): return {"accepted":false,"reason":"missing_item"}
 var recovery: Dictionary = model.config.items[item].get("recovery",{})
 if recovery.get("mode","") != "instant_max_hp_fraction" or recovery.get("refresh_cooldowns",true): return {"accepted":false,"reason":"unsupported_effect"}
 var before: float = sim.hero.hp
 var amount: float = sim.hero.stats.max_hp*float(recovery.amount)
 var result: Dictionary = model.command(command,"use_item",{"uid":uid})
 if result.accepted:
  if sim.has_method("heal"): sim.heal(amount,false)
  else: sim.hero.hp = minf(sim.hero.stats.max_hp,before+amount)
  if sim.has_method("potion_used"): sim.potion_used(item)
  elif sim.has_method("emit_event"): sim.emit_event("potion_used",{"item_id":item,"position":sim.hero.position,"healed":sim.hero.hp-before,"source":"consumable"})
  result["healed"] = sim.hero.hp-before
  result["hp"] = sim.hero.hp
 receipts[id] = {"uid":uid,"result":result.duplicate(true)}
 return result
