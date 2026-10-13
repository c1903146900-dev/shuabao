extends Node3D
## Presentation only. Does not modify simulation state.
const Stage = preload("res://scripts/integration/xuanlei_environment.gd")
var visual: Node3D
var player: AnimationPlayer
var health: Label3D
var hp_back: MeshInstance3D
var hp_fill: MeshInstance3D
const HEALTH_BAR_WIDTH := 1.1
var displayed_health_fraction := -1.0
var health_reveal := 0.0
var detail_labels := false
var hero_marker: MeshInstance3D
var warning: MeshInstance3D
var warning_edge: MeshInstance3D
var warning_back: MeshInstance3D
var attack_alert: Label3D
var kind := "hero"
var last_position := Vector3.ZERO
var anim := "idle"
var anim_time := 0.0
var event_left := 0.0
var dead_seen := false
var animation_contract := {}
var contact_after := 0.0
var recovery := 0.0
var marker_time := 0.0
var segment_start := 0.0
var segment_elapsed := 0.0
var segment_duration := 0.0
var impact_seen := false
var timing_active := false
var animation_time_domain := "world"
var sampled_time := 0.0
var contact_evidence: Array = []
var meshes: Array[MeshInstance3D] = []
var flash := 0.0
var flash_active := false
var last_health_text := ""
var warning_key := ""
var run_reference_speed := 2.5
var corpse_time := 0.0
var flash_mat: StandardMaterial3D
var played_clip := ""
# Role adapters may defer pose writes only when they immediately replace them.
var defer_pose_sample := false
var locomotion_time := 0.0
var moving_latch := 0.0
var skeleton: Skeleton3D
var blend_pose: Array[Transform3D] = []
var blend_left := 0.0
var blend_duration := 0.06
var locomotion_blend := 0.0
# Imported rigid foot bounds are cached once; only 16 corners are checked per pose.
var hero_foot_bounds: Dictionary = {}
var hero_ground_lift := 0.0
var hero_rigid_foot_vertices := 0
var hero_mixed_foot_vertices := 0
var recoil := 0.0
var recoil_direction := Vector3.ZERO
var heavy_recoil := false
var base_health_height := 0.0
var applied_model_scale := 1.0
var recoil_duration := 0.14
const COLORS = {"hero":"b89a68","minion":"ac624b","pouncer":"c48c56","ranged":"6886b9","armored":"77888a","elite":"b39b53","boss":"913e47"}
func setup(actor_kind: String, packed: PackedScene = null) -> void:
	kind = actor_kind
	if kind=="hero" and FileAccess.file_exists("res://assets/xuanlei/animation_contract.json"):
		var full_contract: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/xuanlei/animation_contract.json"))
		animation_contract=full_contract.get("clips",{})
		run_reference_speed=float(full_contract.get("run_reference_speed_mps",2.5))
	if kind!="hero" and FileAccess.file_exists("res://assets/enemies/siege_brood/animation_contract.json"):
		var enemy_contract: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/enemies/siege_brood/animation_contract.json"))
		animation_contract=enemy_contract.get("enemies",{}).get(kind,{}).get("clips",{})
	visual = Node3D.new()
	add_child(visual)
	if packed:
		visual.add_child(packed.instantiate())
	else:
		var proxy := MeshInstance3D.new()
		var shape := CapsuleMesh.new()
		shape.radius = 0.55 if kind=="hero" else 0.4
		shape.height = 2.8 if kind=="hero" else 1.6
		proxy.mesh = shape
		proxy.position.y = shape.height/2
		proxy.material_override = Stage.material(Color(COLORS.get(kind,"ffffff")))
		visual.add_child(proxy)
	_scan(visual)
	if kind=="hero" and is_instance_valid(skeleton): _cache_hero_foot_bounds(visual)
	if player: player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	health = Label3D.new()
	health.font_size = 24
	health.pixel_size = 0.012
	health.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	health.no_depth_test = true
	health.position.y = 3.3 if kind=="hero" else 2.5 if kind=="boss" else 1.9
	health.outline_size = 6
	add_child(health)
	base_health_height=health.position.y
	for front in [false,true]:
		var bar:=MeshInstance3D.new()
		var quad:=QuadMesh.new()
		quad.size=Vector2(HEALTH_BAR_WIDTH,0.1 if front else 0.15)
		bar.mesh=quad
		bar.position=Vector3(0,health.position.y-0.2,0)
		var mat:=Stage.material(Color("c69d61") if front else Color("152127"))
		mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED
		# Default billboards discard node scale, which made damaged bars look full.
		mat.billboard_keep_scale=true
		mat.no_depth_test=true
		mat.render_priority=2 if front else 1
		bar.material_override=mat
		bar.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(bar)
		if front: hp_fill=bar
		else: hp_back=bar
	if kind=="hero":
		hero_marker=MeshInstance3D.new()
		var ring:=TorusMesh.new()
		ring.inner_radius=0.68;ring.outer_radius=0.75;ring.rings=32;ring.ring_segments=4
		hero_marker.mesh=ring
		hero_marker.position.y=0.07
		var mat:=Stage.material(Color("69e7d8"),0.8,0,0.25)
		mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		hero_marker.material_override=mat
		hero_marker.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(hero_marker)
	warning = MeshInstance3D.new()
	add_child(warning)
	warning.visible = false
	warning_back=MeshInstance3D.new();add_child(warning_back)
	warning_edge=MeshInstance3D.new();add_child(warning_edge)
	for pair in [[warning_back,Color("46150e")],[warning_edge,Color("ff5426")]]:
		var mat:=Stage.material(pair[1],0.8,0,0.8 if pair[0]==warning_edge else 0.0)
		mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode=BaseMaterial3D.CULL_DISABLED
		pair[0].material_override=mat
		pair[0].visible=false
	attack_alert=Label3D.new()
	attack_alert.text="!"
	attack_alert.font_size=38
	attack_alert.pixel_size=0.020
	attack_alert.modulate=Color("ff653a")
	attack_alert.outline_modulate=Color("31120c")
	attack_alert.outline_size=9
	attack_alert.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	attack_alert.no_depth_test=true
	attack_alert.position.y=health.position.y+0.45
	attack_alert.visible=false
	add_child(attack_alert)
	flash_mat = Stage.material(Color("ff705d") if kind=="hero" else Color("fff5d6"),0.5,0,1.6)
	flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_mat.albedo_color.a = 0.78
	flash_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
func _scan(n: Node) -> void:
	if n is AnimationPlayer: player = n
	if n is Skeleton3D: skeleton=n
	if n is MeshInstance3D: meshes.append(n)
	for child in n.get_children(): _scan(child)
func hit_reaction(direction: Vector3, hero_hit: bool = false, heavy: bool = false) -> void:
	heavy_recoil=heavy and not hero_hit
	recoil_duration=0.24 if heavy_recoil else 0.14
	flash=0.14 if hero_hit else 0.065 if heavy_recoil else 0.11
	flash_mat.albedo_color.a=0.50 if heavy_recoil else 0.78
	health_reveal=2.5
	recoil=recoil_duration
	recoil_direction=direction.normalized() if direction.length_squared()>0.01 else -global_basis.z
	if hero_hit and event_left<=0: event("hit",0.18)

func event(clip: String, duration: float) -> void:
	if clip.is_empty(): return
	anim=clip
	anim_time=0
	event_left=duration
	timing_active=false
func combat_event(e: Dictionary) -> void:
	var meta: Dictionary=e.get("animation",{})
	if meta.is_empty(): return
	animation_time_domain=str(meta.get("time_domain","world"))
	var clip: String=meta.get("clip","")
	if clip.is_empty(): return
	var definition: Dictionary=animation_contract.get(clip,{})
	var authored_length: float=float(definition.get("duration_s",1.0))
	var events: Dictionary=definition.get("events",{})
	var marker: String={"q2":"chain_release","e2":"release","e3":"field_spawn","r1_start":"fortress_active","r2_charge":"ram_contact"}.get(clip,"contact")
	var at: float=float(events.get(marker,{}).get("time_s",0.0))
	if bool(meta.get("impact",false)):
		if anim!=clip:
			anim=clip
			marker_time=at
		impact_seen=true
		timing_active=true
		segment_start=at
		segment_elapsed=0
		segment_duration=maxf(0.001,float(meta.get("recovery",authored_length-at)))
		recovery=segment_duration
		event_left=recovery
		anim_time=at
		sampled_time=at
		if contact_evidence.size()<96: contact_evidence.append({"sequence":e.get("sequence",0),"clip":clip,"marker":marker,"sample":at,"world_time":e.get("world_time",0),"contract_loaded":not definition.is_empty()})
		return
	var continuing: bool=bool(meta.get("resume",e.get("resume",false))) or bool(e.get("presentation_completed",false))
	segment_start=sampled_time if continuing and anim==clip else 0.0
	anim=clip
	marker_time=at
	contact_after=maxf(0.0,float(meta.get("contact_after",0.0)))
	recovery=maxf(0.001,float(meta.get("recovery",authored_length-at)))
	segment_duration=maxf(0.001,contact_after)
	segment_elapsed=0
	impact_seen=contact_after<=0
	timing_active=true
	event_left=contact_after+recovery
	if impact_seen:
		segment_start=at
		segment_duration=recovery
	anim_time=segment_start

func sync(s: Dictionary, dt: float, frozen := false, real_dt := -1.0) -> void:
	var animation_dt: float=real_dt if animation_time_domain=="real" and real_dt>=0 else dt
	var distance := position.distance_to(s.position)
	if distance>0.001:
		moving_latch=0.065
		if kind=="hero" and not frozen:locomotion_time+=distance/maxf(0.1,run_reference_speed)
	elif not frozen: moving_latch=maxf(0,moving_latch-dt)
	if not frozen:
		recoil=maxf(0,recoil-dt)
		var kick: float=sin(PI*recoil/recoil_duration) if recoil>0 else 0.0
		visual.position=global_basis.inverse()*recoil_direction*((0.25 if heavy_recoil else 0.10)*kick)
		visual.rotation.x=-0.12*kick if heavy_recoil else 0.0
		if heavy_recoil:
			visual.position.y=0.045*kick
	last_position=position
	position=s.position
	var facing: Vector3 = s.get("facing",s.get("aim",Vector3.FORWARD))
	if kind=="hero":
		var cast: Dictionary=s.get("cast_state",{})
		if cast.has("e2"):facing=cast.e2.direction
		elif cast.has("r2_charge"):facing=cast.r2_charge.direction
		elif cast.has("chain_flight"):facing=(cast.chain_flight.destination-s.position).normalized()
		elif float(s.get("dash_left",0))>0:facing=s.get("dash_direction",facing)
	if facing.length_squared()>0.01: rotation.y=atan2(-facing.x,-facing.z)
	var scale_value:float=maxf(.08,float(s.get("model_scale",1.0) if kind=="hero" else s.get("common_model_scale",1.0)))
	if not is_equal_approx(applied_model_scale,scale_value):
		applied_model_scale=scale_value
		visual.scale=Vector3.ONE*scale_value
		health.position.y=base_health_height*scale_value
		hp_fill.position.y=health.position.y-.2;hp_back.position.y=health.position.y-.2
		attack_alert.position.y=health.position.y+.45
	health.visible=detail_labels and kind!="hero" and not s.dead
	if flash>0: health_reveal=2.0
	else: health_reveal=maxf(0,health_reveal-dt)
	var show_bar: bool=kind!="hero" and not s.dead and (health_reveal>0 or kind in ["elite","boss"])
	hp_back.visible=show_bar
	var health_fraction := clampf(float(s.hp)/maxf(0.001,float(s.max_hp)),0,1)
	hp_fill.visible=show_bar and health_fraction>0
	if not is_equal_approx(displayed_health_fraction,health_fraction):
		displayed_health_fraction=health_fraction
		# Resize billboard-local geometry, so the left edge stays fixed even while
		# its actor turns. A world-space position offset would orbit with facing.
		var fill_quad: QuadMesh=hp_fill.mesh
		fill_quad.size.x=HEALTH_BAR_WIDTH*health_fraction
		fill_quad.center_offset.x=-HEALTH_BAR_WIDTH*(1.0-health_fraction)*0.5
	var health_text: String=("玄垒  " if kind=="hero" else "")+str(ceili(s.hp))+" / "+str(ceili(s.max_hp))
	if kind=="hero" and s.get("shield",0)>0: health_text+="  盾"+str(ceili(s.shield))
	if last_health_text!=health_text:
		health.text=health_text
		last_health_text=health_text
	flash=maxf(0,flash-dt)
	if flash_active!=(flash>0):
		flash_active=flash>0
		for m in meshes: m.material_overlay=flash_mat if flash_active else null
	if s.dead and not dead_seen: event("death",2.0)
	dead_seen=s.dead
	corpse_time=corpse_time+dt if s.dead else 0.0
	visible=corpse_time<3.0
	if not visible: return
	if not frozen or s.dead:
		# Walking legs stay live, but the upper body finishes its authored follow-through.
		var moving_recovery_ready:bool=segment_elapsed>=0.14
		if anim in ["attack_1","attack_2","attack_3"]:
			var follow_end:float=float(animation_contract.get(anim,{}).get("phases",{}).get("follow_through_end_s",marker_time+0.08))
			moving_recovery_ready=anim_time>=follow_end
		if kind=="hero" and distance>0.001 and timing_active and impact_seen and moving_recovery_ready and anim in ["attack_1","attack_2","attack_3","q1","q2","q3","e1_release","e3"]:
			event_left=0
		if event_left>0:
			event_left=maxf(0,event_left-animation_dt)
			if timing_active and not impact_seen: event_left=maxf(0.001,event_left)
			if timing_active:
				segment_elapsed+=animation_dt
				if not impact_seen:
					# Hold the authored contact pose until the authoritative hit event arrives.
					anim_time=lerpf(segment_start,marker_time,minf(1.0,segment_elapsed/segment_duration))
				else:
					var end_time: float=float(animation_contract.get(anim,{}).get("duration_s",marker_time+recovery))
					anim_time=lerpf(segment_start,end_time,minf(1.0,segment_elapsed/segment_duration))
			else: anim_time+=dt
		elif not s.dead:
			var next := "run" if moving_latch>0 else "idle"
			if kind!="hero" and s.get("state","")=="warning": next="windup"
			if kind=="hero":
				if s.get("cast_state",{}).has("e1"): next="e1_guard"
				elif s.get("cast_state",{}).has("r1"): next="r1_loop"
				elif s.get("cast_state",{}).has("r2_charge"): next="r2_charge"
			if next!=anim: anim_time=locomotion_time if next=="run" else 0.0
			timing_active=false
			anim=next
			if kind=="hero" and next=="run":
				anim_time=locomotion_time
			else: anim_time+=dt
	if kind!="hero" and not s.dead:
		var state: String=s.get("state","")
		var attack: Dictionary=animation_contract.get("attack",{})
		var contact: float=float(attack.get("events",{}).get("contact",0.4))
		var length: float=float(attack.get("duration_s",1.2))
		if state=="warning":
			anim="leap" if kind=="pouncer" else "attack"
			anim_time=(float(animation_contract.get("leap",{}).get("events",{}).get("takeoff",0.8)) if kind=="pouncer" else contact)*float(s.get("warning_progress",0))
		elif state=="recover":
			anim="attack"
			var total: float=1.5 if kind in ["elite","boss"] else 1.4 if kind=="ranged" else 1.2 if kind=="pouncer" else 1.1
			if kind=="pouncer":
				anim="leap"
				anim_time=lerpf(float(animation_contract.get("leap",{}).get("events",{}).get("contact",1.25)),float(animation_contract.get("leap",{}).get("duration_s",2.45)),clampf(1.0-float(s.timer)/total,0,1))
			else: anim_time=lerpf(contact,length,clampf(1.0-float(s.timer)/total,0,1))
		elif state=="pounce":
			anim="leap"
			anim_time=lerpf(float(animation_contract.get("leap",{}).get("events",{}).get("takeoff",0.8)),float(animation_contract.get("leap",{}).get("events",{}).get("contact",1.25)),clampf(1.0-float(s.timer)/0.45,0,1))
	if player:
		var resolved := anim
		if not player.has_animation(resolved):
			resolved={"r1_loop":"r1","run":"walk","attack_1":"attack","attack_2":"attack","attack_3":"attack","windup":"idle"}.get(resolved,"idle")
		if player.has_animation(resolved):
			var length: float=player.get_animation(resolved).length
			if played_clip!=resolved:
				blend_pose.clear()
				if is_instance_valid(skeleton):
					for bone in range(skeleton.get_bone_count()): blend_pose.append(skeleton.get_bone_pose(bone))
				blend_duration=0.020 if resolved=="dash_attack" else 0.035 if resolved.begins_with("attack") or resolved=="dash" else 0.065
				blend_left=blend_duration
				player.play(resolved)
				played_clip=resolved
			sampled_time=fposmod(anim_time,length) if anim in ["idle","run","walk","e1_guard","r1_loop"] else minf(anim_time,length)
			# Manual sampling must not inherit unkeyed channels from last frame's layers.
			# Capture clip-change blend_pose above before resetting to the authored basis.
			if is_instance_valid(skeleton) and not defer_pose_sample: skeleton.reset_bone_poses()
			if not defer_pose_sample: player.seek(sampled_time,true)
			if kind=="hero":
				# Split-body locomotion stays live throughout windup, contact and recovery.
				# Real displacement, including hitstop movement, drives the gait phase.
				var locomoting: bool=distance>0.0001 and float(s.get("dash_left",0))<=0 and anim not in ["idle","run","walk","death","dash"]
				locomotion_blend=move_toward(locomotion_blend,1.0 if locomoting else 0.0,maxf(real_dt,dt)*10.0)
				if locomotion_blend>0: _blend_recovery_legs(locomotion_blend)
			# Snapshot→new pose crossfade; AnimationPlayer is sampled only once per frame.
			# Bones are visual only, contact tests continue to use authoritative geometry.
			if is_instance_valid(skeleton) and blend_left>0 and blend_pose.size()==skeleton.get_bone_count():
				blend_left=maxf(0,blend_left-animation_dt)
				var weight: float=1.0-blend_left/blend_duration
				# Enemy role playback replaces these writes immediately; keep blend state.
				for bone in range(0 if defer_pose_sample else skeleton.get_bone_count()):
					var pose: Transform3D=blend_pose[bone].interpolate_with(skeleton.get_bone_pose(bone),weight)
					skeleton.set_bone_pose_position(bone,pose.origin)
					skeleton.set_bone_pose_rotation(bone,pose.basis.get_rotation_quaternion())
					skeleton.set_bone_pose_scale(bone,pose.basis.get_scale())
	# A blended articulated arm follows a curved path; the gate's separate
	# translation otherwise drifts away from the hand during clip crossfades.
	if kind=="hero" and is_instance_valid(skeleton) and blend_left>0:
		var hand: int=skeleton.find_bone("handL")
		var grip: int=skeleton.find_bone("socket_gate_grip")
		var gate: int=skeleton.find_bone("gate")
		if hand>=0 and grip>=0 and gate>=0:
			skeleton.force_update_all_bone_transforms()
			var offset: Vector3=skeleton.get_bone_global_pose(hand).origin-skeleton.get_bone_global_pose(grip).origin
			var gate_pose: Transform3D=skeleton.get_bone_global_pose(gate)
			gate_pose.origin+=offset
			skeleton.set_bone_global_pose(gate,gate_pose)
	if kind=="hero": _ground_hero_feet(float(s.position.y))
	warning.visible=not s.dead and kind!="hero" and s.get("state","") in ["warning","spawn"]
	if warning.visible:
		var phase: String=s.get("state","")
		var attack_shape: String="spawn" if phase=="spawn" else str(s.get("attack_shape","circle"))
		var radius: float=0.85 if phase=="spawn" else 4.45 if kind in ["elite","boss"] else 2.50
		var key: String=kind+"/"+attack_shape
		if warning_key!=key:
			warning_key=key
			if attack_shape=="line":
				var shape:=BoxMesh.new()
				shape.size=Vector3(2.5 if kind=="pouncer" else 1.7,0.025,8.48 if kind=="pouncer" else 31.5)
				warning.mesh=shape
			elif attack_shape=="cone":
				var shape:=ImmediateMesh.new()
				shape.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
				for i in range(20):
					var a: float=lerpf(-acos(0.4),acos(0.4),float(i)/20)
					var b: float=lerpf(-acos(0.4),acos(0.4),float(i+1)/20)
					shape.surface_add_vertex(Vector3.ZERO)
					shape.surface_add_vertex(Vector3(sin(a),0,-cos(a))*radius)
					shape.surface_add_vertex(Vector3(sin(b),0,-cos(b))*radius)
				shape.surface_end()
				warning.mesh=shape
			else:
				var shape:=CylinderMesh.new()
				shape.top_radius=radius;shape.bottom_radius=radius;shape.height=0.025
				warning.mesh=shape
			var mat:=Stage.material(Color("cf7444") if phase=="spawn" else Color("df493b"),0.8,0,0.5)
			mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a=0.3
			mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
			if phase!="spawn":mat.albedo_color=Color(1.0,0.13,0.035,0.3)
			warning.material_override=mat
			warning_back.mesh=_danger_border(attack_shape,radius,0.20)
			warning_edge.mesh=_danger_border(attack_shape,radius,0.085)
		var aim: Vector3=s.get("aim",Vector3.FORWARD)
		warning.global_rotation=Vector3(0,atan2(-aim.x,-aim.z),0)
		warning.global_position=s.position+Vector3(0,0.025,0)
		if attack_shape=="line":warning.global_position+=aim*(15.7 if kind=="ranged" else 2.99)
		var tint: Color=warning.material_override.albedo_color
		tint.a=0.13+0.23*float(s.get("warning_progress",0))
		warning.material_override.albedo_color=tint

	warning_edge.visible=warning.visible and s.get("state","")=="warning"
	warning_back.visible=warning_edge.visible
	attack_alert.visible=warning_edge.visible
	if warning_edge.visible:
		warning_edge.global_transform=warning.global_transform
		warning_edge.position.y+=0.015
		warning_back.global_transform=warning.global_transform
		warning_back.position.y+=0.010

func _danger_border(shape: String, radius: float, width: float) -> ImmediateMesh:
	var mesh:=ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	if shape=="line":
		var half_width: float=1.25 if kind=="pouncer" else 0.85
		var half_length: float=4.24 if kind=="pouncer" else 15.75
		var points=[Vector3(-half_width,0,-half_length),Vector3(half_width,0,-half_length),Vector3(half_width,0,half_length),Vector3(-half_width,0,half_length)]
		for i in range(4):_border_strip(mesh,points[i],points[(i+1)%4],width)
	else:
		var span: float=2*acos(0.4) if shape=="cone" else TAU
		for i in range(48):
			var a:float=-span*.5+span*i/48
			var b:float=-span*.5+span*(i+1)/48
			_border_strip(mesh,Vector3(sin(a),0,-cos(a))*radius,Vector3(sin(b),0,-cos(b))*radius,width)
		if shape=="cone":
			for angle in [-span*.5,span*.5]:_border_strip(mesh,Vector3.ZERO,Vector3(sin(angle),0,-cos(angle))*radius,width)
	mesh.surface_end()
	return mesh
func _border_strip(mesh: ImmediateMesh, a: Vector3, b: Vector3, width: float) -> void:
	var side:Vector3=(b-a).normalized().cross(Vector3.UP)*width*.5
	for vertex in [a-side,a+side,b-side,a+side,b+side,b-side]:mesh.surface_add_vertex(vertex)

func _blend_recovery_legs(weight: float) -> void:
	if not is_instance_valid(skeleton) or not player.has_animation("run"):return
	var run: Animation=player.get_animation("run")
	var time: float=fposmod(locomotion_time,run.length)
	var hips: int=skeleton.find_bone("hips")
	var original_hips: Vector3=skeleton.get_bone_pose_position(hips) if hips>=0 else Vector3.ZERO
	for track in range(run.get_track_count()):
		var path: NodePath=run.track_get_path(track)
		if path.get_subname_count()==0:continue
		var bone_name: String=path.get_subname(path.get_subname_count()-1)
		if bone_name not in ["hips","thighL","shinL","footL","thighR","shinR","footR"]:continue
		var bone: int=skeleton.find_bone(bone_name)
		if bone<0:continue
		match run.track_get_type(track):
			Animation.TYPE_POSITION_3D:
				skeleton.set_bone_pose_position(bone,skeleton.get_bone_pose_position(bone).lerp(run.position_track_interpolate(track,time),weight))
			Animation.TYPE_ROTATION_3D:
				skeleton.set_bone_pose_rotation(bone,skeleton.get_bone_pose_rotation(bone).slerp(run.rotation_track_interpolate(track,time),weight))
			Animation.TYPE_SCALE_3D:
				skeleton.set_bone_pose_scale(bone,skeleton.get_bone_pose_scale(bone).lerp(run.scale_track_interpolate(track,time),weight))

	if anim in ["q1","dash_attack"] and hips>=0:
		var chest: int=skeleton.find_bone("chest")
		if chest>=0:
			var difference: Vector3=original_hips-skeleton.get_bone_pose_position(hips)
			skeleton.set_bone_pose_position(chest,skeleton.get_bone_pose_position(chest)+difference)

# Blended bent legs can dip through the floor even when both source clips clear it.
# Correct only required penetration; preserve the authored chest/gate world arc.
func _cache_hero_foot_bounds(node: Node) -> void:
	if node is MeshInstance3D and node.mesh and node.skin:
		var bindings=[]
		for bind in range(node.skin.get_bind_count()):
			var bone: int=node.skin.get_bind_bone(bind)
			if bone<0:bone=skeleton.find_bone(node.skin.get_bind_name(bind))
			bindings.append({"bone":bone,"pose":node.skin.get_bind_pose(bind)})
		for surface in range(node.mesh.get_surface_count()):
			var arrays=node.mesh.surface_get_arrays(surface)
			var vertices=arrays[Mesh.ARRAY_VERTEX];var bones=arrays[Mesh.ARRAY_BONES];var weights=arrays[Mesh.ARRAY_WEIGHTS]
			if bones==null or weights==null:continue
			for vertex in range(vertices.size()):
				for slot in range(4):
					var weight: float=weights[vertex*4+slot]
					var binding: Dictionary=bindings[bones[vertex*4+slot]]
					if weight<=0 or binding.bone<0 or skeleton.get_bone_name(binding.bone) not in ["footL","footR"]:continue
					if weight<0.999:hero_mixed_foot_vertices+=1;continue
					hero_rigid_foot_vertices+=1
					var point: Vector3=binding.pose*vertices[vertex]
					if hero_foot_bounds.has(binding.bone):hero_foot_bounds[binding.bone]=hero_foot_bounds[binding.bone].expand(point)
					else:hero_foot_bounds[binding.bone]=AABB(point,Vector3.ZERO)
	for child in node.get_children():_cache_hero_foot_bounds(child)

func _ground_hero_feet(floor_y: float) -> void:
	hero_ground_lift=0
	if kind!="hero" or hero_foot_bounds.size()!=2 or (locomotion_blend<=0 and blend_left<=0):return
	skeleton.force_update_all_bone_transforms()
	var bottom=INF
	for bone in hero_foot_bounds:
		var pose: Transform3D=skeleton.global_transform*skeleton.get_bone_global_pose(bone)
		var box: AABB=hero_foot_bounds[bone]
		for corner in range(8):bottom=minf(bottom,(pose*box.get_endpoint(corner)).y)
	var clearance: float=floor_y+0.006
	if bottom>=clearance:return
	hero_ground_lift=clearance-bottom
	var hips: int=skeleton.find_bone("hips");var chest: int=skeleton.find_bone("chest")
	var chest_pose: Transform3D=skeleton.get_bone_global_pose(chest)
	var hips_pose: Transform3D=skeleton.get_bone_global_pose(hips)
	hips_pose.origin+=skeleton.global_transform.basis.inverse()*Vector3.UP*hero_ground_lift
	skeleton.set_bone_global_pose(hips,hips_pose)
	skeleton.set_bone_global_pose(chest,chest_pose)
