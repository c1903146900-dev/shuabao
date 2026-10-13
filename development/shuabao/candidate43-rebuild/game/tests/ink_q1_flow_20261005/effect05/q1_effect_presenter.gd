extends "res://tests/ink_q1_effect_20261004/revision07/q1_effect_presenter.gd"
## Traveling body only. Same preview, source receipts, clock/scope and contact.
## Two layers total: one solid asymmetric body + a subordinate wet edge wash.
const BELLY_SHADER=preload("res://tests/ink_q1_flow_20261005/effect05/ink_belly.gdshader")
var _belly_material: ShaderMaterial
func _ready() -> void:
 super._ready()
 _belly_material=ShaderMaterial.new()
 _belly_material.shader=BELLY_SHADER
 _belly_material.set_shader_parameter("pigment",_stroke_texture)

func _station(s: float,front: float,width: float,total: float,residue: bool,lane: int) -> Dictionary:
 var behind: float=maxf(0.0,front-s)
 var age: float=behind/24.0
 var u: float=clampf(s/maxf(total,EPS),0.0,1.0)
 # Fixed written pressure: one loaded belly and one lifted end. No periodic
 # sinusoidal width alternation that draws several equal travelling stripes.
 var load: float=lerpf(.24,.97,smoothstep(0.0,.23,u))
 var lift: float=lerpf(1.0,.40,smoothstep(.38,1.0,u))
 var pressure: float=load*lift
 var front_load: float=lerpf(.88,1.0,smoothstep(0.0,.24,behind))
 var side_release: float=smoothstep(.65,3.75,behind)
 var tail_taper: float=lerpf(1.0,.095,side_release)
 var center: float=width*(-.16+.15*smoothstep(0.0,.65,u)-.055*smoothstep(.64,1.0,u))
 center-=width*.105*side_release
 var radius: float=width*.40*pressure*front_load*tail_taper
 var crest: float=exp(-pow((behind-.32)/.65,2.0))
 var a: float=0.0
 var b: float=0.0
 var value: float=0.0
 var alpha: float=0.0
 var height: float=.02
 if lane==0:
  # One filled shape includes both hard ink bone and wet belly. Its asymmetry
  # lives in the silhouette; fly-white is one shader opening, not a gap lane.
  a=center-radius*.74+width*(.011*sin(s*7.7)+.006*sin(s*13.1+1.1))
  b=center+radius*1.10+width*.017*sin(s*4.3+.5)
  value=.065+.16*smoothstep(.7,3.5,behind)
  alpha=.94*(1.0-smoothstep(1.35,3.85,behind))
  height=.028+.039*crest
 else:
  a=center-radius*.84-width*.018
  b=center+radius*1.18+width*.026
  value=.79
  alpha=.16*(1.0-smoothstep(.045,.20,age))
  height=.019
 a=clampf(a,-width*.5,width*.5)
 b=clampf(b,-width*.5,width*.5)
 if residue:
  alpha*=.24
  height=minf(height,.028)
  value=maxf(value,.72)
 return {"s":s,"a":a,"b":b,"height":height,"value":value,"alpha":alpha}

func _render_wave(mesh: ArrayMesh,path: Array[Vector3],front: float,width: float,wave_id: String,opacity: float=1.0,residue: bool=false,source_age: float=0.0) -> void:
 mesh.clear_surfaces()
 if _belly_material==null:
  _belly_material=ShaderMaterial.new();_belly_material.shader=BELLY_SHADER
  _belly_material.set_shader_parameter("pigment",_stroke_texture)
 var total: float=_path_length(path)
 var limit: float=minf(front,total)
 var lower: float=maxf(0.0,front-4.8)
 var arc: float=0.0
 var count: int=0
 var max_lateral: float=0.0
 var ids: Array[String]=[]
 var vertices:=PackedVector3Array()
 var colors:=PackedColorArray()
 var uvs:=PackedVector2Array()
 for segment_index in range(path.size()-1):
  var delta: Vector3=path[segment_index+1]-path[segment_index];delta.y=0.0
  var length: float=delta.length()
  if length<EPS:continue
  var lo: float=maxf(arc,lower)
  var hi: float=minf(arc+length,limit)
  if hi>lo:
   ids.append(wave_id+":segment:"+str(segment_index))
   var tangent: Vector3=delta/length
   var lateral:=Vector3(tangent.z,0,-tangent.x)
   var intervals: int=maxi(1,ceili((hi-lo)/.11))
   for lane: int in [1,0]:
    if residue and lane==0:continue
    for i in range(intervals):
     var a: Dictionary=_station(lerpf(lo,hi,float(i)/intervals),front,width,total,residue,lane)
     var b: Dictionary=_station(lerpf(lo,hi,float(i+1)/intervals),front,width,total,residue,lane)
     if float(a.alpha)<.001 and float(b.alpha)<.001:continue
     # One off-centre contact point reaches the true front; the rest of the
     # edge sits strictly behind it. Extra cross sections shape one mass,
     # not new layers. Source corners remain separate, never spline-bridged.
     var across_samples: Array[float]=[0.0,.12,.27,.48,.70,.88,1.0]
     for column in range(across_samples.size()-1):
      var left_cross: float=across_samples[column]
      var right_cross: float=across_samples[column+1]
      for corner: Array in [[float(a.s),left_cross],[float(a.s),right_cross],[float(b.s),right_cross],[float(a.s),left_cross],[float(b.s),right_cross],[float(b.s),left_cross]]:
       var source_s: float=float(corner[0])
       var across: float=float(corner[1])
       var tip_setback: float=.57*pow((across-.27)/.73,2.0)+.065*smoothstep(.60,1.0,across)
       var head_weight: float=1.0-smoothstep(0.0,1.15,maxf(0.0,front-source_s))
       var visible_s: float=maxf(arc,source_s-tip_setback*head_weight)
       var row: Dictionary=_station(visible_s,front,width,total,residue,lane)
       var x: float=lerpf(float(row.a),float(row.b),across)
       var world: Vector3=path[segment_index]+tangent*(visible_s-arc)+lateral*x+Vector3.UP*float(row.height)
       vertices.append(world)
       colors.append(Color(float(row.value),1.0 if lane==0 else 0.0,across,float(row.alpha)*opacity))
       uvs.append(Vector2(visible_s/maxf(total,EPS),.5+x/width))
       max_lateral=maxf(max_lateral,absf(x))
      count+=2
  arc+=length
 _add_surface(mesh,vertices,colors,_belly_material,uvs)
 _stats.triangles+=count
 _stats["visual_revision"]="effect05_native_alpha_pressure_mapping"
 _stats.wave_geometry.append({"wave_id":wave_id,"triangles":count,"min_arc":lower,"max_arc":limit,"front_arc":front,"max_lateral":max_lateral,"source_half_width":width*.5,"exact_segment_ids":ids,"height_cap_m":.067,"residue_only":residue,"fixed_origin":path[0],"source_age":source_age,"stationary_pigment_coordinates":true,"shared_full_width_uv":true,"solid_body_layers":0 if residue else 1,"wet_underwash_layers":1,"max_layers":2,"fly_white_source":"original_rgba_alpha","procedural_slits":0,"front_profile":"off_center_tip_plus_inward_setback_only","maximum_front_setback_m":.635,"tail_profile":"tapered_side_release","original_pigment":STROKE_PATH})
