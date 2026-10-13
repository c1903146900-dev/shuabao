extends Node3D
const Scroll=preload("res://visual_rework_20261009/views/r2_scroll.gd")
const Forms=preload("res://visual_rework_20261009/views/r_forms.gd")
const Peak=preload("res://visual_rework_20261009/views/r2_painted_peak.gd")
var scope={}
var scroll:Node3D
var domain={}
var peaks={}
var warnings={}
func _ready()->void:
 set_as_top_level(true);transform=Transform3D.IDENTITY
func reset_visuals()->void:
 if is_instance_valid(scroll):scroll.visible=false;scroll.queue_free()
 scroll=null;domain={}
 for node in peaks.values():node.visible=false;node.queue_free()
 peaks.clear()
 for node in warnings.values():node.visible=false;node.queue_free()
 warnings.clear()
func receive_source(_event:Dictionary,_snapshot:Dictionary)->void:pass
func present_source(ink:Dictionary,_projection:Dictionary={})->void:
 var next=ink.get("scope",{})
 if scope!=next:reset_visuals();scope=next.duplicate(true)
 var now=float(ink.get("world_time",NAN))
 if not is_finite(now):reset_visuals();return
 var current:Dictionary=ink.get("peaks_domain",{})
 if not current.is_empty():
  if domain.get("domain_id","")!=current.get("domain_id",""):
   reset_visuals();domain=current.duplicate(true)
   if not current.get("position") is Vector3 or float(current.get("radius",0))<=0:return
   scroll=Scroll.new();scroll.duration=float(current.expires_at)-float(current.born_at);add_child(scroll);scroll.position=current.position;scroll.scale=Vector3.ONE*(float(current.radius)/10.0)
  domain=current.duplicate(true)
 elif not domain.is_empty():
  var ended=false
  for finished in ink.get("r2_finished",[]):
   if finished.get("domain_id","")==domain.get("domain_id","") and finished.get("reason","")=="natural_expiry":ended=true
  if not ended:reset_visuals();return
 if is_instance_valid(scroll):
  var age=now-float(domain.born_at);scroll.advance(age)
  if now>=float(domain.expires_at)+.20:reset_visuals();return
 var live={}
 var live_warnings={}
 for record in ink.get("ground_peaks",[]):
  if record.get("domain_id","")!=domain.get("domain_id",""):continue
  var phase=str(record.get("phase",""))
  if phase=="warning":
   var center=record.get("position",Vector3.INF);var radius=float(record.get("peak_radius",0));var key=str(record.get("peak_id",""))
   if center is Vector3 and center.is_finite() and radius>0:
    live_warnings[key]=true
    if not warnings.has(key):
     var ring=TorusMesh.new();ring.inner_radius=maxf(.01,radius-.06);ring.outer_radius=radius;ring.rings=48;ring.ring_segments=8
     warnings[key]=Forms.mesh(self,ring,center+Vector3.UP*.16,Forms.mat(Color(.40,.66,.56,.55)))
    warnings[key].position=center+Vector3.UP*.16
   continue
  if phase not in ["rise","hit","fade"]:continue
  if not record.get("position") is Vector3 or not Vector3(record.position).is_finite():continue
  var at=float(record.get("rise_at",NAN));var end=float(record.get("disappear_at",NAN));var radius=float(record.get("peak_radius",0))
  if not is_finite(at) or not is_finite(end) or radius<=0 or now<at or now>=end:continue
  var key=str(record.get("peak_id",""));live[key]=true
  if not peaks.has(key):
   var n=Peak.new();add_child(n);peaks[key]=n
  var peak:Node3D=peaks[key];peak.position=record.position;peak.scale=Vector3.ONE*(radius/2.0);peak.advance(now-at)
 for key in peaks.keys():
  if not live.has(key):peaks[key].queue_free();peaks.erase(key)

 for key in warnings.keys():
  if not live_warnings.has(key):warnings[key].visible=false;warnings[key].queue_free();warnings.erase(key)
