extends RefCounted
## One-time text correction after the original Host and HUD are ready.
## Original HUD exposes no top-button variable; use its unique direct rectangle.
const HUD_PATH := "res://tests/ink_style_specimen_20261004/revision10_hud/hud.gd"
static func apply(hud: Control) -> Button:
 if not is_instance_valid(hud) or hud.get_script()==null or hud.get_script().resource_path!=HUD_PATH:return null
 var matches: Array[Button]=[]
 for child in hud.get_children():
  if child is Button and child.position==Vector2(920,18) and child.size==Vector2(105,32):matches.append(child)
 if matches.size()!=1:return null
 var button: Button=matches[0]
 if button.text not in ["商店  B","商店  P"] or button.focus_mode!=Control.FOCUS_NONE:return null
 var connections: Array=button.pressed.get_connections()
 if connections.size()!=1 or not connections[0].callable.is_valid():return null
 button.text="商店  P"
 assert(button.pressed.get_connections()==connections)
 return button
