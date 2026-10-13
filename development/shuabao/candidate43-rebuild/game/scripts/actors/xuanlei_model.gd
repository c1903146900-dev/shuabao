extends RefCounted
const T = preload("res://data/combat/xuanlei_tuning.gd")
var actor_id = "xuanlei"
var base_stats = T.hero_stats()
var projected_base_stats = T.hero_stats()
var stats = T.hero_stats()
var hp = 600.0
var position = Vector3(0,0,5)
var facing = Vector3.FORWARD
var move_intent = Vector3.ZERO
var aim_point = Vector3.ZERO
var cooldowns = {"attack":0.0,"shift":0.0,"q":0.0,"e":0.0,"r":0.0,"passive":0.0}
var loadout = {"q":"q1","e":"e1","r":"r1","passive":"p1"}
var ranks = {"q":1,"e":1,"r":1,"passive":1}
var lock_time = 0.0
var movement_lock_left = 0.0
var dash_left = 0.0
var dash_direction = Vector3.FORWARD
var invulnerable_left = 0.0
var untargetable = false
var dead = false
var knockback = Vector3.ZERO
var stun_left = 0.0
var slow_left = 0.0
var slow_amount = 0.0
var cast_state: Dictionary = {}
var self_rescue_used = false
var death_state = "alive"
var xp_progress = 0.0
var gold = 0
var attack_index = 0
var bone_stacks = 0
var crowd_count = 0
var hexes: Array = []
var shields: Dictionary = {}
var standing_time = 0.0
func has_hex(id: String) -> bool: return T.hex_id(id) in hexes
func ruin_factor() -> float:
 if loadout.passive!="p3" or ranks.passive<=0: return 0.0
 var threshold: float=T.fraction("P3-1",ranks.passive)
 return clampf((threshold-hp/stats.max_hp)/maxf(threshold,0.001),0,1)
func ad() -> float: return stats.ad*(1.0+T.fraction("P3-2",ranks.passive)*ruin_factor()) if loadout.passive=="p3" and ranks.passive>0 else stats.ad
func defence() -> float:
 var bonus: float=bone_stacks*T.fraction("P1-4",ranks.passive) if loadout.passive=="p1" and ranks.passive>0 else 0.0
 return stats.defence*(1.0+bonus)
func attack_speed() -> float:
 var bonus: float=T.hex_value("this_city",3)/100.0 if cast_state.has("e3") and has_hex("this_city") and standing_time>T.hex_value("this_city",1) else 0.0
 return minf(2.5,stats.attack_speed*(1.0+bonus))
func speed() -> float:
 return stats.move_speed*(1.0-T.fraction("E1-2",ranks.e) if cast_state.has("e1") else 1.0)*(1.0-slow_amount if slow_left>0 else 1.0)
func tenacity() -> float:
 if cast_state.has("r1"): return T.fraction("R1-3",cast_state.r1.rank)
 return clampf(stats.tenacity,0,1)
func lifesteal() -> float: return stats.lifesteal+(T.fraction("P3-3",ranks.passive)*ruin_factor() if loadout.passive=="p3" and ranks.passive>0 else 0.0)
func shield_total() -> float:
 var amount: float=0.0
 for shield in shields.values(): amount+=shield.amount
 return amount
func snapshot() -> Dictionary:
 return {"actor_id":actor_id,"model_scale":stats.get("model_scale",1.0),"attack_range":stats.get("attack_range",T.parameter("ATK-6")),"hp":hp,"max_hp":stats.max_hp,"position":position,"facing":facing,"move_intent":move_intent,"ad":ad(),"defence":defence(),"attack_speed":attack_speed(),"move_speed":speed(),"tenacity":tenacity(),"lifesteal":lifesteal(),"cooldowns":cooldowns.duplicate(true),"loadout":loadout.duplicate(true),"ranks":ranks.duplicate(true),"dead":dead,"death_state":death_state,"self_rescue_used":self_rescue_used,"xp_progress":xp_progress,"invulnerable":invulnerable_left>0 or dash_left>0,"untargetable":untargetable,"cast_state":cast_state.duplicate(true),"shield":shield_total(),"shields":shields.duplicate(true),"bone_stacks":bone_stacks,"attack_index":attack_index,"hexes":hexes.duplicate(),"standing_time":standing_time,"movement_lock_left":movement_lock_left,"dash_left":dash_left,"dash_direction":dash_direction}
func set_projected_stats(projected: Dictionary) -> void:
 for key in projected:
  if stats.has(key): stats[key]=projected[key]; projected_base_stats[key]=projected[key]
 hp=minf(hp,stats.max_hp)
