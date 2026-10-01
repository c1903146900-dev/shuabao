extends RefCounted
## Local synchronous coordinator. Never emits a consumable request before validation.
const T = preload("res://data/combat/tuning.gd")
const HOOKS = ["stats.v1","stat.AD.v1","stat.attack_speed.v1","stat.max_hp.v1","stat.cooldown_reduction.v1","recovery.v1"]
var receipts := {}
func sync_stats(sim: Node, model: RefCounted) -> void:
 var base := {"AD":T.INITIAL.hero_ad,"AP":0.0,"attack_speed":T.INITIAL.hero_as,"crit_chance":0.0,"cooldown_reduction":0.0,"max_hp":T.INITIAL.hero_hp,"defense":0.0,"move_speed":T.INITIAL.hero_speed,"lifesteal":0.0,"tenacity":0.0,"penetration":0.0,"hp_regen":0.5}
 var projected: Dictionary = model.project_stats(base)
 for pair in [["AD","ad"],["attack_speed","attack_speed"],["max_hp","max_hp"],["cooldown_reduction","cdr"]]:
  sim.hero.stats[pair[1]] = projected[pair[0]]
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
 if sim.phase != "victory" or model.snapshot().phase != "safe": return {"accepted":false,"reason":"unsafe_phase"}
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
  sim.hero.hp = minf(sim.hero.stats.max_hp,before+amount)
  result["healed"] = sim.hero.hp-before
  result["hp"] = sim.hero.hp
 receipts[id] = {"uid":uid,"result":result.duplicate(true)}
 return result
