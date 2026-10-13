extends "res://tests/ink_shop_ui_host_20261004/shop_panel.gd"
## Original list UI, now a bounded intermediate recipe/quote projection.
## No wallet, inventory owner, stat recomputation, craft algorithm or HP writes.
const LocalText = preload("res://tests/ink_initial_vortex_host_20261004/text_projection.gd")
var recipe_projection: Dictionary = {}

func _ready() -> void:
 super._ready()
 # Small fit adjustment for two recipe lines; this is not the final shop grid.
 theme.default_font_size = 16
 var panel: Control = _title.get_parent().get_parent()
 panel.position = Vector2(100, 38); panel.size.y = 630
 _detail.custom_minimum_size.y = 108
 _detail.add_theme_font_size_override("font_size", 15)

func refresh(force: bool = false) -> void:
 super.refresh(force)
 if not _state.get("ready", false) or not visible: return
 _title.text = LocalText.shop_title(_state.state, _session.initial_flow_diagnostic) + " · 一级合成接线候选"
 if _session.get("funded_fixture") == true: _title.text = _title.text.replace("普通成长入口", "测试资金诊断入口") + " · 1500 TEST初始金币"
 if not _state.last_receipt.is_empty() and not _state.last_receipt.get("accepted", false):
  _receipt.text = "未执行：" + commerce_reason(str(_state.last_receipt.get("reason", "unknown")))

func _detail_for_selected() -> void:
 super._detail_for_selected()
 recipe_projection = {}
 if not _state.get("ready", false) or not _state.catalog.items.has(_selected): return
 var item: Dictionary = _state.catalog.items[_selected]
 var is_recipe: bool = _selected.begins_with("intermediate:")
 if not is_recipe: return
 var ordered: Array = item.get("components", []).duplicate()
 var required: Dictionary = {}
 for part in ordered: required[part] = int(required.get(part, 0)) + 1
 var owned: Dictionary = {}
 for held in _state.state.inventory:
  if required.has(held.id): owned[held.id] = int(owned.get(held.id, 0)) + int(held.count)
 var ingredient_lines: Array[String] = []
 var source_component_total: int = 0
 for part in required:
  var component: Dictionary = _state.catalog.items[part]
  source_component_total += int(component.price) * int(required[part])
  ingredient_lines.append("%s ×%d（持有%d/%d）" % [component.name, int(required[part]), int(owned.get(part, 0)), int(required[part])])
 var combine_fee: int = int(item.price) - source_component_total
 # Display arithmetic describes original recipe only. Actual charge/credit and
 # acceptance always come from the model's disposable atomic quote below.
 var text: String = _detail.text + "\n原配方：" + " + ".join(ingredient_lines)
 text += "\n原合成费 %d金" % combine_fee
 if _quote.get("accepted", false):
  text += " · 本次实际扣款 %d金（已持组件抵扣%d金）" % [int(_quote.charge), int(_quote.credit)]
  _buy.text = "合成 %s（本次 %d金币）" % [item.name, int(_quote.charge)]
 else:
  text += " · 暂不可合成：" + commerce_reason(str(_quote.get("reason", "unknown")))
  _buy.text = "不可合成：" + commerce_reason(str(_quote.get("reason", "unknown")))
 recipe_projection = {"item":_selected, "components":ordered, "required_counts":required, "owned_counts":owned, "source_price":int(item.price), "source_component_total":source_component_total, "combine_fee":combine_fee, "quote":_quote.duplicate(true)}
 _detail.text = text

func _purchase() -> void:
 if _buy.disabled or not _quote.get("accepted", false): return
 _request("craft" if _selected.begins_with("intermediate:") else "buy", {"item":_selected}, _quote.token)

static func commerce_reason(reason: String) -> String:
 if reason.ends_with(":outside_base11_intermediate17_slice") or reason == "outside_base11_intermediate17_slice": return "成装真实效果尚未接入"
 if reason == "mandatory_hex_pending": return "请先完成真实初始四选一"
 return reason_text(reason)
