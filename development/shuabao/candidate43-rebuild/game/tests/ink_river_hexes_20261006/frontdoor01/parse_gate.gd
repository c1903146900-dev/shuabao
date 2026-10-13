extends SceneTree
const Binding=preload("res://tests/ink_river_hexes_20261006/frontdoor01/live_binding.gd")
const FILES = ["res://tests/ink_river_hexes_20261006/frontdoor01/bridge.gd", "res://tests/ink_river_hexes_20261006/frontdoor01/finite_host.gd", "res://tests/ink_river_hexes_20261006/frontdoor01/floor_session.gd", "res://tests/ink_river_hexes_20261006/frontdoor01/host.gd", "res://tests/ink_river_hexes_20261006/frontdoor01/lifecycle_gate.gd", "res://tests/ink_river_hexes_20261006/frontdoor01/live_binding.gd", "res://tests/ink_river_hexes_20261006/frontdoor01/navigation_install.gd", "res://tests/ink_river_hexes_20261006/frontdoor01/planned_adapter.gd", "res://tests/ink_river_hexes_20261006/frontdoor01/planned_chooser.gd", "res://scripts/integration/yanguizhou_first_floor.gd", "res://scripts/ui/hero_chooser.gd"]
func _initialize() -> void:
 var failures: Array[String]=[]
 var binding: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Binding.BINDING_PATH))
 for path: String in Binding.ENTRY_PATHS:
  if FileAccess.get_sha256(path)!=str(binding.ancestor_pin_replacements[path].after):failures.append("planned_alias_missing:"+path)
 for path: String in FILES:
  var source_script: GDScript=load(path)
  if source_script==null or not source_script.can_instantiate():failures.append(path)
 print("INK_RIVER_FRONTDOOR_PARSE ",JSON.stringify({"passed":failures.is_empty(),"scripts":FILES,"failures":failures,"source_binding_sha256":FileAccess.get_sha256(Binding.BINDING_PATH),"runtime_pass":false}))
 quit(0 if failures.is_empty() else 1)
