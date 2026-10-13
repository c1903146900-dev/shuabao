extends "res://tests/ink_rest_service_20261006/candidate01/host.gd"
## Use the proven rest Session with exact successor admission. P1 Sim and every
## Q/E/R/input lifecycle factory stay inherited without changing script identity.
const RestOrdinarySession = preload("res://tests/ink_rest_service_20261006/candidate01/ordinary01/floor_session.gd")
const RestOrdinaryBinding = preload("res://tests/ink_rest_service_20261006/candidate01/ordinary01/live_binding.gd")
const RestOrdinaryNavigation = preload("res://tests/ink_rest_service_20261006/candidate01/ordinary01/navigation_install.gd")
const REST_RULE_TEXT := "休息点：回满生命、清除Buff和冷却；基础血瓶不补充"
const REST_SETTLED_TEXT := "本次已回满生命、清除Buff和冷却；基础血瓶不补充"
const OLD_REST_TEXT := "休息恢复效果尚待来源定义，当前不加血。"
func _make_floor_session() -> RefCounted:
 return RestOrdinarySession.new()
func _install_source_navigation() -> Dictionary:
 return RestOrdinaryNavigation.apply_to_fresh_ink_sim(sim)
func _rest_hint() -> String:
 if shop_session == null or shop_session.ledger == null or not shop_session._entered_service("rest"):
  return REST_RULE_TEXT
 var entry_id: String = str(shop_session._active_entry.get("receipt_id",""))
 for receipt: Dictionary in shop_session.rest_service.snapshot():
  if receipt.get("accepted",false) and receipt.get("run_id","") == shop_session.run_id and receipt.get("room_id","") == shop_session.active_node_room and receipt.get("entry_id","") == entry_id:
   return REST_SETTLED_TEXT
 return REST_RULE_TEXT
func _refresh_session_controls(force: bool) -> void:
 super._refresh_session_controls(force)
 if is_instance_valid(session_hint):
  session_hint.text = session_hint.text.replace(OLD_REST_TEXT,_rest_hint())
func _commerce_evidence() -> Dictionary:
 var report: Dictionary = super._commerce_evidence()
 report["parent_p1_runtime_source_binding"] = report.get("runtime_source_binding","")
 report["runtime_source_binding"] = FileAccess.get_sha256(RestOrdinaryBinding.BINDING_PATH)
 report["rest_ordinary_overlay"] = true
 return report
func rest_ordinary_report() -> Dictionary:
 return {"binding":FileAccess.get_sha256(RestOrdinaryBinding.BINDING_PATH),"rest_service_binding":RestOrdinaryBinding.REST_SHA,"same_p1_sim":is_instance_valid(sim) and sim.get_script().resource_path == RestOrdinaryBinding.SIM_PATH,"single_owner_intact":shop_session._owner_intact() if shop_session != null and shop_session.ledger != null else false,"rest_hint":_rest_hint(),"native_input_passed":false,"natural_progression_verified":false,"full_floor_passed":false,"flask_consumer_opened":false}
func _write_json(filename: String, contents: Dictionary) -> void:
 var out: Dictionary = contents.duplicate(true)
 out["rest_ordinary_integration"] = rest_ordinary_report()
 super._write_json(filename,out)
