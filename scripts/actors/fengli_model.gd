extends RefCounted
const T = preload("res://data/combat/tuning.gd")
var actor_id: String = "fengli"
var stats: Dictionary = T.hero_stats()
var hp: float = T.INITIAL.hero_hp
var position: Vector3 = Vector3(0, 0, 5)
var facing: Vector3 = Vector3.FORWARD
var move_intent: Vector3 = Vector3.ZERO
var aim_point: Vector3 = Vector3(0, 0, 0)
var cooldowns: Dictionary = {"attack":0.0,"shift":0.0,"q":0.0,"e":0.0,"r":0.0,"passive":0.0}
var loadout: Dictionary = {"q":"q1","e":"e3","r":"r1","passive":"p3"}
var ranks: Dictionary = {"q":1,"e":1,"r":1,"passive":1}
var lock_time: float = 0.0
var dash_left: float = 0.0
var dash_direction: Vector3 = Vector3.FORWARD
var overload_left: float = 0.0
var q1_stacks: int = 0
var kill_progress: int = 0
var permanent_ad: float = 0.0
var invulnerable_left: float = 0.0
var untargetable: bool = false
var dead: bool = false
var knockback: Vector3 = Vector3.ZERO
var stun_left: float = 0.0
var slow_left: float = 0.0
var slow_amount: float = 0.0
var cast_state: Dictionary = {}
var self_rescue_used: bool = false
var death_state: String = "alive"
var xp_progress: float = 100.0
var gold: int = 0
func ad() -> float:
 return stats.ad + permanent_ad
func attack_speed() -> float:
 return minf(T.CONFIRMED.as_cap, stats.attack_speed * (1.0 + (T.ranked("e3_bonus",ranks.e) if overload_left > 0 else 0.0)))
func speed() -> float:
 return stats.move_speed * (1.0 + (T.ranked("e3_bonus",ranks.e) if overload_left > 0 else 0.0)) * (1.0 - slow_amount if slow_left > 0 else 1.0)
func tenacity() -> float:
 return minf(1.0, stats.tenacity + (T.ranked("e3_bonus",ranks.e) if overload_left > 0 else 0.0))
func snapshot() -> Dictionary:
 return {"actor_id":actor_id,"hp":hp,"max_hp":stats.max_hp,"position":position,"facing":facing,
 "move_intent":move_intent,"ad":ad(),"attack_speed":attack_speed(),"move_speed":speed(),"tenacity":tenacity(),
 "cooldowns":cooldowns.duplicate(true),"loadout":loadout.duplicate(true),"ranks":ranks.duplicate(true),
 "q1_stacks":q1_stacks,"overload_left":overload_left,"kill_progress":kill_progress,"permanent_ad":permanent_ad,
 "dead":dead,"death_state":death_state,"self_rescue_used":self_rescue_used,"xp_progress":xp_progress,
 "invulnerable":invulnerable_left > 0,"untargetable":untargetable,"cast_state":cast_state.duplicate(true)}
