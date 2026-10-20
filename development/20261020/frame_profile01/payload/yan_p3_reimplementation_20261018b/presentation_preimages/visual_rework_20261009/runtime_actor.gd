extends "res://tests/ink_ultimate_brush_art_20261008/candidate01/hero_view.gd"
## Explicit runtime-GLTF successor. Original numeric clip consumer is inherited intact.
const Runtime_BINDING="res://runtime_converted_assets/r2_conversion_binding.json"
const Runtime_BINDING_SHA="99fddf1917f3ae2922c9d4dee1f8f5fd428f8052eb8b59374a515c5b38f4b2d6"
func _ultimate_standard_import_uid_errors()->Array[String]:
 var errors:Array[String]=[]
 if FileAccess.get_sha256(Runtime_BINDING)!=Runtime_BINDING_SHA:return ["runtime_conversion_binding_changed"]
 var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Runtime_BINDING))
 if data.get("schema","")!="runtime-gltf-successor-r2-1" or data.get("editor_equivalent",true):return ["runtime_conversion_schema"]
 for rel:String in data.files:
  if FileAccess.get_sha256("res://"+rel)!=data.files[rel]:errors.append("runtime_conversion_resource_changed:"+rel)
 var descriptor=ConfigFile.new()
 if descriptor.load(Ultimate_ASSET+".import")!=OK:return ["runtime_descriptor_missing"]
 if descriptor.get_value("remap","path","")!=data.remap or descriptor.get_value("deps","source_file","")!=Ultimate_ASSET:errors.append("runtime_mapping_changed")
 var packed=ResourceLoader.load(Ultimate_ASSET,"PackedScene") as PackedScene
 if packed==null or not ResourceLoader.exists(str(data.remap)):errors.append("runtime_scene_missing")
 print("EXPLICIT_RUNTIME_GLTF_BINDING ",JSON.stringify({"source":Ultimate_ASSET,"remap":data.remap,"loaded_path":packed.resource_path if packed else "","errors":errors,"editor_equivalent":false}))
 return errors
