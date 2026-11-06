extends "res://tests/ink_first_floor_user_route_20261005/runtime01/route_map.gd"
## Cache visual work only. The host still obtains fresh authoritative choices on
## every visible frame, and its original selection handler revalidates clicks.
## Native overview, scroll, resize, reward previews and drawing remain inherited.
var _visual_ready: bool = false
var _visual_available: Dictionary = {}
var _visual_completed: Dictionary = {}
var _visual_selected: String = ""
var _visual_entered: String = ""
var _visual_input_blocked: bool = false
var _visual_neon: bool = false
var _visual_identity: String = ""
var _visual_definition: Dictionary = {}
var _visual_buttons: Dictionary = {}

func present(choices: Array, state: Dictionary, input_blocked: bool) -> void:
 # Match the original's string coercion, duplicate collapse and insertion order.
 # Never retain the caller's mutable Arrays/Dictionaries or cache its validation.
 input_allowed = not input_blocked
 available.clear(); completed.clear()
 for choice: Dictionary in choices: available[str(choice.node_id)] = true
 for receipt: Dictionary in state.get("completed_rows", []): completed[str(receipt.identity.node_id)] = true
 selected = str(state.get("selected_identity", {}).get("node_id", ""))
 entered = selected if str(state.get("status", "")) == "entered" else ""
 # Button permission is refreshed even on cache hits, including correction of a
 # direct disabled-state change. This is a display projection, not click authority.
 for row: Dictionary in definition.get("rows", []):
  for node: Dictionary in row.nodes:
   var id: String = str(node.id)
   var button: Button = buttons[id]
   button.disabled = input_blocked or not available.has(id)
 # Dictionary equality compares membership, not insertion order. A fresh caller
 # ordering therefore updates available/scroll receipts but needs no new styles.
 # Definition copies and button identities also invalidate mutation/rebinding;
 # hashing or memoizing the route/source authority is deliberately absent.
 if _visual_ready and _visual_available == available and _visual_completed == completed and _visual_selected == selected and _visual_entered == entered and _visual_input_blocked == input_blocked and _visual_neon == neon_palette_enabled and _visual_identity == _bound_identity and _visual_definition == definition and _visual_buttons == buttons:
  return
 super.present(choices, state, input_blocked)
 _visual_available = available.duplicate()
 _visual_completed = completed.duplicate()
 _visual_selected = selected
 _visual_entered = entered
 _visual_input_blocked = input_blocked
 _visual_neon = neon_palette_enabled
 _visual_identity = _bound_identity
 _visual_definition = definition.duplicate(true)
 _visual_buttons = buttons.duplicate()
 _visual_ready = true

func _process(delta:float)->void:
 # Open at legal current choices, never spend five seconds touring locked Boss.
 overview_seen=true
 super._process(delta)
