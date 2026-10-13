extends SceneTree
const Host = preload("res://tests/ink_intermediate_shop_ui_20261004/fix02/host.gd")
const Gate = preload("res://tests/ink_intermediate_shop_ui_20261004/fix02/ui_gate.gd")
func _initialize() -> void:
 var host = Host.new()
 print("INTERMEDIATE_SHOP_HOST_PARSE_ONLY ", host.get_script().resource_path)
 host.free()
 quit(0)
