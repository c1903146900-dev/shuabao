extends RefCounted
const BONES: Array[String]=["pelvis","thigh_L","shin_L","foot_L","thigh_R","shin_R","foot_R"]
var neutral: Dictionary={}
var stable_idle: int=0
var previous_yaw: float=NAN
var previous_scope: String=""
var previous_draw: int=-1
var neutral_scope: String=""
var previous_bones: Dictionary={}
var idle_started: float=-1.0
func v(p: Vector3) -> Array:return [p.x,p.y,p.z]
func basis(b: Basis) -> Array:return [v(b.x),v(b.y),v(b.z)]
func transform(t: Transform3D) -> Dictionary:return {"origin":v(t.origin),"basis_columns":basis(t.basis)}
func observe(entry: Node,stage: String) -> Dictionary:
 if not is_instance_valid(entry):return {"accepted":false,"reason":"rig_entry_missing"}
 var host_value: Variant=entry.get("active_room")
 var display_value: Variant=entry.get("_front_hero")
 if not is_instance_valid(host_value) or not is_instance_valid(display_value):return {"accepted":false,"reason":"rig_owner_missing"}
 var actor_value: Variant=host_value.get("hero_view")
 var camera_value: Variant=display_value.get("camera")
 if not is_instance_valid(actor_value) or not is_instance_valid(camera_value):return {"accepted":false,"reason":"rig_actor_camera_missing"}
 var actor: Node3D=actor_value as Node3D
 var camera: Camera3D=camera_value as Camera3D
 if actor==null or camera==null:return {"accepted":false,"reason":"rig_actor_camera_types"}
 var skeleton_value: Variant=actor.get("skeleton")
 if not is_instance_valid(skeleton_value):return {"accepted":false,"reason":"rig_skeleton_missing"}
 var skeleton: Skeleton3D=skeleton_value as Skeleton3D
 if actor==null or camera==null or skeleton==null:return {"accepted":false,"reason":"rig_types"}
 var report: Dictionary=actor.get("sample_report")
 var receipt: Dictionary=display_value.get("receipt")
 var sim: Variant=host_value.get("sim")
 if not is_instance_valid(sim):return {"accepted":false,"reason":"rig_sim_missing"}
 var hero: Variant=sim.hero
 if not is_instance_valid(hero):return {"accepted":false,"reason":"rig_hero_missing"}
 if display_value.get_parent()!=host_value or display_value.get("actor")!=actor or display_value.get("source")!=sim or not actor.is_ancestor_of(skeleton):return {"accepted":false,"reason":"rig_owner_chain"}
 var renderer_value: Variant=display_value.get("renderer")
 if not is_instance_valid(renderer_value):return {"accepted":false,"reason":"rig_renderer_missing"}
 var renderer_receipt: Dictionary=renderer_value.get("receipt")
 var controlled: bool=bool(hero.dead) or float(hero.stun_left)>0.0 or float(hero.dash_left)>0.0 or hero.knockback.length()>0.00001
 var row: Dictionary={"accepted":true,"stage":stage,"source_time":sim.hero_time,"draw_frame":Engine.get_process_frames(),"actor_transform":transform(actor.global_transform),"skeleton_transform":transform(skeleton.global_transform),"camera_transform":transform(camera.global_transform),"bones":{},"base":report.get("base"),"upper":report.get("upper"),"gait":report.get("gait_elapsed_absolute"),"walk_playback_ratio":report.get("walk_playback_ratio"),"actor_source_time":report.get("source_time"),"controller_source_time":receipt.get("source_time"),"view":receipt.get("view"),"moving":receipt.get("moving"),"phase":receipt.get("phase"),"controlled":controlled,"dead":hero.dead,"stun_left":hero.stun_left,"dash_left":hero.dash_left,"knockback":v(hero.knockback),"actor_yaw":actor.rotation.y,"hp":hero.hp,"move_intent":v(hero.move_intent)}
 for name: String in BONES:
  var index: int=skeleton.find_bone(name)
  if index<0:return {"accepted":false,"reason":"rig_bone_missing:"+name}
  var world: Transform3D=skeleton.global_transform*skeleton.get_bone_global_pose(index)
  if not world.is_finite():return {"accepted":false,"reason":"nonfinite_bone:"+name}
  var pixel: Vector2=camera.unproject_position(world.origin)
  row.bones[name]={"index":index,"world":transform(world),"actor_relative":transform(actor.global_transform.affine_inverse()*world),"camera_relative":transform(camera.global_transform.affine_inverse()*world),"screen":[pixel.x,pixel.y],"behind_camera":camera.is_position_behind(world.origin)}
 var scope: String=str(host_value.get_instance_id())+"/"+str(sim.get_instance_id())+"/"+str(hero.get_instance_id())+"/"+str(sim.room_id)+"/"+str(sim.encounter_generation)+"/"+str(actor.get_instance_id())+"/"+str(skeleton.get_instance_id())+"/"+str(camera.get_instance_id())
 if not neutral.is_empty() and scope!=neutral_scope:return {"accepted":false,"reason":"neutral_owner_changed"}
 var adjacent: bool=scope==previous_scope and Engine.get_process_frames()==previous_draw+1
 var stable_yaw: bool=adjacent and is_finite(previous_yaw) and absf(wrapf(actor.rotation.y-previous_yaw,-PI,PI))<0.0001
 var eligible: bool=stage=="calibrate_idle" and str(receipt.get("view",""))=="front" and str(report.get("base",""))=="idle" and str(report.get("upper",""))=="" and not controlled and stable_yaw and bool(receipt.get("accepted",false)) and not bool(receipt.get("moving",true)) and bool(renderer_receipt.get("accepted",false)) and str(renderer_receipt.get("view",""))=="front" and float(renderer_receipt.get("source_time",-INF))==float(sim.hero_time) and display_value.is_visible_in_tree() and renderer_value.is_visible_in_tree() and float(report.get("source_time",-INF))==float(sim.hero_time) and float(receipt.get("source_time",-INF))==float(sim.hero_time)
 previous_yaw=actor.rotation.y
 previous_scope=scope
 previous_draw=Engine.get_process_frames()
 row["adjacent_same_owner"]=adjacent
 var maximum_origin_delta: float=INF
 var maximum_basis_delta: float=INF
 if adjacent and not previous_bones.is_empty():
  maximum_origin_delta=0.0;maximum_basis_delta=0.0
  for name: String in BONES:
   var current: Dictionary=row.bones[name].actor_relative
   var prior: Dictionary=previous_bones[name].actor_relative
   var co: Array=current.origin;var po: Array=prior.origin
   maximum_origin_delta=maxf(maximum_origin_delta,Vector3(co[0]-po[0],co[1]-po[1],co[2]-po[2]).length())
   for col in range(3):
    var cb: Array=current.basis_columns[col];var pb: Array=prior.basis_columns[col]
    maximum_basis_delta=maxf(maximum_basis_delta,Vector3(cb[0]-pb[0],cb[1]-pb[1],cb[2]-pb[2]).length())
 if eligible:
  if idle_started<0.0:idle_started=float(sim.hero_time)
 else:idle_started=-1.0
 var idle_age: float=float(sim.hero_time)-idle_started if idle_started>=0.0 else 0.0
 var converged: bool=eligible and idle_age>=0.3 and maximum_origin_delta<=0.001 and maximum_basis_delta<=0.005
 stable_idle=stable_idle+1 if converged else 0
 previous_bones=row.bones.duplicate(true)
 row["maximum_bone_origin_delta_m"]=maximum_origin_delta if is_finite(maximum_origin_delta) else null
 row["maximum_bone_basis_column_delta"]=maximum_basis_delta if is_finite(maximum_basis_delta) else null
 row["idle_source_age"]=idle_age
 row["pose_converged"]=converged
 var forward: Vector3=actor.global_basis.z;forward.y=0.0
 var movement: Vector3=hero.move_intent;movement.y=0.0
 row["actual_forward_dot_movement"]=forward.normalized().dot(movement.normalized()) if forward.length()>0.00001 and movement.length()>0.00001 else null
 row["neutral_eligible"]=eligible
 row["stable_idle_frames"]=stable_idle
 if neutral.is_empty() and stable_idle>=3:
  var left_x: float=float(row.bones.thigh_L.screen[0]);var right_x: float=float(row.bones.thigh_R.screen[0])
  if absf(left_x-right_x)<0.01:return {"accepted":false,"reason":"neutral_screen_sides_ambiguous"}
  neutral_scope=scope
  neutral={"sample":row.duplicate(true),"screen_left_bone":"thigh_L" if left_x<right_x else "thigh_R","screen_right_bone":"thigh_R" if left_x<right_x else "thigh_L","mapping_locked_once":true,"foot_screen_left_bone":"foot_L" if float(row.bones.foot_L.screen[0])<float(row.bones.foot_R.screen[0]) else "foot_R","foot_thigh_side_agree":(float(row.bones.foot_L.screen[0])<float(row.bones.foot_R.screen[0]))==(left_x<right_x)}
 row["neutral_locked"]=not neutral.is_empty()
 return row
