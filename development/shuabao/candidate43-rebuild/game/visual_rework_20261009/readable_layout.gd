extends RefCounted
## Pure display overlay: clear exactly three frozen static duplicates, never controls.
const HUD_PATH="res://tests/ink_style_specimen_20261004/revision10_hud/hud.gd"
const HUD_SHA="62c2b2518d0dc76aaa14d29aad51664f89802ff3e7d862de59479114305464d8"
const CREATOR_PATH="res://tests/ink_style_specimen_20261004/revision03/hud.gd"
const CREATOR_SHA="e6e17791cb3f28124ed140a58b31bfbe3404d4411ce78ba7284060d433502b93"
const SPECS=[
 {"text":"装备","position":Vector2(946,644),"declared_size":Vector2(46,24),"font":15},
 {"text":"示意框","position":Vector2(1039,648),"declared_size":Vector2(43,18),"font":11},
 {"text":"装备接入中","position":Vector2(946,673),"declared_size":Vector2(135,18),"font":12}
]
static func apply(hud:Control,summary:Label)->Dictionary:
 if not is_instance_valid(hud) or hud.get_script()==null or hud.get_script().resource_path!=HUD_PATH or FileAccess.get_sha256(HUD_PATH)!=HUD_SHA or FileAccess.get_sha256(CREATOR_PATH)!=CREATOR_SHA:
  return {"passed":false,"reason":"exact_original_hud_required","changed":0}
 if not is_instance_valid(summary) or summary.get_parent()==null:
  return {"passed":false,"reason":"actual_summary_required","changed":0}
 var selected:Array=[]
 var observations:Array=[]
 for spec:Dictionary in SPECS:
  var matches:Array=[]
  for child:Node in hud.get_children():
   if child is Label and child!=summary and child.get_script()==null and child.text==spec.text and child.position==spec.position and child.get_theme_font_size("font_size")==spec.font and child.mouse_filter==Control.MOUSE_FILTER_IGNORE and child.get_child_count()==0:
    var connected:bool=false
    for signal_info:Dictionary in child.get_signal_list():
     if not child.get_signal_connection_list(signal_info.name).is_empty():connected=true
    if not connected:matches.append(child)
  observations.append({"text":spec.text,"count":matches.size()})
  if matches.size()!=1:return {"passed":false,"reason":"static_label_signature_not_unique","changed":0,"observations":observations}
  selected.append(matches[0])
 # All identities and complete signatures are verified before the first mutation.
 var changes:Array=[]
 for label:Label in selected:
  changes.append({"instance_id":label.get_instance_id(),"path":str(label.get_path()),"before":label.text,"position":label.position,"size":label.size,"minimum":label.get_minimum_size(),"combined_minimum":label.get_combined_minimum_size(),"declared_size":SPECS[changes.size()].declared_size})
 for label:Label in selected:label.text=""
 var geometry_unchanged:bool=true
 for index in range(selected.size()):
  changes[index]["after_minimum"]=selected[index].get_minimum_size()
  changes[index]["after_combined_minimum"]=selected[index].get_combined_minimum_size()
  if selected[index].position!=changes[index].position or selected[index].size!=changes[index].size:geometry_unchanged=false
 return {"passed":geometry_unchanged,"reason":"" if geometry_unchanged else "unexpected_geometry_change","geometry_unchanged":geometry_unchanged,"changed":3,"labels":changes,"summary_id":summary.get_instance_id(),"summary_text":summary.text,"buttons_changed":0,"new_backdrop":false}
