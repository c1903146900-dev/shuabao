extends "res://scripts/integration/hero_entry.gd"
## New explicit development entry. Original chooser, host and Sim identities
## remain untouched; visual child attaches only after the genuine room exists.
const Controller=preload("res://visual_rework_20261009/controller.gd")
var visual_room_id=0
var visual_controller:Node3D
func _process(_delta:float)->void:
 if active_hero!="yanguizhou" or not is_instance_valid(active_room):return
 if bool(active_room.get("_mainprep_required")) or bool(active_room.get("_mainprep_pending")):return
 if active_room.get_instance_id()==visual_room_id:return
 visual_room_id=active_room.get_instance_id()
 visual_controller=Controller.new();active_room.add_child(visual_controller);visual_controller.attach_to_host(active_room)
 print("VISUAL_REWORK_ATTACHED_TO_REAL_HOST ",active_room.get_script().resource_path)

func _launch_fresh(hero_id: String) -> void:
 # Validate before destruction, so a missing future scene cannot lose a run.
 var packed = load("res://visual_rework_20261009/runtime_room.tscn" if hero_id=="yanguizhou" else Chooser.ROOMS.get(hero_id, ""))
 if not packed is PackedScene:
  _recover_failed_start("关卡暂时无法载入，当前对局仍保留。")
  return
 var next_room = packed.instantiate()
 if not next_room is Node3D:
  if is_instance_valid(next_room): next_room.free()
  _recover_failed_start("关卡类型无效，当前对局仍保留。")
  return
 if hero_id == "yanguizhou" and not _has_exact_yanguizhou_adapter(next_room):
  next_room.free()
  _recover_failed_start("首层候选入口不匹配，当前对局仍保留。")
  return
 _capture_held_inputs()
 if is_instance_valid(active_room):
  if _is_yanguizhou_room() and not active_room.frontdoor_close_run("frontdoor_confirmed_new_run"):
   next_room.free()
   _recover_failed_start("当前动作尚未结束，请稍后重试；当前对局仍保留。")
   return
  _clear_room_input()
  _stop_room_audio()
  # Immediate free at a deferred boundary removes both formal and test sims,
  # their controllers, callbacks, CanvasLayers, voices and per-room audio bus.
  active_room.free()
 active_room = null
 _pause_nodes.clear()
 _pause_layers.clear()
 _room_focus = null
 confirmation.hide()
 confirm_button.disabled = false
 cancel_button.disabled = false
 # Wait for the current GUI event and queued frees before exposing new input.
 await get_tree().process_frame
 if not is_inside_tree():
  next_room.free()
  return
 active_room = next_room
 active_hero = hero_id
 session_serial += 1
 add_child(active_room)
 # The ink host has its own layers 100/110. Keep its 1024 startup mask above us.
 front_layer.layer = 200 if _is_yanguizhou_room() else 100
 # Only this button receives private copies; shared chooser theme stays immutable.
 for kind:String in ["normal","hover","pressed","focus","disabled"]:
  if _is_yanguizhou_room():
   var local_style:StyleBox=return_button.get_theme_stylebox(kind).duplicate()
   local_style.content_margin_top=4
   local_style.content_margin_bottom=4
   return_button.add_theme_stylebox_override(kind,local_style)
  else:
   return_button.remove_theme_stylebox_override(kind)
 return_button.position = Vector2(1070, 52) if _is_yanguizhou_room() else Vector2(810, 22)
 return_button.size = Vector2(170, 32) if _is_yanguizhou_room() else Vector2(170, 38)
 # Input callbacks run children first in reverse tree order. Keep the fence last.
 move_child(input_fence, get_child_count() - 1)
 _capture_held_inputs()
 _clear_room_input()
 chooser.hide()
 chooser.set_busy(false)
 return_button.show()
 var focus := get_viewport().gui_get_focus_owner()
 if focus: focus.release_focus()
 screen = Screen.RUN


func _has_exact_yanguizhou_adapter(room:Node)->bool:
 if not is_instance_valid(room) or not room is Node3D:return false
 return room.get_script()!=null and room.get_script().resource_path=="res://visual_rework_20261009/runtime_host.gd" or super._has_exact_yanguizhou_adapter(room)
