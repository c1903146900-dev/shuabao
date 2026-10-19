extends Node
## Display/measurement only. Never initializes a Host, pauses it, or alters input.
var report: Dictionary = {}
var layer: CanvasLayer
var caption: Label
var watched_room: WeakRef
var entry_ref: WeakRef
var awaiting_usable := false

func _ready() -> void:
 layer = CanvasLayer.new()
 layer.name = "EntryLoadingStatus"
 layer.layer = 1100
 add_child(layer)
 var backing := ColorRect.new()
 backing.color = Color("17272b")
 backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
 layer.add_child(backing)
 caption = Label.new()
 caption.position = Vector2(48, 80)
 caption.add_theme_font_size_override("font_size", 24)
 caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
 layer.add_child(caption)
 layer.hide()

func begin(entry: Node, click_usec: int) -> void:
 entry_ref = weakref(entry)
 watched_room = null
 awaiting_usable = false
 report = {"click_usec":click_usec, "launch_begin_usec":Time.get_ticks_usec(), "phases":[], "status":"loading", "performance_passed":false}
 layer.show()

func mark(key: String) -> void:
 report[key] = Time.get_ticks_usec()

func stage(message: String, key: String) -> void:
 caption.text = message
 mark(key + "_text_set_usec")
 # Post-draw is a renderer callback, not proof of OS compositor presentation.
 await RenderingServer.frame_post_draw
 mark(key + "_postdraw_usec")
 report.phases.append(key)

func watch_first_usable(room: Node) -> void:
 watched_room = weakref(room)
 awaiting_usable = true

func fail() -> void:
 mark("failed_usec")
 report.status = "failed_original_recovery"
 awaiting_usable = false
 layer.hide()

func _process(_delta: float) -> void:
 if not awaiting_usable: return
 var entry: Node = entry_ref.get_ref() as Node
 var room: Node = watched_room.get_ref() as Node
 if not is_instance_valid(entry) or not is_instance_valid(room) or entry.active_room != room:
  awaiting_usable = false
  layer.hide()
  report.status = "owner_retired"
  return
 if str(entry.active_hero) == "yanguizhou":
  if not str(room.get("floor_error")).is_empty() or not str(room.get("startup_session_error")).is_empty() or bool(room.get("finished")):
   fail() # Let the original Host's error/exit UI remain visible; no false recovery.
   report.status = "host_error_original_ui"
   return
  if bool(room.get("_mainprep_required")) or bool(room.get("_mainprep_pending")) or not bool(room.get("initial_started")): return
 # Observe admission, hide our drawing, then record first completed draw.
 awaiting_usable = false
 mark("first_usable_admitted_usec")
 layer.hide()
 await RenderingServer.frame_post_draw
 mark("first_usable_postdraw_usec")
 report.status = "ready_observed"
