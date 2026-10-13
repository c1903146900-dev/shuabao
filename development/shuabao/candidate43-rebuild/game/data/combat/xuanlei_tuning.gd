extends RefCounted
## Runtime adapter for the final source-authoritative design; no rank interpolation.
const Design = preload("res://data/final_design/catalog.gd")
const VERSION = "xuanlei-v03-integration-1"
const ARENA_HALF_EXTENT = 18.0
const BASE_ATTACK_SPEED = 1.0 / 0.70
const BASIC_DAMAGE_SCALE = 0.574
const HEX_ALIASES = {"gate_cleave":"h01","double_echo":"h02","double_chain":"h03","close_chain":"h04","body_weapon":"h05","no_crowding":"h06","welcome":"h07","again":"h08","no_brakes":"h09","wall_kill":"h10","comrades":"h11","this_city":"h12","target":"h13","unbroken":"h14","fourth":"h15","return_gate":"h16"}
const ALIASES = {
 "q1_ad":"Q1-5","q1_hp":"Q1-6","q1_cd":"Q1-9",
 "q2_ad":"Q2-5","q2_shield":"Q2-6","q2_cd":"Q2-8","q2_range":"Q2-1",
 "q3_ad":"Q3-4","q3_collision":"Q3-8","q3_push":"Q3-5","q3_cd":"Q3-10",
 "e1_duration":"E1-1","e1_reduction":"E1-4","e1_ad":"E1-8","e1_cd":"E1-10",
 "e2_ad":"E2-6","e2_wall":"E2-8","e2_cd":"E2-11",
 "e3_duration":"E3-2","e3_cd":"E3-5",
 "p1_defence":"P1-4","p2_ad":"P2-4","p2_heal":"P2-5","p3_ad":"P3-2","p3_leech":"P3-3",
 "r1_ad":"R1-9","r1_pressure_cap":"R1-6","r1_cd":"R1-13",
 "r2_ad":"R2-8","r2_hp":"R2-9","r2_wall":"R2-12","r2_finish_ad":"R2-16","r2_finish_hp":"R2-17","r2_cd":"R2-18"
}
static func parameter(token: String, rank: int=1) -> float:
 return Design.parameter("xuanlei",token,maxi(1,rank))
static func fraction(token: String, rank: int=1) -> float:
 return Design.fraction("xuanlei",token,maxi(1,rank))
static func ranked(key: String, rank: int) -> float:
 if key=="e2_speed": return parameter("E2-1",rank)/parameter("E2-2",rank)
 var token: String=ALIASES.get(key,key)
 var definition: Dictionary=Design.parameter_data("xuanlei",token)
 return fraction(token,rank) if str(definition.get("unit","")).contains("%") else parameter(token,rank)
static func hero_stats() -> Dictionary:
 return {"ad":42.0,"ap":0.0,"attack_speed":parameter("ATK-5"),"crit_chance":0.0,"cdr":0.0,"max_hp":600.0,"defence":30.0,"move_speed":5.2,"lifesteal":0.0,"tenacity":0.0,"penetration":0.0,"regen":0.5}
static func hex_id(id: String) -> String:
 if id.begins_with("xuanlei_"): id=id.trim_prefix("xuanlei_")
 return "xuanlei_"+str(HEX_ALIASES.get(id,id)).to_lower()
static func hex_value(id: String, index: int=1) -> float:
 var canonical: String=hex_id(id)
 var token: String=canonical.trim_prefix("xuanlei_").to_upper()+"-"+str(index)
 return Design.hex_parameter(canonical,token)
static func hex_catalog() -> Array:
 var result: Array=[]
 for id in Design.hex_ids("xuanlei",false):
  var source: Dictionary=Design.hex_definition(id)
  result.append({"id":id,"name":source.name,"dependency":str(source.requires).to_lower(),"description":source.description,"effects":{"mechanism":id},"status":"source_final","requires":source.requires,"stats":{},"effect_key":id,"required_hooks":["hex."+id+".v1"]})
 return result
static func skill_description(candidate: String, rank: int) -> String:
 return Design.description("xuanlei",candidate,rank)
