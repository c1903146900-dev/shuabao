extends RefCounted
const Existing = preload("res://equipment_rage_20261010/adapter.gd")
const Passive26 = preload("passive26.gd")
const Prior = preload("res://equipment_regeneration_20261009/adapter.gd")
const ITEM_ID := "final:D01"
const SOURCE := "res://docs/equipment_source_20261004/correction_0959/equipment_system_extracted.json"
const STATS := [["max_health","health_points","max_hp",500.0,1.0],["AD","attack_points","AD",30.0,1.0],["AP","ability_points","AP",35.0,1.0]]
const COMPONENTS := {"intermediate:I17":1150,"intermediate:I01":1100,"base:B06":450}

static func build(numeric: Dictionary) -> Dictionary:
 var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
 if not source is Dictionary: return Prior._deny("d01_original_source_missing")
 return build_from_source(numeric,source)

static func build_from_source(numeric: Dictionary, source: Dictionary) -> Dictionary:
 var prior: Dictionary = Existing.build_from_source(numeric,source)
 if not prior.get("accepted",false): return prior
 var count: int = 0
 for definition: Dictionary in prior.definitions.values():
  if definition.get("supported",false): count+=1
 if count!=44 or prior.definitions.has(ITEM_ID): return Prior._deny("exact_44_prior_equipment_required")
 var item: Dictionary = Prior._one(source.get("equipment"),"id",ITEM_ID)
 if item.get("name")!="巨像心核" or item.get("tier")!="final" or item.get("mechanism_ids")!=["passive:26"]: return Prior._deny("exact_d01_original_required")
 if item.get("source_price")!=3150 or item.get("source_component_total")!=2700 or item.get("source_combine_fee")!=450: return Prior._deny("exact_d01_original_prices_required")
 var catalog: Dictionary = Prior._one(numeric.get("catalog"),"owner_id",ITEM_ID)
 if catalog.get("name")!=item.name or catalog.get("kind")!="final" or catalog.get("source_code")!=item.get("source_code") or catalog.get("mechanism_ids")!="passive:26" or catalog.get("source_attributes")!=item.get("source_attributes") or catalog.get("source_effects")!=item.get("source_effects") or not Prior._text(catalog.get("source_ref")): return Prior._deny("d01_catalog_mismatch")
 if not item.get("source_attributes_parsed") is Array or item.source_attributes_parsed.size()!=STATS.size(): return Prior._deny("d01_stats_schema_mismatch")
 var stats: Dictionary = {}
 var references: Array = []
 var allowed: Array = [ITEM_ID+".price"]
 for spec: Array in STATS:
  var key: String = ITEM_ID+".stat."+str(spec[0])
  allowed.append(key)
  var row: Variant = numeric.parameters.get(key)
  var original: Dictionary = Prior._one(item.source_attributes_parsed,"stat",str(spec[0]))
  if original.get("value")!=spec[3] or original.get("unit")!=("percent_points" if spec[1]=="percent_points" else "flat") or not Prior._valid_entry(row,str(spec[1])) or float(row.source_value)!=float(spec[3]): return Prior._deny("d01_stat_mismatch:"+key)
  if spec[1]=="percent_points" and float(row.value)>100.0: return Prior._deny("d01_stat_bounds:"+key)
  stats[spec[2]]=float(row.value)*float(spec[4])
  references.append(Prior._reference(key,row,float(spec[4])))
 for key: Variant in numeric.parameters:
  if str(key).begins_with(ITEM_ID+".") and key not in allowed: return Prior._deny("unsupported_d01_parameter:"+str(key))
 var price: Variant = numeric.parameters.get(ITEM_ID+".price")
 if not Prior._valid_gold(price) or float(price.source_value)!=3150.0: return Prior._deny("d01_price_mismatch")
 references.append(Prior._reference(ITEM_ID+".price",price,1.0))
 var seen: Dictionary = {}
 var original_seen: Dictionary = {}
 if not item.get("components") is Array or item.components.size()!=3: return Prior._deny("d01_original_recipe_mismatch")
 for row: Variant in item.components:
  if not row is Dictionary or row.get("item_id") not in COMPONENTS or original_seen.has(row.item_id) or row.get("quantity")!=1: return Prior._deny("d01_original_recipe_mismatch")
  original_seen[row.item_id]=true
 var components: Array = []
 var total: float = 0.0
 for row: Variant in numeric.recipes:
  if not row is Dictionary: return Prior._deny("d01_recipe_schema_mismatch")
  if row.get("result_id")!=ITEM_ID: continue
  var id: Variant = row.get("component_id")
  if id not in COMPONENTS or seen.has(id) or row.get("recipe_id")!=ITEM_ID+"<-"+str(id) or not Prior._whole(row.get("quantity")) or float(row.quantity)!=1.0 or not Prior._text(row.get("source_ref")): return Prior._deny("d01_recipe_mismatch")
  var original: Dictionary = Prior._one(source.get("equipment"),"id",str(id))
  var entry: Variant = numeric.parameters.get(str(id)+".price")
  if original.get("source_price")!=COMPONENTS[id] or not Prior._valid_gold(entry) or float(entry.source_value)!=float(COMPONENTS[id]): return Prior._deny("d01_component_price_mismatch")
  seen[id]=true;total+=float(entry.value)
  components.append({"item_id":id,"quantity":1,"price":int(entry.value),"source_ref":row.source_ref})
 if seen.size()!=3 or total>float(price.value): return Prior._deny("d01_recipe_incomplete")
 var derived: Dictionary = Prior._one(numeric.get("derived_combine_fees"),"item_id",ITEM_ID)
 if derived.get("unit")!="gold" or derived.get("current_total_price")!=price.value or derived.get("current_component_total")!=total or derived.get("combine_fee")!=float(price.value)-total: return Prior._deny("d01_derived_fee_mismatch")
 var original_passive: Dictionary = Prior._one(source.get("passives"),"id","passive:26")
 var text: String = "每拥有100点由装备、锻体及局内效果提供的额外最大生命，获得2点攻击力和3点法术强度。最多计算1200额外生命。"
 if original_passive.get("name")!="血肉铸兵" or original_passive.get("source_effect")!=text: return Prior._deny("d01_passive_original_mismatch")
 var mechanism: Dictionary = Prior._one(numeric.get("mechanisms_original"),"owner_id","passive:26")
 if mechanism.get("name")!="血肉铸兵" or mechanism.get("source_text")!=text: return Prior._deny("d01_passive_numeric_mismatch")
 var tuning: Dictionary = {}
 var passive_allowed: Array = []
 for spec: Array in [["health_step","health_points",100.0],["health_cap","health_points",1200.0],["ad_per_step","attack_points",2.0],["ap_per_step","ability_points",3.0]]:
  var key: String = "passive:26."+str(spec[0])
  passive_allowed.append(key)
  var row: Variant = numeric.parameters.get(key)
  if not Prior._valid_entry(row,str(spec[1])) or float(row.source_value)!=float(spec[2]): return Prior._deny("d01_passive_parameter_mismatch:"+key)
  tuning[spec[0]]=float(row.value);references.append(Prior._reference(key,row,1.0))
 for key: Variant in numeric.parameters:
  if str(key).begins_with("passive:26.") and key not in passive_allowed: return Prior._deny("unsupported_d01_passive_parameter:"+str(key))
 if not Passive26.valid_tuning(tuning): return Prior._deny("invalid_d01_tuning")
 var out: Dictionary = prior.duplicate(true)
 out.definitions[ITEM_ID]={"supported":true,"reason":"","mechanism_prepared":true,"runtime_complete":false,"shop_admitted":false,"runtime_status":"inert_until_original_colossus_consumer_bound","name":item.name,"tier":"final","stats":stats,"passives":["passive:26"],"actives":[],"passive26":tuning,"parameters":references,"original_source":item.duplicate(true),"base_stat_stacking":"per_legal_copy","passive_stacking":"one_same_name_effect","recipe":{"components":components,"full_price":int(price.value),"component_total":int(total),"combine_fee":int(float(price.value)-total),"unit":"gold"}}
 return out
