extends "res://scripts/actors/hero_model_core.gd"
const T=preload("res://data/combat/fengli_tuning.gd")
var permanent_ad:float=0.0
var permanent_q1_damage:float=0.0
var q1_stacks:int=0
var credited_kills:int=0
var p3_progress:int=0
var q1_kill_ids:Dictionary={}
func _init()->void:
 actor_id="fengli"
 initialize_stats(T.hero_stats())
func has_hex(id:String)->bool:return T.hex_id(id) in hexes
func ad()->float:return float(stats.ad)+permanent_ad
func attack_speed()->float:
 var factor:float=1.0
 if cast_state.has("e3"):factor+=T.fraction("E3-3",int(cast_state.e3.rank))
 if cast_state.has("h02"):factor+=T.hex_fraction("h02",1)
 if cast_state.has("h09"):factor+=T.hex_fraction("h09",1)
 return minf(float(T.runtime().attack_speed_cap),float(stats.attack_speed)*factor)
func speed()->float:
 var factor:float=1.0+T.fraction("E3-2",int(cast_state.e3.rank)) if cast_state.has("e3") else 1.0
 return float(stats.move_speed)*factor*(1.0-slow_amount if slow_left>0 else 1.0)
func tenacity()->float:
 var bonus:float=T.fraction("E3-4",int(cast_state.e3.rank)) if cast_state.has("e3") else 0.0
 return clampf(float(stats.tenacity)+bonus,0.0,1.0)
func critical_chance()->float:
 return clampf(float(stats.crit_chance)+(T.hex_fraction("h14",1) if cast_state.has("e3") and has_hex("h14") else 0.0),0.0,1.0)
func lifesteal()->float:
 return float(stats.lifesteal)+(T.hex_fraction("h14",2) if cast_state.has("e3") and has_hex("h14") else 0.0)
func basic_lifesteal()->float:
 return lifesteal()+(T.fraction("P1-1",int(ranks.passive)) if loadout.passive=="p1" and ranks.passive>0 else 0.0)
func snapshot()->Dictionary:
 var result:Dictionary=super.snapshot()
 result.merge({"permanent_ad":permanent_ad,"permanent_q1_damage":permanent_q1_damage,"q1_stacks":q1_stacks,"credited_kills":credited_kills,"p3_progress":p3_progress,"crit_chance":critical_chance(),"forced_motion":dash_left>0 or cast_state.has("q2") or cast_state.has("e1_pierce"),"basic_lifesteal":basic_lifesteal()})
 return result
