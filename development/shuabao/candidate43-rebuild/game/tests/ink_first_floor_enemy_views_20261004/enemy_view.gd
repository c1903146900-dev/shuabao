extends "res://scripts/integration/enemy_actor_view.gd"
## Reuses production imported-model/rig/socket/bar construction, no proxy fallback.
## Deliberately replaces incremental sync with absolute detached pose sampling.
const Palette = preload("res://tests/ink_style_specimen_20261004/style.gd")
const Catalog = preload("res://tests/ink_first_floor_enemy_views_20261004/asset_catalog.gd")
var import_report: Dictionary = {}
var sample_report: Dictionary = {}
var _clips: Dictionary = {}
var _palette: Array[StandardMaterial3D] = []
var _base_colors: Array[Color] = []
var _shield: MeshInstance3D
var _height := 1.5

func configure(actor_kind: String) -> bool:
	set_process(false); set_physics_process(false)
	var definition: Dictionary = Catalog.entry(actor_kind)
	if definition.is_empty() or not ResourceLoader.exists(str(definition.get("asset", ""))):
		import_report = {"status":"HOLD_missing_exact_role_asset","kind":actor_kind}; return false
	var packed := load(str(definition.asset)) as PackedScene
	if packed == null:
		import_report = {"status":"HOLD_not_imported_scene","kind":actor_kind}; return false
	super.setup(actor_kind, packed)
	if player == null or skeleton == null:
		import_report = {"status":"HOLD_missing_imported_rig","kind":actor_kind}; return false
	for key: StringName in player.get_animation_list():
		var short_name := str(key).get_slice("/",str(key).get_slice_count("/")-1)
		_clips[short_name] = key
	for required: String in ["idle", str(definition.locomotion_clip), "attack", "death", str(definition.hurt_clip)]:
		if not _clips.has(required):
			import_report = {"status":"HOLD_missing_role_clip","kind":actor_kind,"clip":required}; return false
	if actor_kind == "pouncer" and not _clips.has("leap"):
		import_report = {"status":"HOLD_missing_leap","kind":actor_kind}; return false
	for mesh: MeshInstance3D in meshes:
		for index in range(mesh.mesh.get_surface_count()):
			var old: Material = mesh.mesh.surface_get_material(index)
			var hint := old.resource_name.to_lower() if old != null else ""
			var swatch := _swatch(hint)
			var material := Palette.matte(swatch.color, swatch.map)
			mesh.set_surface_override_material(index, material)
			_palette.append(material); _base_colors.append(swatch.color)
	_height = float(definition.height_m) + 0.26
	for bar in [hp_back, hp_fill]:
		var material := Palette.matte(Palette.DANGER if bar == hp_fill else Palette.SURFACE)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		material.billboard_keep_scale = true; material.no_depth_test = true
		material.render_priority = 2 if bar == hp_fill else 1
		bar.material_override = material
	_shield = MeshInstance3D.new()
	var shield_quad := QuadMesh.new(); shield_quad.size = Vector2(HEALTH_BAR_WIDTH,0.035)
	_shield.mesh = shield_quad
	var shield_material := hp_fill.material_override.duplicate() as StandardMaterial3D
	shield_material.albedo_color = Palette.ACCENT; shield_material.render_priority = 3
	_shield.material_override = shield_material
	_shield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shield)
	health.modulate = Palette.TEXT; health.font_size = 18
	for hidden in [warning, warning_edge, warning_back, attack_alert, role_status]: hidden.visible = false
	var clip_lengths: Dictionary = {}
	for short_name: String in _clips: clip_lengths[short_name] = player.get_animation(_clips[short_name]).length
	import_report = {"status":"imported_original_matte_candidate_unreviewed","kind":actor_kind,"asset":definition.asset,"meshes":meshes.size(),"bones":skeleton.get_bone_count(),"clips":clip_lengths,"model_proportions_unchanged":true,"source_collision_unchanged":true,"art_accepted":false}
	return true

func _swatch(hint: String) -> Dictionary:
	# Same four authored maps as minion; role accent slots remain distinct.
	if "bronze" in hint or "brass" in hint or "copper" in hint: return {"map":"bronze","color":Color.WHITE}
	if "bone" in hint or "ivory" in hint: return {"map":"bone","color":Color.WHITE}
	if "vermilion" in hint or "ember" in hint or "terracotta" in hint or "eye" in hint: return {"map":"","color":Color("B35F48")}
	if "violet" in hint: return {"map":"","color":Color("858AA2")}
	if "jade" in hint: return {"map":"","color":Color("72988E")}
	if "ink" in hint or "charcoal" in hint or "graphite" in hint or "cloth" in hint: return {"map":"","color":Palette.SURFACE}
	return {"map":"carapace","color":Color.WHITE}

func apply_sample(sample: Dictionary) -> void:
	if player == null or skeleton == null: return
	sample_report = sample.duplicate(true)
	position = sample.position
	var facing: Vector3 = sample.facing
	if facing.length_squared() > 0.001: rotation.y = atan2(-facing.x,-facing.z)
	visual.scale = Vector3.ONE * float(sample.model_scale)
	var clip := str(sample.clip)
	if not _clips.has(clip):
		sample_report["status"] = "HOLD_missing_selected_clip"; visible = false; return
	var animation: Animation = player.get_animation(_clips[clip])
	var at := fposmod(float(sample.time),animation.length) if bool(sample.loop) else clampf(float(sample.time),0.0,animation.length)
	skeleton.reset_bone_poses()
	player.play(_clips[clip]); player.seek(at,true)
	played_clip = clip; sampled_time = at
	sample_report["sampled_time"] = at
	visible = not bool(sample.cleanup)
	var show := not bool(sample.dead)
	health.position.y = _height * float(sample.model_scale)
	hp_fill.position.y = health.position.y - 0.13; hp_back.position.y = hp_fill.position.y
	_shield.position.y = hp_fill.position.y + 0.075
	health.visible = show
	health.text = "%s  %d / %d" % [str(sample.kind), ceili(float(sample.hp)), ceili(float(sample.max_hp))]
	if bool(sample.has_shield): health.text += "  盾 %d" % ceili(float(sample.shield))
	hp_back.visible = show
	_set_bar(hp_fill,float(sample.hp_fraction),show)
	_set_bar(_shield,float(sample.shield_fraction),show and bool(sample.has_shield))
	var brightness := 1.0 + float(sample.hit_flash)
	for index in range(_palette.size()): _palette[index].albedo_color = _base_colors[index] * Color(brightness,brightness,brightness,1.0)

func _set_bar(bar: MeshInstance3D, fraction: float, show: bool) -> void:
	var quad := bar.mesh as QuadMesh
	quad.size.x = HEALTH_BAR_WIDTH * fraction
	quad.center_offset.x = -HEALTH_BAR_WIDTH * (1.0-fraction) * 0.5
	bar.visible = show and fraction > 0.0

func socket_world(socket_name: String) -> Dictionary:
	var bone := skeleton.find_bone(socket_name) if skeleton != null else -1
	if bone < 0: return {"found":false,"socket":socket_name}
	skeleton.force_update_all_bone_transforms()
	return {"found":true,"socket":socket_name,"position":skeleton.global_transform*skeleton.get_bone_global_pose(bone).origin}

func cast_socket_world() -> Vector3:
	# Do not inherit the production generic fallback point for a missing socket.
	var result := socket_world("socket_cast")
	return result.position if result.found else Vector3.INF
