extends Node3D
## Original existing minion geometry/animation; detached source state only.
const Style = preload("res://tests/ink_style_specimen_20261004/style.gd")
const ASSET := "res://assets/enemies/siege_brood/minion/minion.glb"
const CONTRACT := "res://assets/enemies/siege_brood/animation_contract.json"
var player: AnimationPlayer
var skeleton: Skeleton3D
var clips: Dictionary = {}
var materials: Array[StandardMaterial3D] = []
var base_colors: Array[Color] = []
var fill: MeshInstance3D
var proof: Dictionary = {"status":"not_loaded","clips":{},"source_geometry_unchanged":true,"source_ai_unchanged":true}
var last_position := Vector3.INF
var gait := 0.0
var attack_contact := .46
var attack_recovery := .68
var dead_at := -1.0
var last_contact := -100.0
func _ready() -> void:
	set_process(false)
	var contract: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(CONTRACT))
	var entry: Dictionary=contract.get("enemies",{}).get("minion",{})
	attack_contact=float(entry.get("windup_s",.46))
	attack_recovery=float(entry.get("recovery_s",.68))
	if not ResourceLoader.exists(ASSET):
		proof.status="HOLD_missing_minion"
		return
	var scene: PackedScene=load(ASSET)
	var body:=scene.instantiate()
	add_child(body)
	_scan(body)
	if player == null or skeleton == null:
		proof.status="HOLD_imported_rig_missing"
		return
	player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for key: StringName in player.get_animation_list():
		var short_name:=str(key).get_slice("/",str(key).get_slice_count("/")-1)
		clips[short_name]=key
		proof.clips[short_name]=player.get_animation(key).length
	for front in [false,true]:
		var node:=MeshInstance3D.new()
		var quad:=QuadMesh.new()
		quad.size=Vector2(.95,.075 if front else .115)
		node.mesh=quad
		node.position=Vector3(0,1.42,0)
		var mat:=Style.matte(Style.DANGER if front else Style.SURFACE)
		mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED
		mat.billboard_keep_scale=true
		mat.no_depth_test=true
		mat.render_priority=2 if front else 1
		node.material_override=mat
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		if front:fill=node
	proof.status="existing_original_geometry_new_matte_palette_unreviewed"
func _scan(node: Node) -> void:
	if node is AnimationPlayer:player=node
	if node is Skeleton3D:skeleton=node
	if node is MeshInstance3D:
		for index in range(node.mesh.get_surface_count()):
			var old_material: Material=node.mesh.surface_get_material(index)
			var name_hint:=old_material.resource_name.to_lower() if old_material!=null else ""
			var key:="carapace"
			var color:=Color.WHITE
			if "bronze" in name_hint:key="bronze"
			elif "bone" in name_hint:key="bone"
			elif "vermilion" in name_hint:key="";color=Color("B35F48")
			var mat:=Style.matte(color,key)
			node.set_surface_override_material(index,mat)
			materials.append(mat)
			base_colors.append(color)
	for child in node.get_children():_scan(child)
func contact(receipt: Dictionary) -> void:
	if float(receipt.get("actual_damage",0.0))>0:last_contact=float(receipt.get("contact_time",-100.0))
func present(state: Dictionary, source_time: float) -> void:
	if player==null or skeleton==null:return
	var at: Vector3=state.get("position",Vector3.ZERO)
	var moved:=last_position.distance_to(at) if last_position.is_finite() else 0.0
	position=at
	var facing: Vector3=state.get("facing",Vector3.FORWARD)
	if facing.length_squared()>.001:rotation.y=atan2(-facing.x,-facing.z)
	gait+=moved/2.8
	var clip:="run" if moved>.0001 else "idle"
	var at_time:=gait if clip=="run" else source_time
	var phase:=str(state.get("state","chase"))
	if state.get("dead",false):
		if dead_at<0:dead_at=source_time
		clip="death";at_time=source_time-dead_at
	elif phase=="warning":
		clip="attack";at_time=attack_contact*clampf(float(state.get("warning_progress",0.0)),0,1)
	elif phase=="recover":
		clip="attack";at_time=attack_contact+attack_recovery*clampf(1.0-float(state.get("timer",attack_recovery))/attack_recovery,0,1)
	if clips.has(clip):
		var animation:=player.get_animation(clips[clip])
		at_time=fposmod(at_time,animation.length) if clip in ["idle","run"] else clampf(at_time,0,animation.length)
		skeleton.reset_bone_poses()
		player.play(clips[clip]);player.seek(at_time,true)
	var fraction:=clampf(float(state.get("hp",0.0))/maxf(.001,float(state.get("max_hp",1.0))),0,1)
	fill.scale.x=maxf(.001,fraction)
	fill.visible=not state.get("dead",false)
	var flash:=.12 if source_time-last_contact>=0 and source_time-last_contact<.075 else 0.0
	for index in range(materials.size()):materials[index].albedo_color=base_colors[index]*Color(1.0+flash,1.0+flash,1.0+flash,1.0)
	last_position=at
