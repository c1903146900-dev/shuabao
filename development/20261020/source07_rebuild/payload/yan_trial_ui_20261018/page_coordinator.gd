extends Node
## Rebuilt from source06. Presentation requests only; original input/signals stay.
var room: Node
var page := ""
var requested := "skills"
var last_status := ""
var last_growth := true
var last_map := true
var initialized := false
var writes: Array[Dictionary] = []
var shade: ColorRect
var title: Label
var done: Button
var route_button: Button

static func choose_page(f: Dictionary, request: String) -> String:
 if f.blocked: return "blocked"
 if request == "skills" and f.learn: return "skills"
 if request == "map" and f.route: return "map"
 return "room"

func bind_owner(value: Node) -> void:
 room = value
 name = "RebuiltRunPages"
 room.add_child(self)
 shade = ColorRect.new()
 shade.color = Color("17272b")
 shade.mouse_filter = Control.MOUSE_FILTER_STOP
 room.session_canvas.add_child(shade)
 room.session_canvas.move_child(shade, 0)
 title = Label.new()
 title.add_theme_font_size_override("font_size", 26)
 title.mouse_filter = Control.MOUSE_FILTER_IGNORE
 room.session_canvas.add_child(title)
 done = Button.new()
 done.pressed.connect(_finish)
 room.session_canvas.add_child(done)
 route_button = Button.new()
 route_button.text = "路线 M"
 route_button.pressed.connect(_show_map)
 room.session_canvas.add_child(route_button)

func _facts() -> Dictionary:
 var status: String = str(room.shop_session.status)
 return {"blocked":room._mainprep_required or room._mainprep_pending or room.finished or room.diagnostic or room.sim.hero.dead or room.shop_session.panel_open or room.shop_session.initial_modal_open or room.initial_hud.hex_required or room.initial_hud.hex_draft.visible or status in ["completed", "defeated", "aborted"],
 "learn":room._learning_panel_allowed(),
 # Exact runtime01 Session.available_choices/select admission. Service is NOT ready.
 "route":status in ["preparation", "between_rooms"] and room.floor_error.is_empty()}

func present() -> void:
 if not is_instance_valid(room): deactivate(); return
 var f: Dictionary = _facts()
 var status: String = str(room.shop_session.status)
 if initialized:
  # Original Button callback/K/M handler changes these requests before presenter.
  if bool(room.growth_open_requested) != last_growth:
   requested = "skills" if room.growth_open_requested else ("map" if f.route else "none")
  if bool(room.map_visible_requested) != last_map:
   requested = "map" if room.map_visible_requested else "none"
 if status != last_status:
  if status == "between_rooms": requested = "map"
  elif status in ["combat", "service", "completed", "defeated", "aborted"]: requested = "none"
 last_status = status
 page = choose_page(f, requested)
 var skills: bool = page == "skills"
 var map: bool = page == "map"
 var sheet: bool = skills or map
 if not sheet: _restore()
 # Request flags are presentation state only. No original signals disconnected.
 _write(room, &"growth_open_requested", skills)
 _write(room, &"map_visible_requested", map)
 last_growth = skills
 last_map = map
 initialized = true
 _write(room.initial_hud.growth_panel, &"visible", skills)
 _write(room.route_map, &"visible", map)
 _write(room.session_next, &"visible", map)
 if sheet:
  _write(room.hud, &"visible", false)
  _write(room.session_equipment, &"visible", false)
  _write(room.service_continue, &"visible", false)
  _write(room.shop_open_button, &"visible", false)
  _write(room.session_hint, &"visible", map)
  _write(room.growth_toggle, &"visible", map and f.learn)
  if is_instance_valid(room.ordinary_potion_controls): _write(room.ordinary_potion_controls, &"visible", false)
  var backing: Control = room.session_canvas.get_node_or_null("TrialLiveHintBacking") as Control
  if is_instance_valid(backing): _write(backing, &"visible", map)
 shade.visible = sheet
 title.visible = sheet
 done.visible = sheet
 route_button.visible = not f.blocked and f.route and not sheet
 var viewport: Vector2 = room.get_viewport().get_visible_rect().size
 shade.size = viewport
 title.position = Vector2(36, 88)
 title.text = "技能配置" if skills else "选择下一处房间"
 done.position = Vector2(viewport.x - 254, viewport.y - 66)
 done.size = Vector2(218, 44)
 done.text = "完成，查看路线" if skills and f.route else "返回房间"
 route_button.position = Vector2(22, 82)
 route_button.size = Vector2(104, 32)
 if skills:
  var panel: Control = room.initial_hud.growth_panel
  _write(panel, &"position", Vector2((viewport.x - 880) * 0.5, 132))
  _write(panel, &"custom_minimum_size", Vector2(880, 510))
  _write(panel, &"size", Vector2(880, 510))
  for key: String in room.initial_hud.q_choices:
   var choice: Dictionary = room.initial_hud.q_choices[key]
   _write(choice.name, &"custom_minimum_size", Vector2(200, 36))
   _write(choice.upgrade, &"custom_minimum_size", Vector2(200, 46))
  _write(room.initial_hud.e1_choice, &"custom_minimum_size", Vector2(200, 46))
 elif map:
  _write(room.route_map, &"position", Vector2(42, 132))
  _write(room.route_map, &"size", Vector2(maxf(430,viewport.x-440), maxf(420,viewport.y-220)))
  _write(room.session_next, &"position", Vector2(viewport.x-350, 146))
  _write(room.session_next, &"size", Vector2(314, 48))
  _write(room.session_hint, &"position", Vector2(viewport.x-350, 218))
  _write(room.session_hint, &"size", Vector2(314,room.session_hint.size.y))
  var backing: Control = room.session_canvas.get_node_or_null("TrialLiveHintBacking") as Control
  if is_instance_valid(backing):
   _write(backing, &"position", Vector2(viewport.x-358,210))
   _write(backing, &"size", Vector2(330,backing.size.y))

func _finish() -> void:
 room.frontdoor_clear_input()
 requested = "map" if page == "skills" and _facts().route else "none"
 present()

func _show_map() -> void:
 if not _facts().route or _facts().blocked: return
 room.frontdoor_clear_input()
 requested = "map"
 present()

func _write(node: Object, property: StringName, value: Variant) -> void:
 for row: Dictionary in writes:
  if row.node.get_ref() == node and row.property == property:
   if node.get(property) != row.after: row.before = node.get(property)
   row.after = value
   if node.get(property) != value: node.set(property, value)
   return
 writes.append({"node":weakref(node),"property":property,"before":node.get(property),"after":value})
 if node.get(property) != value: node.set(property, value)

func _restore() -> void:
 for i: int in range(writes.size()-1,-1,-1):
  var row: Dictionary = writes[i]
  var node: Object = row.node.get_ref()
  if is_instance_valid(node) and node.get(row.property) == row.after and row.before != row.after: node.set(row.property,row.before)
 writes.clear()

func deactivate() -> void:
 _restore()
 initialized = false
 for control: Control in [shade,title,done,route_button]:
  if is_instance_valid(control): control.visible = false

func _exit_tree() -> void:
 deactivate()
 for control: Control in [shade,title,done,route_button]:
  if is_instance_valid(control): control.queue_free()
