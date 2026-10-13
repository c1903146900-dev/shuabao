extends Control
## Original procedural map UI. The source reference informed legibility only.
## All edges and button permissions come from the bound Session; pixels grant none.
signal node_chosen(row: int, node_id: String)
const LABELS := {"ordinary":"普通","elite":"精英","rest":"休息","training":"训练","boss":"Boss"}
const COLORS := {"ordinary":Color("46524f"),"elite":Color("99563b"),"rest":Color("376d59"),"training":Color("536488"),"boss":Color("7e425b")}
var definition: Dictionary = {}
var buttons: Dictionary = {}
var centers: Dictionary = {}
var available: Dictionary = {}
var selected := ""
var completed: Dictionary = {}
var entered := ""
var _bound_identity := ""

func bind_route(route: Dictionary) -> void:
 var identity: String = JSON.stringify(route).sha256_text()
 if identity == _bound_identity: return
 _bound_identity = identity
 for old: Node in get_children():
  if old is Button: old.disabled = true
  remove_child(old); old.queue_free()
 definition = route.duplicate(true); buttons.clear()
 mouse_filter = Control.MOUSE_FILTER_STOP
 for row: Dictionary in definition.rows:
  for node: Dictionary in row.nodes:
   var button := Button.new()
   var kind: String = str(definition.payloads[node.payload_ref].kind)
   button.text = str(LABELS[kind]); button.custom_minimum_size = Vector2(72,28)
   button.add_theme_font_size_override("font_size",14)
   button.tooltip_text = "第%d行 · %s · %s\n只沿所连路径进入下一行" % [int(row.number),str(node.id),str(LABELS[kind])]
   button.pressed.connect(_choose.bind(int(row.number),str(node.id)))
   add_child(button); buttons[str(node.id)] = button
 _layout_nodes(); queue_redraw()

func present(choices: Array, state: Dictionary, input_blocked: bool) -> void:
 available.clear(); completed.clear()
 for choice: Dictionary in choices: available[str(choice.node_id)] = true
 for receipt: Dictionary in state.get("completed_rows",[]): completed[str(receipt.identity.node_id)] = true
 selected = str(state.get("selected_identity",{}).get("node_id",""))
 entered = selected if str(state.get("status","")) == "entered" else ""
 for row: Dictionary in definition.get("rows",[]):
  for node: Dictionary in row.nodes:
   var id: String = str(node.id)
   var kind: String = str(definition.payloads[node.payload_ref].kind)
   var button: Button = buttons[id]
   button.disabled = input_blocked or not available.has(id)
   var box := StyleBoxFlat.new()
   box.bg_color = Color("eadfc8") if available.has(id) else Color("ded8c9")
   if completed.has(id): box.bg_color = Color("abc0af")
   if selected == id: box.bg_color = Color("d1b784")
   box.border_color = COLORS[kind] if available.has(id) or completed.has(id) or selected == id else Color("a3a299")
   box.set_border_width_all(2 if available.has(id) or selected == id else 1)
   box.set_corner_radius_all(12 if kind != "boss" else 5)
   for style: String in ["normal","disabled","hover","pressed","focus"]: button.add_theme_stylebox_override(style,box)
   button.add_theme_color_override("font_disabled_color",Color("334a42") if completed.has(id) or selected == id else Color("81857d"))
   button.add_theme_color_override("font_color",COLORS[kind])
 _layout_nodes(); queue_redraw()

func _notification(what: int) -> void:
 if what == NOTIFICATION_RESIZED and not definition.is_empty(): _layout_nodes(); queue_redraw()

func _layout_nodes() -> void:
 var gap: float = maxf(30.0,(size.y-52.0)/11.0)
 centers.clear()
 for row: Dictionary in definition.get("rows",[]):
  for node: Dictionary in row.nodes:
   var id: String = str(node.id)
   var x: float = 66.0 + (float(definition.presentation.node_x[id])-160.0)/440.0*(size.x-120.0)
   var at := Vector2(x,26.0+(12-int(row.number))*gap)
   centers[id] = at
   var button: Button = buttons[id]
   button.size = Vector2(72,28); button.position = at-button.size/2.0

func _draw() -> void:
 draw_style_box(_background(),Rect2(Vector2.ZERO,size))
 if definition.is_empty(): return
 var font: Font = ThemeDB.fallback_font
 for row: Dictionary in definition.rows:
  var first: String = str(row.nodes[0].id)
  if centers.has(first): draw_string(font,Vector2(8,centers[first].y+5),"%02d" % int(row.number),HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("7a8075"))
  for node: Dictionary in row.nodes:
   var start: Vector2 = centers[str(node.id)]-Vector2(0,15)
   for target: String in node.next:
    var finish: Vector2 = centers[target]+Vector2(0,15)
    var active: bool = (completed.has(str(node.id)) and (completed.has(target) or selected == target)) or (str(node.id) == selected and available.has(target))
    var color: Color = Color("365d49") if active else Color("919789")
    # Short dotted connections curve gently between neighboring horizontal rows.
    var midpoint: Vector2 = (start+finish)*0.5+Vector2((finish.x-start.x)*0.08,0)
    var previous: Vector2 = start
    for segment in range(1,19):
     var t: float = float(segment)/18.0
     var point: Vector2 = start*(1-t)*(1-t)+midpoint*2*(1-t)*t+finish*t*t
     if segment % 3 != 0: draw_line(previous,point,color,2.8 if active else 1.5,true)
     previous = point

func _background() -> StyleBoxFlat:
 var box := StyleBoxFlat.new(); box.bg_color = Color("e5e0d0f2")
 box.border_color = Color("8d9986"); box.set_border_width_all(1); box.set_corner_radius_all(6)
 return box

func _choose(row: int, node_id: String) -> void:
 node_chosen.emit(row,node_id)
