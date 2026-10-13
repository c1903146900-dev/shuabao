extends RefCounted
## Tracks physical edges across a modal, including Q which router does not latch.
var pressed_keys: Dictionary = {}
var pressed_buttons: Dictionary = {}
var retired_keys: Dictionary = {}
var retired_buttons: Dictionary = {}
var blocked: bool = false
func set_blocked(value: bool) -> void:
 if value:
  retired_keys.merge(pressed_keys, true)
  retired_buttons.merge(pressed_buttons, true)
 blocked = value
func observe(event: InputEvent) -> bool:
 var retired: bool = false
 if event is InputEventKey:
  var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
  retired = retired_keys.has(key)
  if event.pressed:
   pressed_keys[key] = true
   if blocked: retired_keys[key] = true
  else:
   pressed_keys.erase(key); retired_keys.erase(key)
 elif event is InputEventMouseButton:
  retired = retired_buttons.has(event.button_index)
  if event.pressed:
   pressed_buttons[event.button_index] = true
   if blocked: retired_buttons[event.button_index] = true
  else:
   pressed_buttons.erase(event.button_index); retired_buttons.erase(event.button_index)
 return retired and not blocked
func focus_lost() -> void:
 retired_keys.merge(pressed_keys, true)
 retired_buttons.merge(pressed_buttons, true)
