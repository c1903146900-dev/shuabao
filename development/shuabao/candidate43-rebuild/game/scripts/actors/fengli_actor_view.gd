extends Node3D
## Isolated source-final Fengli presentation. Never writes simulation state.
## Action clips do not imply locomotion locks. Runtime forced motion is explicit.
signal phase_reached(payload: Dictionary)

const MODEL := preload("res://assets/fengli/fengli_final.glb")
const CONTRACT_PATH := "res://assets/fengli/animation_contract_final.json"
const LEG_BONES := ["thigh-1", "shin-1", "foot-1", "thigh1", "shin1", "foot1"]
var visual: Node3D
var player: AnimationPlayer
var skeleton: Skeleton3D
var locomotion_model: Node3D
var locomotion_player: AnimationPlayer
var locomotion_skeleton: Skeleton3D
var contract: Dictionary = {}
var current_clip := "idle"
var clip_time_domain := "world"
var dying := false
var clip_elapsed := 0.0
var clip_duration := 0.0
var playback_scale := 1.0
var locomotion_time := 0.0
var idle_time := 0.0
var moving_blend := 0.0
var phase_evidence: Array = []
var seen_markers: Dictionary = {}
var previous_position := Vector3.ZERO
var has_previous := false
var last_facing := Vector3.FORWARD
var played_clip := ""
var cast_id := ""
var baseline_visual_scale := 1.0
var applied_model_scale := 1.0
var effective_visual_scale := 1.0
var authored_run_reference_speed := 2.4
var foot_bounds: Dictionary = {}
var foot_points: Dictionary = {}
var ground_lift := 0.0
var mixed_foot_vertices := 0
var hit_left := 0.0
var hit_duration := .09
var hit_direction := Vector3.ZERO
var hit_heavy := false
var flash_material: StandardMaterial3D
var flash_meshes: Array[MeshInstance3D] = []
var original_overlays: Array = []
var state_material: ShaderMaterial
var overloaded := false
var untargetable_visual := false
var source_pose: Array[Transform3D] = []
var locomotion_source_pose: Array[Transform3D] = []

func setup(_kind: String = "hero", packed: PackedScene = null) -> void:
	contract = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT_PATH))
	baseline_visual_scale = float(contract.get("baseline_visual_scale", 1.0))
	authored_run_reference_speed = float(contract.get("authored_run_reference_speed_mps", contract.get("run_reference_speed_mps", 2.4)))
	effective_visual_scale = baseline_visual_scale
	var scene: PackedScene = packed if packed != null else MODEL
	visual = scene.instantiate()
	add_child(visual)
	visual.scale = Vector3.ONE * effective_visual_scale
	player = _find(visual, "AnimationPlayer") as AnimationPlayer
	skeleton = _find(visual, "Skeleton3D") as Skeleton3D
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	# A hidden sampler supplies only lower-body locomotion while the real actor attacks.
	locomotion_model = scene.instantiate()
	locomotion_model.visible = false
	add_child(locomotion_model)
	locomotion_model.scale = Vector3.ONE * effective_visual_scale
	locomotion_player = _find(locomotion_model, "AnimationPlayer") as AnimationPlayer
	locomotion_skeleton = _find(locomotion_model, "Skeleton3D") as Skeleton3D
	locomotion_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for ap in [player, locomotion_player]:
		for clip in ["idle", "run"]:
			ap.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	_sample(player, "idle", 0.0)
	_cache_foot_bounds(visual)
	flash_material = StandardMaterial3D.new()
	flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_material.albedo_color = Color(.55, .20, .23, .26)
	_cache_flash(visual)
	state_material = ShaderMaterial.new()
	state_material.shader = preload("res://assets/fengli/vfx/state_rim.gdshader")

func _find(node: Node, class_name_value: String) -> Node:
	if node.is_class(class_name_value): return node
	for child in node.get_children():
		var found := _find(child, class_name_value)
		if found != null: return found
	return null

func event(clip: String, duration := -1.0, identifier := "") -> void:
	if not contract.get("clips", {}).has(clip): return
	current_clip = clip
	clip_elapsed = 0.0
	clip_duration = float(contract.clips[clip].get("runtime_default_duration_s", contract.clips[clip].duration_s)) if duration <= 0 else duration
	clip_time_domain = "real" if clip in ["dash", "dash_attack", "r1", "death"] else "world"
	playback_scale = float(contract.clips[clip].duration_s) / maxf(.0001, clip_duration)
	cast_id = identifier
	seen_markers.clear()
	_sample(player, clip, 0.0)

func combat_event(e: Dictionary) -> void:
	var kind: String = str(e.get("kind", ""))
	var clip: String = {"attack_started":"attack", "dash_started":"dash", "dash":"dash", "dash_attack_started":"dash_attack", "q1_started":"q1", "q3_started":"q3"}.get(kind, "")
	if kind == "q2_strike_started": clip = "q2_entry" if int(e.get("strike", 1)) == 1 else "q2_strike"
	if kind == "q2_finished": clip = "q2_exit"
	if kind == "e1_started": clip = "e1_throw"
	if kind == "r1_started": clip = "r1"
	if kind == "r2_throw_started": clip = "r2_throw_high" if int(e.get("count",1))>=4 else "r2_throw"
	if kind in ["overload_started", "e3_started"]: clip = "e3_activate"
	if kind in ["hero_died", "hero_death"]: dying = true; clip = "death"
	if kind == "e1_pierce_started": clip = "e1_pierce"
	if kind == "e1_finished" and bool(e.get("pierced",false)) and current_clip == "e1_pierce": clip = "e1_recover"
	if kind == "e2_started": clip = "e2_spin3" if int(e.get("rotations",1)) == 3 else "e2_spin"
	if kind == "e2_blink": clip = "e2_blink"
	if kind == "e2_spin_started" and e.get("phase","") == "extra": clip = "e2_afterspin"
	if kind == "e2_return" and current_clip not in ["e2_spin","e2_spin3","e2_afterspin"]: clip = "e2_return"
	if kind in ["attack_cancelled", "basic_cancelled", "skill_cancelled", "cast_cancelled", "r1_cancelled"]:
		for identifier in e.get("cast_ids", [e.get("cast_id", "")]):
			if not str(identifier).is_empty() and str(identifier) == cast_id:
				clip_duration = 0.0
				seen_markers.clear()
	if not clip.is_empty():
		var duration: float = float(e.get("rotation_duration", -1.0)) if clip == "e2_afterspin" else float(e.get("duration", -1.0))
		if clip in ["e3_activate", "death"]: duration = -1.0
		event(clip, duration, str(e.get("cast_id", "")))
		clip_time_domain = str(e.get("animation", {}).get("time_domain", clip_time_domain))

func sync(state: Dictionary, dt: float, frozen := false, _real_dt := -1.0) -> void:
	if not is_instance_valid(player): return
	var dead: bool = bool(state.get("dead", false))
	if dead and not dying:
		dying = true
		event("death")
	elif not dead and dying:
		dying = false
		clip_duration = 0.0
		current_clip = "idle"
	overloaded = state.get("cast_state", {}).has("e3") and not dead
	untargetable_visual = bool(state.get("untargetable", false)) and not dead
	state_material.set_shader_parameter("overload", 1.0 if overloaded else 0.0)
	state_material.set_shader_parameter("untargetable", 1.0 if untargetable_visual else 0.0)
	var destination: Vector3 = state.get("position", position)
	var distance: float = previous_position.distance_to(destination) if has_previous else 0.0
	previous_position = destination
	has_previous = true
	position = destination
	applied_model_scale = maxf(.08, float(state.get("model_scale", 1.0)))
	effective_visual_scale = baseline_visual_scale * applied_model_scale
	visual.scale = Vector3.ONE * effective_visual_scale
	locomotion_model.scale = Vector3.ONE * effective_visual_scale
	var direction: Vector3 = state.get("facing", state.get("aim", last_facing))
	if direction.length_squared() > .001: last_facing = direction.normalized()
	rotation.y = atan2(-last_facing.x, -last_facing.z)
	var movement_dt: float = maxf(dt, _real_dt) if _real_dt >= 0 else dt
	var forced_motion: bool = bool(state.get("forced_motion", false))
	var moving: bool = distance > .0001 and not forced_motion and not dead
	moving_blend = 0.0 if forced_motion else move_toward(moving_blend, 1.0 if moving else 0.0, movement_dt * 14.0)
	locomotion_time += distance / maxf(.1, authored_run_reference_speed * effective_visual_scale) if moving else 0.0
	idle_time += 0.0 if frozen else dt
	var action_active: bool = clip_duration > 0 and clip_elapsed < clip_duration
	if action_active:
		var action_dt: float = maxf(0.0, _real_dt) if clip_time_domain == "real" and _real_dt >= 0.0 else (0.0 if frozen else dt)
		clip_elapsed = minf(clip_duration, clip_elapsed + action_dt)
		_sample(player, current_clip, clip_elapsed * playback_scale)
		_record_markers()
		if moving_blend > 0.001 and current_clip not in ["idle", "run", "dash"]:
			_sample(locomotion_player, "run", fmod(locomotion_time, float(contract.clips.run.duration_s)))
			skeleton.force_update_all_bone_transforms()
			var hips := skeleton.find_bone("hips")
			var chest := skeleton.find_bone("chest")
			var preserved_chest := skeleton.get_bone_global_pose(chest)
			# Rotating torso/weapon stays authored; walking legs retain the true travel plane.
			# This changes no world position and never locks the moving E2 spin.
			if current_clip in ["e2_spin","e2_spin3","e2_afterspin"]:
				var root_index := skeleton.find_bone("root")
				skeleton.set_bone_pose_rotation(root_index, skeleton.get_bone_pose_rotation(root_index).slerp(Quaternion.IDENTITY, moving_blend))
			skeleton.set_bone_pose_position(hips, skeleton.get_bone_pose_position(hips).lerp(locomotion_skeleton.get_bone_pose_position(locomotion_skeleton.find_bone("hips")), moving_blend))
			skeleton.set_bone_global_pose(chest, preserved_chest)
			for bone_name in LEG_BONES:
				var i := skeleton.find_bone(bone_name)
				var j := locomotion_skeleton.find_bone(bone_name)
				if i < 0 or j < 0: continue
				skeleton.set_bone_pose_rotation(i, skeleton.get_bone_pose_rotation(i).slerp(locomotion_skeleton.get_bone_pose_rotation(j), moving_blend))
				skeleton.set_bone_pose_position(i, skeleton.get_bone_pose_position(i).lerp(locomotion_skeleton.get_bone_pose_position(j), moving_blend))
	elif dying and contract.clips.has("death"):
		current_clip = "death"
		_sample(player, "death", float(contract.clips.death.duration_s))
	else:
		current_clip = "run" if moving else "idle"
		var at: float = fmod(locomotion_time, float(contract.clips.run.duration_s)) if moving else fmod(idle_time, float(contract.clips.idle.duration_s))
		_sample(player, current_clip, at)
	_ground_feet()
	_present_hit(movement_dt)

func _sample(ap: AnimationPlayer, clip: String, at: float) -> void:
	# Imported GLB optimizes constant channels. Restore the last pristine sampled
	# pose before resampling so lower-body/global overrides never accumulate.
	# Rest-pose reset is wrong here: untracked imported constants are authored.
	var sampled_skeleton: Skeleton3D = skeleton if ap == player else locomotion_skeleton
	var pristine: Array[Transform3D] = source_pose if ap == player else locomotion_source_pose
	for i in pristine.size(): sampled_skeleton.set_bone_pose(i, pristine[i])
	if ap.current_animation != clip: ap.play(clip)
	ap.seek(at, true)
	ap.advance(0.0)
	pristine.clear()
	for i in sampled_skeleton.get_bone_count(): pristine.append(sampled_skeleton.get_bone_pose(i))

func _record_markers() -> void:
	for marker in contract.clips[current_clip].phase_markers_s:
		var time_value: float = float(contract.clips[current_clip].phase_markers_s[marker])
		if clip_elapsed * playback_scale + .00001 >= time_value and not seen_markers.has(marker):
			seen_markers[marker] = true
			var evidence := {"cast_id":cast_id, "clip":current_clip, "marker":marker, "authored_s":time_value, "elapsed_s":clip_elapsed}
			phase_evidence.append(evidence)
			if phase_evidence.size() > 256: phase_evidence.pop_front()
			phase_reached.emit(evidence.duplicate(true))

func socket_position(socket: String) -> Vector3:
	var bone_name: String = contract.get("bone_attachments", {}).get(socket, socket)
	var i := skeleton.find_bone(bone_name)
	return skeleton.global_transform * skeleton.get_bone_global_pose(i).origin if i >= 0 else global_position


func _cache_foot_bounds(node: Node) -> void:
	if node is MeshInstance3D and node.mesh and node.skin:
		var bindings: Array = []
		for bind in node.skin.get_bind_count():
			var bone: int = node.skin.get_bind_bone(bind)
			if bone < 0: bone = skeleton.find_bone(node.skin.get_bind_name(bind))
			bindings.append({"bone":bone, "pose":node.skin.get_bind_pose(bind)})
		for surface in node.mesh.get_surface_count():
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var vertices = arrays[Mesh.ARRAY_VERTEX]
			var bones = arrays[Mesh.ARRAY_BONES]
			var weights = arrays[Mesh.ARRAY_WEIGHTS]
			if bones == null or weights == null: continue
			for vertex in vertices.size():
				for slot in range(4):
					var weight: float = weights[vertex * 4 + slot]
					var binding: Dictionary = bindings[bones[vertex * 4 + slot]]
					if weight <= 0 or binding.bone < 0 or skeleton.get_bone_name(binding.bone) not in ["foot-1", "foot1"]: continue
					if weight < .999:
						mixed_foot_vertices += 1
						continue
					var point: Vector3 = binding.pose * vertices[vertex]
					if not foot_points.has(binding.bone): foot_points[binding.bone] = PackedVector3Array()
					foot_points[binding.bone].append(point)
					if foot_bounds.has(binding.bone): foot_bounds[binding.bone] = foot_bounds[binding.bone].expand(point)
					else: foot_bounds[binding.bone] = AABB(point, Vector3.ZERO)
	for child in node.get_children(): _cache_foot_bounds(child)

func _ground_feet() -> void:
	ground_lift = 0.0
	if foot_bounds.size() != 2 or moving_blend <= 0.0: return
	skeleton.force_update_all_bone_transforms()
	var bottom := INF
	for bone in foot_bounds:
		var pose: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(bone)
		# Exact rigid sole vertices avoid conservative rotated-AABB corners lifting a narrow shoe.
		for point in foot_points[bone]: bottom = minf(bottom, (pose * point).y)
	var floor_y := global_position.y + .008
	if bottom >= floor_y: return
	ground_lift = floor_y - bottom
	var hips := skeleton.find_bone("hips")
	var chest := skeleton.find_bone("chest")
	var chest_pose := skeleton.get_bone_global_pose(chest)
	var hips_pose := skeleton.get_bone_global_pose(hips)
	hips_pose.origin += skeleton.global_transform.basis.inverse() * Vector3.UP * ground_lift
	skeleton.set_bone_global_pose(hips, hips_pose)
	skeleton.set_bone_global_pose(chest, chest_pose)


func hit_reaction(direction: Vector3, hero_hit := true, heavy := false) -> void:
	# Presentation only: no source movement, damage, skill cancel, or invulnerability changes.
	hit_duration = .11 if heavy else .085 if hero_hit else .07
	hit_left = hit_duration
	hit_heavy = heavy
	hit_direction = Vector3(direction.x, 0, direction.z).normalized()
	if current_clip in ["idle", "run"] and contract.clips.has("hit") and not dying: event("hit", .20 if heavy else .15)
	if hit_direction.length_squared() < .001: hit_direction = -last_facing

func _cache_flash(node: Node) -> void:
	if node is MeshInstance3D:
		flash_meshes.append(node)
		original_overlays.append(node.material_overlay)
	for child in node.get_children(): _cache_flash(child)

func _present_hit(dt: float) -> void:
	hit_left = maxf(0.0, hit_left - dt)
	var wave := sin(PI * hit_left / maxf(.001, hit_duration)) if hit_left > 0 else 0.0
	visual.position = global_basis.inverse() * hit_direction * wave * (.04 if hit_heavy else .025)
	for i in flash_meshes.size():
		flash_meshes[i].material_overlay = flash_material if hit_left > 0 else state_material if overloaded or untargetable_visual else original_overlays[i]
	if wave > 0:
		var chest := skeleton.find_bone("chest")
		var rotation := skeleton.get_bone_pose_rotation(chest)
		skeleton.set_bone_pose_rotation(chest, rotation * Quaternion(Vector3.RIGHT, .035 * wave))
