extends "res://tests/ink_intermediate_shop_ui_20261004/host.gd"
## View lifetime fix only; exact Session, Sim, Controller and Model unchanged.
const SignalSafeShopPanel = preload("res://tests/ink_intermediate_shop_ui_20261004/fix02/shop_panel.gd")
func _create_session_controls() -> void:
 super._create_session_controls()
 if not is_instance_valid(shop_panel): return
 # Startup-only view replacement occurs before any user signal can fire.
 shop_panel.free()
 shop_panel = SignalSafeShopPanel.new(); session_canvas.add_child(shop_panel)
 shop_panel.bind_session(shop_session)
 shop_panel.close_requested.connect(func(): _shop(false))
 shop_panel.transaction_requested.connect(_submit_shop)
 _refresh_session_controls(true)
func _commerce_evidence() -> Dictionary:
 var out: Dictionary = super._commerce_evidence()
 out["ui_view_script"] = "res://tests/ink_intermediate_shop_ui_20261004/fix02/shop_panel.gd"
 out["recipe_projection"] = shop_panel.recipe_projection.duplicate(true) if is_instance_valid(shop_panel) and shop_panel.get_script() == SignalSafeShopPanel else {}
 return out
