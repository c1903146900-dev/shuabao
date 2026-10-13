extends RefCounted
## Source-final Wind adapter. Original source values are never interpolated or copied.
const Design=preload("res://data/final_design/catalog.gd")
const HERO_ID:="fengli"
const VERSION:="fengli-v03-integration-1"
static var _runtime:Dictionary={}
static var _animation:Dictionary={}
static func runtime()->Dictionary:
 if _runtime.is_empty():_runtime=JSON.parse_string(FileAccess.get_file_as_string("res://data/combat/fengli_runtime_tuning.json"))
 return _runtime.duplicate(true)
static func parameter(token:String,rank:int=1)->float:return Design.parameter(HERO_ID,token,rank)
static func fraction(token:String,rank:int=1)->float:return Design.fraction(HERO_ID,token,rank)
static func hex_id(id:String)->String:
 return id.to_lower() if id.begins_with(HERO_ID+"_") or id.begins_with("common_") else HERO_ID+"_"+id.to_lower()
static func hex_value(id:String,index:int=1)->float:
 var canonical:String=hex_id(id)
 var token:String=canonical.trim_prefix(HERO_ID+"_").trim_prefix("common_").to_upper()+"-"+str(index)
 return Design.hex_parameter(canonical,token)
static func hex_fraction(id:String,index:int=1)->float:return hex_value(id,index)/100.0
static func hero_stats()->Dictionary:
 var result:Dictionary=runtime().base_stats
 result["attack_speed"]=parameter("ATK-2")
 result["attack_range"]=parameter("ATK-3")
 result["model_scale"]=1.0
 return result
static func animation_contract()->Dictionary:
 if _animation.is_empty():_animation=JSON.parse_string(FileAccess.get_file_as_string("res://assets/fengli/animation_contract_final.json"))
 return _animation.duplicate(true)
static func animation(clip:String)->Dictionary:return animation_contract().get("clips",{}).get(clip,{}).duplicate(true)
static func timing(clip:String)->Array:
 var data:Dictionary=animation(clip)
 return [float(data.get("phase_markers_s",{}).get("contact",0.0)),float(data.get("duration_s",.25))]
static func hex_catalog()->Array:
 var entries:Array=[]
 for id in Design.hex_ids(HERO_ID,false):entries.append(Design.hex_definition(id))
 return entries
