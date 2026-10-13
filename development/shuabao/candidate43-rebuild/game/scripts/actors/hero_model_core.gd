extends RefCounted
## Hero-neutral actor state. Values are neutral interface defaults, not hero tuning.
## A concrete hero supplies base_stats/projected stats and overrides derived attributes.
var actor_id: String = "hero"
var base_stats: Dictionary = {"ad":0.0,"ap":0.0,"attack_speed":1.0,"crit_chance":0.0,"cdr":0.0,"max_hp":1.0,"defence":0.0,"move_speed":0.0,"lifesteal":0.0,"tenacity":0.0,"penetration":0.0,"regen":0.0,"attack_range":0.0,"model_scale":1.0}
var projected_base_stats: Dictionary = base_stats.duplicate(true)
var stats: Dictionary = base_stats.duplicate(true)
var hp: float = 1.0
var position := Vector3(0,0,5)
var facing := Vector3.FORWARD
var move_intent := Vector3.ZERO
var aim_point := Vector3.ZERO
var cooldowns: Dictionary = {"attack":0.0,"shift":0.0,"q":0.0,"e":0.0,"r":0.0,"passive":0.0}
var loadout: Dictionary = {"q":"","e":"","r":"","passive":""}
var ranks: Dictionary = {"q":0,"e":0,"r":0,"passive":0}
var lock_time: float = 0.0 # Combat-action gate, never a locomotion gate.
var movement_lock_left: float = 0.0 # Only explicit authored restrictions may set it.
var dash_left: float = 0.0
var dash_direction := Vector3.FORWARD
var invulnerable_left: float = 0.0
var untargetable: bool = false
var dead: bool = false
var knockback := Vector3.ZERO
var stun_left: float = 0.0
var slow_left: float = 0.0
var slow_amount: float = 0.0
var cast_state: Dictionary = {}
var self_rescue_used: bool = false
var death_state: String = "alive"
var xp_progress: float = 0.0
var gold: int = 0
var attack_index: int = 0
var hexes: Array = []
var shields: Dictionary = {}
var standing_time: float = 0.0

func initialize_stats(values: Dictionary, refill: bool = true) -> void:
 base_stats.merge(values.duplicate(true),true)
 projected_base_stats=base_stats.duplicate(true)
 stats=base_stats.duplicate(true)
 hp=float(stats.max_hp) if refill else minf(hp,float(stats.max_hp))

func has_hex(id: String) -> bool: return id in hexes
func ad() -> float: return float(stats.ad)
func defence() -> float: return float(stats.defence)
func attack_speed() -> float: return clampf(float(stats.attack_speed),0.001,2.5)
func speed() -> float: return maxf(0.0,float(stats.move_speed)*(1.0-clampf(slow_amount,0,1) if slow_left>0 else 1.0))
func tenacity() -> float: return clampf(float(stats.tenacity),0,1)
func lifesteal() -> float: return float(stats.lifesteal)
func shield_total() -> float:
 var total: float=0
 for shield in shields.values(): total+=maxf(0,float(shield.amount))
 return total

func set_projected_stats(projected: Dictionary) -> void:
 for key in projected:
  projected_base_stats[key]=projected[key]
  stats[key]=projected[key]
 hp=minf(hp,float(stats.max_hp))

func snapshot() -> Dictionary:
 var result: Dictionary={"actor_id":actor_id,"model_scale":stats.get("model_scale",1.0),"attack_range":stats.get("attack_range",0.0),"hp":hp,"max_hp":stats.max_hp,"position":position,"facing":facing,"move_intent":move_intent,"ad":ad(),"defence":defence(),"attack_speed":attack_speed(),"move_speed":speed(),"tenacity":tenacity(),"lifesteal":lifesteal(),"cooldowns":cooldowns,"loadout":loadout,"ranks":ranks,"dead":dead,"death_state":death_state,"self_rescue_used":self_rescue_used,"xp_progress":xp_progress,"invulnerable":invulnerable_left>0,"untargetable":untargetable,"cast_state":cast_state,"shield":shield_total(),"shields":shields,"attack_index":attack_index,"hexes":hexes,"standing_time":standing_time,"movement_lock_left":movement_lock_left,"dash_left":dash_left,"dash_direction":dash_direction}
 result.merge(_hero_snapshot(),true)
 return result.duplicate(true)

func _hero_snapshot() -> Dictionary: return {}
