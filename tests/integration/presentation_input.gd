extends "res://tests/integration/two_room_input.gd"
## Adapt logical HUD positions to the actual embedded window size.
func click(control: Control) -> void:
 var p: Vector2 = get_viewport().get_final_transform() * control.get_global_rect().get_center()
 for down in [true,false]:
  var e := InputEventMouseButton.new()
  e.button_index = MOUSE_BUTTON_LEFT
  e.position = p
  e.global_position = p
  e.pressed = down
  Input.parse_input_event(e)
  await frames()
