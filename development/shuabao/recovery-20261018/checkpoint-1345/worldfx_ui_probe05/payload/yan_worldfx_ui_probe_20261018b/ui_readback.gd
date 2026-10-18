extends RefCounted
## New read-only fixture helper. No presentation call, signal emission, UI write,
## input delivery, source snapshot method, or gameplay operation occurs here.

static func _field(object: Variant, key: String) -> Variant:
 if not is_instance_valid(object): return null
 for property: Dictionary in object.get_property_list():
  if str(property.name)==key: return object.get(key)
 return null

static func _vec(value: Vector2) -> Array:
 return [value.x,value.y]

static func _rect(value: Rect2) -> Array:
 return [value.position.x,value.position.y,value.size.x,value.size.y]

static func _pressed(button: Button) -> Array:
 var result: Array=[]
 for row: Dictionary in button.get_signal_connection_list("pressed"):
  var callback: Callable=row.callable
  var object: Object=callback.get_object()
  result.append({"target_id":object.get_instance_id() if is_instance_valid(object) else 0,"method":str(callback.get_method()),"flags":row.flags,"custom":callback.is_custom()})
 return result

static func _control(node: Variant) -> Dictionary:
 if not is_instance_valid(node) or not node is Control: return {"valid":false}
 var result: Dictionary={"valid":true,"id":node.get_instance_id(),"path":str(node.get_path()),"class":node.get_class(),"rect":_rect(node.get_global_rect()),"minimum_size":_vec(node.get_combined_minimum_size()),"visible":node.visible,"visible_in_tree":node.is_visible_in_tree(),"mouse_filter":node.mouse_filter,"z_index":node.z_index,"process_mode":node.process_mode}
 var ancestor: Node=node.get_parent()
 while is_instance_valid(ancestor):
  if ancestor is CanvasLayer:
   result["canvas_layer"]={"id":ancestor.get_instance_id(),"layer":ancestor.layer,"visible":ancestor.visible}
   break
  ancestor=ancestor.get_parent()
 if node is Button:
  result["text"]=node.text
  result["disabled"]=node.disabled
  result["pressed_connections"]=_pressed(node)
 elif node is Label:
  result["text_length"]=node.text.length()
  result["text_sha256"]=node.text.sha256_text()
  result["text_head"]=node.text.left(2048)
  result["line_count"]=node.get_line_count()
 return result

static func _child(parent: Variant, name: String) -> Variant:
 if not is_instance_valid(parent) or not parent is Node: return null
 return parent.get_node_or_null(NodePath(name))

static func sample(room: Node, entry: Node) -> Dictionary:
 var result: Dictionary={"classification":"READ_ONLY_ACTUAL_POSTDRAW_UI_FIELDS","native_hit_test_proven":false,"layout_target_is_not_actual_rect":true,"art_acceptance":"NOT_REVIEWED"}
 if not is_instance_valid(room) or not is_instance_valid(entry): result["valid"]=false;return result
 result["valid"]=true
 result["host_id"]=room.get_instance_id()
 result["entry_id"]=entry.get_instance_id()
 result["screen"]=_field(entry,"screen")
 result["room_visible"]=room.is_visible_in_tree()
 result["room_process_mode"]=room.process_mode
 result["viewport_rect"]=_rect(room.get_viewport().get_visible_rect())
 var source: Variant=_field(room,"sim")
 if is_instance_valid(source):
  result["source"]={"id":source.get_instance_id(),"room_id":_field(source,"room_id"),"generation":_field(source,"encounter_generation"),"phase":_field(source,"phase"),"hero_time":_field(source,"hero_time"),"paused":_field(source,"paused")}
 result["requests"]={"map":_field(room,"map_visible_requested"),"growth":_field(room,"growth_open_requested"),"diagnostic":_field(room,"diagnostic")}
 var session: Variant=_field(room,"shop_session")
 if is_instance_valid(session):
  result["session"]={"id":session.get_instance_id(),"status":_field(session,"status"),"shop_modal":_field(session,"panel_open"),"initial_modal":_field(session,"initial_modal_open")}
 var controls: Dictionary={}
 for key: String in ["session_header","session_hint","session_next","service_continue","shop_open_button","route_map","session_equipment","growth_toggle"]:
  controls[key]=_control(_field(room,key))
 controls["return_button"]=_control(_field(entry,"return_button"))
 var chooser: Variant=_field(entry,"chooser")
 controls["chooser"]=_control(chooser)
 controls["resume_button"]=_control(_field(chooser,"resume_button"))
 var hud: Variant=_field(room,"hud")
 for key: String in ["footer","buffs","status","diag"]: controls["hud_"+key]=_control(_field(hud,key))
 if is_instance_valid(hud):
  var buttons: Array=[]
  for child: Node in hud.get_children():
   if child is Button: buttons.append(_control(child))
  result["hud_buttons"]=buttons
 var initial: Variant=_field(room,"initial_hud")
 controls["growth_panel"]=_control(_field(initial,"growth_panel"))
 var hex: Variant=_field(initial,"hex_draft")
 controls["hex_draft"]=_control(hex)
 if is_instance_valid(hex):
  result["hex_choosing"]=_field(hex,"choosing")
  var cards: Variant=_field(hex,"cards")
  var choices: Array=[]
  if cards is Array:
   for card: Variant in cards:
    var select: Variant=card.get("select") if card is Dictionary else _field(card,"select")
    choices.append(_control(select))
  result["hex_buttons"]=choices
 var canvas: Variant=_field(room,"session_canvas")
 var diagnostic: Variant=_child(canvas,"TrialF1Diagnostics")
 controls["trial_diagnostics"]=_control(diagnostic)
 if is_instance_valid(diagnostic) and diagnostic.get_child_count()>0:
  var scroll: Node=diagnostic.get_child(0)
  controls["trial_diagnostics_scroll"]=_control(scroll)
  if scroll.get_child_count()>0: controls["trial_diagnostics_text"]=_control(scroll.get_child(0))
 var hint: Variant=_field(room,"session_hint")
 if is_instance_valid(hint): controls["trial_hint_backing"]=_control(_child(hint.get_parent(),"TrialLiveHintBacking"))
 var h02: Variant=_field(room,"h02_label")
 controls["h02_label"]=_control(h02)
 if is_instance_valid(h02): controls["old_h02_parent"]=_control(h02.get_parent())
 result["controls"]=controls
 return result


static func growth_buttons(room: Node) -> Dictionary:
 var hud: Variant=_field(room,"initial_hud")
 if not is_instance_valid(hud):return {}
 var result: Dictionary={}
 var choices: Variant=_field(hud,"q_choices")
 if choices is Dictionary:
  for candidate: String in ["Q1","Q2","Q3"]:
   if choices.has(candidate):result[candidate]=choices[candidate].get("upgrade")
 for key: String in ["e1_choice","e2_choice","e3_choice","p1_choice","p2_choice","p3_choice","r1_choice","r2_choice","undo_button","respec_button"]:
  result[key]=_field(hud,key)
 return result

static func growth_sample(room: Node) -> Dictionary:
 var out: Dictionary={"classification":"ACTUAL_EXPANDED_GROWTH_GEOMETRY","native_device_proven":false,"buttons":{},"all_fully_visible_without_scrolling":false}
 if not is_instance_valid(room):return out
 var viewport: Rect2=room.get_viewport().get_visible_rect()
 var hud: Variant=_field(room,"initial_hud")
 out["panel"]=_control(_field(hud,"growth_panel"))
 out["viewport_rect"]=_rect(viewport)
 var all_visible: bool=true
 for key: String in growth_buttons(room):
  var button: Variant=growth_buttons(room)[key]
  var row: Dictionary=_control(button)
  if not is_instance_valid(button) or not button is Button:
   all_visible=false;out.buttons[key]=row;continue
  var rect: Rect2=button.get_global_rect()
  var effective: Rect2=viewport
  var clips: Array=[]
  var scrolls: Array=[]
  var ancestor: Node=button.get_parent()
  while is_instance_valid(ancestor):
   if ancestor is Control and ancestor.clip_contents:
    effective=effective.intersection(ancestor.get_global_rect())
    clips.append({"id":ancestor.get_instance_id(),"rect":_rect(ancestor.get_global_rect())})
   if ancestor is ScrollContainer:
    var bar: VScrollBar=ancestor.get_v_scroll_bar()
    scrolls.append({"id":ancestor.get_instance_id(),"rect":_rect(ancestor.get_global_rect()),"scroll_vertical":ancestor.scroll_vertical,"vertical_scroll_mode":ancestor.vertical_scroll_mode,"bar_visible":bar.is_visible_in_tree(),"minimum":bar.min_value,"maximum":bar.max_value,"page":bar.page})
   ancestor=ancestor.get_parent()
  row["effective_clip_rect"]=_rect(effective)
  row["clip_ancestors"]=clips
  row["scroll_ancestors"]=scrolls
  row["fully_visible_rect"]=button.is_visible_in_tree() and rect.size.x>0.0 and rect.size.y>0.0 and effective.encloses(rect)
  if not row.fully_visible_rect:all_visible=false
  out.buttons[key]=row
 out["button_count"]=out.buttons.size()
 out["all_fully_visible_without_scrolling"]=all_visible and out.buttons.size()==13
 return out
