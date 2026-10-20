extends RefCounted
const Catalog=preload("res://data/final_design/catalog.gd")
const RUNTIME_PATH="res://tests/ink_q1_foundation_20261004/revision02/data/runtime_tuning.json"
const HERO_ID="yanguizhou"
static func parameter(token:String,rank:int=1)->float:
 return Catalog.parameter(HERO_ID,token,rank)
static func fraction(token:String,rank:int=1)->float:
 return Catalog.fraction(HERO_ID,token,rank)
static func hex_parameter(token:String)->float:
 return Catalog.hex_parameter(HERO_ID+"_"+token.split("-")[0].to_lower(),token)
static func runtime()->Dictionary:
 var parsed=JSON.parse_string(FileAccess.get_file_as_string(RUNTIME_PATH))
 return parsed.duplicate(true) if parsed is Dictionary else {}
static func hero_stats()->Dictionary:
 return hero_stats_from_runtime(runtime())
static func hero_stats_from_runtime(source_runtime:Dictionary)->Dictionary:
 var values:Dictionary=source_runtime.base_stats.duplicate(true)
 values["attack_speed"]=parameter("ATK-2")
 values["attack_range"]=parameter("ATK-3")
 return values
