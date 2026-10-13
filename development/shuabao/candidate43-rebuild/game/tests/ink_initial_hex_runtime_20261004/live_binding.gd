extends RefCounted
## Versioned exact-script/hash admission. No inferred capability from catalog names.
const SIM_PATH="res://tests/ink_initial_hex_runtime_20261004/ink_initial_sim.gd"
const BINDING_PATH="res://tests/ink_initial_hex_runtime_20261004/source_binding.json"
const MANIFEST_PATH="res://tests/ink_initial_hex_runtime_20261004/capabilities.json"
const EXPECTED_BINDING="c997eab5df81084d7ca970c76464389e4cf47954ae8271c1b18ae3a8b27cec7a"
const Catalog=preload("res://tests/ink_initial_hex_runtime_20261004/ink_initial_catalog.gd")
const ADAPTER_HOOKS=["stats.v1","recovery.v1","equipment.task_completion.v1","stat.AD.v1","stat.AP.v1","stat.attack_speed.v1","stat.max_hp.v1","stat.defense.v1","stat.move_speed.v1","stat.crit_chance.v1","stat.cooldown_reduction.v1","stat.lifesteal.v1","stat.tenacity.v1","stat.penetration.v1","stat.hp_regen.v1"]
static func read_capabilities(sim: Node,include_source_adapter_hooks: bool=false)->Dictionary:
 if not is_instance_valid(sim) or sim.get_script()==null or sim.get_script().resource_path!=SIM_PATH:return _deny("wrong_ink_sim_script")
 if FileAccess.get_sha256(BINDING_PATH)!=EXPECTED_BINDING:return _deny("ink_binding_changed")
 var binding: Variant=JSON.parse_string(FileAccess.get_file_as_string(BINDING_PATH))
 var manifest: Variant=JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
 if not binding is Dictionary or not manifest is Dictionary:return _deny("ink_manifest_missing")
 if manifest.get("schema",0)!=1 or manifest.get("hero_id","")!="yanguizhou" or manifest.get("source_binding_id","")!=EXPECTED_BINDING:return _deny("ink_manifest_identity")
 if manifest.get("source_implemented_hooks",[])!=Catalog.FIRST_SLICE_HEX_HOOKS or manifest.get("runtime_candidates",[])!=["Q1"]:return _deny("ink_manifest_capability_mismatch")
 if not binding.get("runtime_map") is Dictionary or binding.runtime_map.is_empty():return _deny("ink_manifest_files_missing")
 for relative in binding.runtime_map:
  if not relative is String or relative.begins_with("/") or ".." in relative.split("/"):return _deny("ink_binding_path_invalid")
  if FileAccess.get_sha256("res://"+relative)!=binding.runtime_map[relative].sha256:return _deny("ink_dependency_digest_mismatch:"+relative)
 var hooks: Array=manifest.source_implemented_hooks.duplicate()
 if include_source_adapter_hooks:hooks.append_array(ADAPTER_HOOKS)
 return {"accepted":true,"reason":"","capabilities":{"schema_version":1,"hero_id":"yanguizhou","source_binding_id":EXPECTED_BINDING,"runtime_candidates":["Q1"],"supported_hooks":hooks,"ordinary_entry_ready":false,"scope":"Lv1 eight source candidates; finite results and normal UI acceptance separate"}}
static func _deny(reason: String)->Dictionary:return {"accepted":false,"reason":reason}
