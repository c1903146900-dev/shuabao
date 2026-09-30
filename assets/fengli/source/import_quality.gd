@tool
extends Node
func configure() -> String:
 var config := ConfigFile.new()
 var path := "res://assets/fengli/fengli.glb.import"
 assert(config.load(path)==OK)
 config.set_value("params","_subresources",{"nodes":{"PATH:AnimationPlayer":{"optimizer/enabled":false}}})
 assert(config.save(path)==OK)
 call_deferred("reimport")
 return "PRECISE_IMPORT_REQUESTED"
func reimport() -> void:
 EditorInterface.get_resource_filesystem().reimport_files(PackedStringArray(["res://assets/fengli/fengli.glb"]))
