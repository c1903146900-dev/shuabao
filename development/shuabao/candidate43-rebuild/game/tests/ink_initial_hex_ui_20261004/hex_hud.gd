extends Control
## Minimal HUD interface for the unchanged real ProgressionController.
## It contains no authority and cannot mutate SP, skills, offers or inventory.
signal modal_changed(blocked: bool)
const Adapter = preload("res://scripts/ui/hud_adapter.gd")
const HexView = preload("res://tests/ink_initial_hex_ui_20261004/hex_view.gd")
const Style = preload("res://tests/ink_style_specimen_20261004/style.gd")
var adapter = Adapter.new()
var rows: Dictionary = {}
var hex_required: bool = false
var hex_draft: PanelContainer
var shade: ColorRect
var projection: Dictionary = {}
var receipt: Dictionary = {}
func _ready() -> void:
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 theme = Style.ui_theme()
 for slot in ["Q", "E", "R", "P"]:
  var options := OptionButton.new()
  options.add_item("未学习"); options.hide(); add_child(options)
  rows[slot] = {"options":options}
 shade = ColorRect.new(); shade.color = Color(0.04,0.06,0.07,0.88)
 shade.mouse_filter = Control.MOUSE_FILTER_STOP; add_child(shade)
 shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); shade.hide()
 hex_draft = HexView.new(); add_child(hex_draft)
 hex_draft.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
 hex_draft.offset_left = -526; hex_draft.offset_right = 526
 hex_draft.offset_top = -284; hex_draft.offset_bottom = 284
 hex_draft.selected.connect(func(slot: int): adapter.request("hex_select", {"milestone":projection.get("active_milestone", 0), "slot":slot}))
 hex_draft.refreshed.connect(func(slot: int): adapter.request("hex_refresh", {"milestone":projection.get("active_milestone", 0), "slot":slot}))
 hex_draft.hide()
func present_progression(view: Dictionary) -> void:
 projection = view.duplicate(true)
 hex_draft.present(projection)
func set_receipt(message: String, accepted: bool) -> void:
 receipt = {"text":message, "accepted":accepted}
 if hex_required and not accepted: hex_draft.show_error(message)
func set_hex_required(required: bool) -> void:
 if required == hex_required: return
 hex_required = required
 if not required:
  hex_draft.hide(); shade.hide(); modal_changed.emit(false)
func show_required_hex() -> void:
 if hex_draft.visible: return
 shade.show(); hex_draft.show(); hex_draft.present(projection)
 hex_draft.focus_first(); modal_changed.emit(true)
func close_panels() -> void:
 if hex_required:
  set_receipt("请先完成当前海克斯选择", false)
  show_required_hex(); return
 hex_draft.hide(); shade.hide(); modal_changed.emit(false)
func open_supply(_index: int = 0) -> void:
 if hex_required: show_required_hex()
func blocks_gameplay_input() -> bool:
 return hex_required or hex_draft.visible
