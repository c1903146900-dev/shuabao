extends "res://tests/ink_intermediate_shop_ui_20261004/shop_panel.gd"
## Retire rows only at the exact inherited rebuild boundary. A selling Button
## may still be emitting pressed; detach now, destroy after signal unwinds.
## New rows and real transaction/quote remain synchronous in this same call.
func refresh(force: bool = false) -> void:
 if _session != null:
  var next_state: Dictionary = _session.ui_state()
  if next_state.get("ready", false) and next_state.panel_open and (force or int(next_state.state.revision) != _shown_revision):
   _retire_rows(_list)
   _retire_rows(_inventory)
 super.refresh(force)

func _retire_rows(container: Node) -> void:
 if not is_instance_valid(container): return
 for child in container.get_children():
  _disable_retiring_buttons(child)
  container.remove_child(child)
  child.queue_free()

func _disable_retiring_buttons(node: Node) -> void:
 if node is BaseButton:
  node.disabled = true
 for child in node.get_children(): _disable_retiring_buttons(child)
