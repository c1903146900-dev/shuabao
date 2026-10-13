extends Node3D
## Attached to the genuine ordinary host. Read-only Sim observation only.
const Q1=preload("res://visual_rework_20261009/views/q1_view.gd")
const Q2=preload("res://visual_rework_20261009/views/q2_source_river_view.gd")
const Q3=preload("res://visual_rework_20261009/views/q3_source_landscape_view.gd")
const E2=preload("res://visual_rework_20261009/views/e2_source_boat_view.gd")
const E3=preload("res://visual_rework_20261009/views/e3_source_painted_realms_view.gd")
const R1=preload("res://visual_rework_20261009/views/r1_source_snow_view.gd")
const R2=preload("res://visual_rework_20261009/views/r2_source_scroll_view.gd")
var r1:Node3D
var r2:Node3D
var host:Node3D
var source:Node
var q1:Node3D
var q2:Node3D
var q3:Node3D
var e2:Node3D
var e3:Node3D
var legacy_visibility:Dictionary={}
var last_snapshot:Dictionary={}
var observed_events=0
func _ready()->void:
 process_priority=100
 q1=Q1.new();q2=Q2.new();q3=Q3.new();e2=E2.new();e3=E3.new();r1=R1.new();r2=R2.new()
 for n in [q1,q2,q3,e2,e3,r1,r2]:add_child(n)
func attach_to_host(value:Node3D)->void:host=value
func _event(event:Dictionary)->void:
 if not is_instance_valid(source):return
 var snapshot:Dictionary=source.ink_presenter_snapshot().duplicate(true)
 for n in [q1,q3,e2,e3,r1,r2]:
  if n.has_method("receive_source"):n.receive_source(event.duplicate(true),snapshot.duplicate(true))
 observed_events+=1
func _set_legacy(name:String,value:bool)->void:
 var node=host.get(name)
 if not is_instance_valid(node):return
 if not legacy_visibility.has(name):legacy_visibility[name]={"node":weakref(node),"visible":node.visible}
 node.visible=value
func _restore_legacy()->void:
 for row in legacy_visibility.values():
  var node=row.node.get_ref()
  if is_instance_valid(node):node.visible=row.visible
 legacy_visibility.clear()
func _reset_all()->void:
 for n in [q1,q2,q3,e2,e3,r1,r2]:
  if is_instance_valid(n):n.reset_visuals()
 _restore_legacy();last_snapshot={}
func _exit_tree()->void:
 _restore_legacy()
 if is_instance_valid(source) and source.combat_event.is_connected(_event):source.combat_event.disconnect(_event)
func _process(_delta:float)->void:
 if not is_instance_valid(host):return
 var sim:Node=host.get("sim")
 if not is_instance_valid(sim):return
 if source!=sim:
  if is_instance_valid(source) and source.combat_event.is_connected(_event):source.combat_event.disconnect(_event)
  source=sim;source.combat_event.connect(_event);_reset_all()
 if bool(host.get("finished")) or source.hero.dead or source.phase not in ["combat","preparation"]:
  _reset_all();return
 var ink:Dictionary=source.ink_presenter_snapshot().duplicate(true);last_snapshot=ink.duplicate(true)
 var projection:Dictionary=host.get("e3_selected_projection") if host.get("e3_selected_projection") is Dictionary else {}
 var preview:Dictionary={}
 var router=host.get("input_router")
 if router!=null and not source.paused and not bool(host.get("_mainprep_required")):
  preview=router.e3_preview_for_view(host._current_pointer_ground())
 q1.present_source(ink);q2.present_source(ink);q3.present_source(ink);e2.present_source(ink,projection);e3.present_source(ink,preview,projection);r1.present_source(ink);r2.present_source(ink)
 q2.present_combat_readability(source.enemies,source.hero.position,float(source.hero_radius))
 for name in ["q1_view","mountain_view","e3_frame_view","r1_domain_view","r2_peaks_view"]:_set_legacy(name,false)
 _set_legacy("q2_river_view",q2.fallback_required)
 _set_legacy("e2_boat_view",e2.fallback_required)
