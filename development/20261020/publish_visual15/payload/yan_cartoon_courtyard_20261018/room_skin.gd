extends Node3D
## Independent drawing attachment. The original RoomView owns everything else.
## No source access, input, events, snapshots, wall clock, camera or lighting edits.

const ROOM_SCRIPT := "res://tests/ink_first_floor_room_art_20261004/stage.gd"
const ROOM_SCRIPT_SHA := "7994370235d499c595126e896c724a188a54ae6126951a222f2197c1aa08a292"
const LAYOUT_PATH := "res://tests/ink_first_floor_room_art_20261004/room_layout.json"
const LAYOUT_SHA := "0eb81dacfc66a1117f4a1c1647309c37980bcf72f4de3d50e88a909cd4d1946b"
const GEOMETRY_PATH := "res://yan_cartoon_courtyard_20261018/assets/room/cartoon_courtyard_mesh.json"
const FLOOR_PATH := "res://yan_cartoon_courtyard_20261018/assets/room/painted_courtyard_floor.png"
const GEOMETRY_SHA := "dd86a852d3f491e963cf7f230204e6dc07b7950c06fe98ead0dd0ecf1f135a71"
const FLOOR_SHA := "7f54661029374b9aba1b211d56b9d5171be03ab127b8382c9e14e172513da110"

# Exact visual groups only; original geometry and asset pigment tables remain untouched.
const STONE_VALUE_GROUPS := ["west_gallery_cartoon_foundation", "east_cistern_garden_cartoon_foundation", "north_west_wing_cartoon_foundation", "north_east_wing_cartoon_foundation", "south_west_wing_cartoon_foundation", "south_east_wing_cartoon_foundation", "west_broken_gallery_wall_cartoon", "east_lower_retaining_wall_cartoon", "south_west_wing_low_parapet_cartoon", "south_east_wing_low_parapet_cartoon"]

var _stone_value_receipt: Dictionary = {"status":"not_attempted"}

var receipt: Dictionary = {"attached": false, "reason": "not_attempted", "native_verified": false, "art_accepted": false}
var _stage: WeakRef
var _old_opaque: MeshInstance3D
var _old_shadow: MeshInstance3D
var _old_opaque_visible := false
var _old_shadow_visible := false
var _original_stage_id := 0
var _original_stage_script: Script
var _original_camera_id := 0
var _original_light_id := 0
var _original_opaque_id := 0
var _original_shadow_id := 0
var _original_opaque_mesh_id := 0
var _original_shadow_mesh_id := 0
var _original_shadow_parent_id := 0
var _owns_opaque_hide := false
var _owns_shadow_hide := false
var _static_shadow: MeshInstance3D
var _enabled := false
var _has_saved_visibility := false

func attach_to_stage(stage: Node3D) -> Dictionary:
	if receipt.get("attached", false):
		return receipt.duplicate(true)
	if not is_instance_valid(stage) or stage.get_script() == null or stage.get_script().resource_path != ROOM_SCRIPT:
		return _failed("exact_original_RoomView_required")
	if FileAccess.get_sha256(ROOM_SCRIPT) != ROOM_SCRIPT_SHA or FileAccess.get_sha256(LAYOUT_PATH) != LAYOUT_SHA:
		return _failed("original_room_or_layout_changed")
	var opaque: Node = stage.get_node_or_null("PaintedForecourtOpaque")
	var shadow: Node = stage.get_node_or_null("StaticSoftShadowLayer/BakedVolumeCastAndContact")
	var shadow_layer: Node = stage.get_node_or_null("StaticSoftShadowLayer")
	var camera: Node = stage.get_node_or_null("Forecourt_18m_40degCamera")
	var light: Node = stage.get_node_or_null("SharedWarmKey")
	if not opaque is MeshInstance3D or not shadow is MeshInstance3D or not shadow_layer is Node3D or not camera is Camera3D or not light is DirectionalLight3D:
		return _failed("original_drawing_camera_light_or_shadow_nodes_missing")
	if stage.has_node("CartoonCourtyardSample01"):
		return _failed("duplicate_attachment_refused")
	if not FileAccess.file_exists(GEOMETRY_PATH) or not FileAccess.file_exists(FLOOR_PATH):
		return _failed("cartoon_asset_missing_original_remains_visible")
	if FileAccess.get_sha256(GEOMETRY_PATH) != GEOMETRY_SHA or FileAccess.get_sha256(FLOOR_PATH) != FLOOR_SHA:
		return _failed("cartoon_asset_hash_mismatch_original_remains_visible")
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(GEOMETRY_PATH))
	if not value is Dictionary:
		return _failed("cartoon_geometry_unreadable_original_remains_visible")
	var data: Dictionary = value
	if data.get("schema", "") != "shuabao-original-cartoon-courtyard-1" or not _valid_mesh(data.get("opaque", {})) or not _valid_mesh(data.get("static_shadow", {})):
		return _failed("cartoon_geometry_invalid_original_remains_visible")
	# PNG bytes are the original generated asset. This supports a fresh uncached
	# composition without requiring a pre-existing editor import sidecar.
	var floor_image := Image.load_from_file(FLOOR_PATH)
	if floor_image == null or floor_image.is_empty():
		return _failed("cartoon_floor_image_unreadable_original_remains_visible")
	var floor_texture := ImageTexture.create_from_image(floor_image)
	if floor_texture == null:
		return _failed("cartoon_floor_texture_unavailable_original_remains_visible")
	name = "CartoonCourtyardSample01"
	var floor_view := _make_floor(floor_texture)
	var prop_view := _make_mesh("RoundedPaintedCourtyard", data.opaque, false, data.groups)
	_static_shadow = _make_mesh("SimplePaintedContactShadows", data.static_shadow, true)
	if floor_view.mesh == null or prop_view.mesh == null or _static_shadow.mesh == null:
		return _failed("cartoon_mesh_build_failed_original_remains_visible")
	add_child(floor_view)
	add_child(prop_view)
	add_child(_static_shadow)
	_stage = weakref(stage)
	_old_opaque = opaque as MeshInstance3D
	_old_shadow = shadow as MeshInstance3D
	_old_opaque_visible = _old_opaque.visible
	_old_shadow_visible = _old_shadow.visible
	_has_saved_visibility = true
	_original_stage_id = stage.get_instance_id()
	_original_stage_script = stage.get_script()
	_original_camera_id = camera.get_instance_id()
	_original_light_id = light.get_instance_id()
	_original_opaque_id = _old_opaque.get_instance_id()
	_original_shadow_id = _old_shadow.get_instance_id()
	_original_opaque_mesh_id = _old_opaque.mesh.get_instance_id() if _old_opaque.mesh != null else 0
	_original_shadow_mesh_id = _old_shadow.mesh.get_instance_id() if _old_shadow.mesh != null else 0
	_original_shadow_parent_id = _old_shadow.get_parent().get_instance_id()
	stage.add_child(self)
	# Commit only after the complete new drawing attachment is present.
	_enabled = true
	_old_opaque.visible = false
	_old_shadow.visible = false
	_owns_opaque_hide = true
	_owns_shadow_hide = true
	_static_shadow.visible = (shadow_layer as Node3D).visible
	receipt = {
		"attached": true, "reason": "complete_drawing_attachment_installed",
		"stage_id": _original_stage_id, "camera_id": _original_camera_id, "light_id": _original_light_id,
		"original_room_script": ROOM_SCRIPT, "original_room_script_sha256": ROOM_SCRIPT_SHA,
		"original_layout_sha256": LAYOUT_SHA, "geometry_sha256": GEOMETRY_SHA, "floor_sha256": FLOOR_SHA,
		"hidden_original_nodes": [str(_old_opaque.get_path()), str(_old_shadow.get_path())],
		"saved_visibility": [_old_opaque_visible, _old_shadow_visible],
		"source_reads": 0, "source_writes": 0, "new_gameplay_event_connections": 0,
		"camera_light_or_stage_replaced": false, "native_verified": false, "art_accepted": false,
		"stats": data.get("stats", {}).duplicate(true),
		"stone_value_mapping": _stone_value_receipt.duplicate(true)
	}
	return receipt.duplicate(true)

func _process(_delta: float) -> void:
	# Original F7/static-shadow policy remains authoritative. No time is sampled.
	if not _enabled or _stage == null or not is_instance_valid(_static_shadow): return
	var stage: Node = _stage.get_ref()
	if not _binding_intact(stage):
		_invalidate_binding("original_drawing_or_stage_binding_changed")
		return
	var layer: Node = stage.get_node_or_null("StaticSoftShadowLayer")
	if layer is Node3D: _static_shadow.visible = layer.visible

func set_skin_enabled(enabled: bool) -> void:
	if not receipt.get("attached", false) or _stage == null: return
	var stage: Node = _stage.get_ref()
	if not _binding_intact(stage):
		_invalidate_binding("original_drawing_or_stage_binding_changed")
		return
	_enabled = enabled
	visible = enabled
	if enabled:
		_old_opaque.visible = false
		_old_shadow.visible = false
		_owns_opaque_hide = true
		_owns_shadow_hide = true
	else:
		_restore_original_visibility(false)
	receipt["skin_enabled"] = enabled

func detach() -> void:
	var restoration: Dictionary = _restore_original_visibility()
	receipt["attached"] = false
	receipt["reason"] = "detached_original_visibility_restored" if restoration.get("complete", false) else "detached_restoration_incomplete"
	queue_free()

func _exit_tree() -> void:
	_restore_original_visibility()

func _restore_original_visibility(release_ownership: bool = true) -> Dictionary:
	if not _has_saved_visibility or _stage == null:
		return receipt.get("restoration", {"complete": true, "reason": "no_owned_visibility_change"}).duplicate(true)
	var stage: Node = _stage.get_ref()
	# Each original draw node is independent. Losing one must not strand the
	# other valid original drawing hidden, and must not touch a replacement.
	var opaque_result: Dictionary = _restore_one(stage, _old_opaque, "PaintedForecourtOpaque", _original_opaque_id, _original_stage_id, _original_opaque_mesh_id, _old_opaque_visible, _owns_opaque_hide)
	var shadow_result: Dictionary = _restore_one(stage, _old_shadow, "StaticSoftShadowLayer/BakedVolumeCastAndContact", _original_shadow_id, _original_shadow_parent_id, _original_shadow_mesh_id, _old_shadow_visible, _owns_shadow_hide)
	_owns_opaque_hide = false
	_owns_shadow_hide = false
	if release_ownership: _has_saved_visibility = false
	_enabled = false
	var result: Dictionary = {"complete": opaque_result.get("restored", false) and shadow_result.get("restored", false), "opaque": opaque_result, "shadow": shadow_result}
	receipt["restoration"] = result.duplicate(true)
	return result

func _original_draw_owned(stage: Node, node: MeshInstance3D, path: String, node_id: int, parent_id: int, mesh_id: int) -> bool:
	return is_instance_valid(stage) and stage.get_instance_id() == _original_stage_id and is_instance_valid(node) and node.get_instance_id() == node_id and is_instance_valid(node.get_parent()) and node.get_parent().get_instance_id() == parent_id and stage.get_node_or_null(path) == node and node.mesh != null and node.mesh.get_instance_id() == mesh_id

func _restore_one(stage: Node, node: MeshInstance3D, path: String, node_id: int, parent_id: int, mesh_id: int, original_visible: bool, owned_hide: bool) -> Dictionary:
	if not owned_hide: return {"restored": true, "reason": "no_owned_hide_remaining"}
	if not _original_draw_owned(stage, node, path, node_id, parent_id, mesh_id):
		return {"restored": false, "reason": "original_node_or_mesh_replaced_no_write"}
	if node.visible:
		return {"restored": original_visible, "reason": "external_visibility_change_preserved_no_write"}
	node.visible = original_visible
	return {"restored": true, "reason": "exact_original_visibility_restored", "value": original_visible}

func _binding_intact(stage: Node) -> bool:
	if not is_instance_valid(stage) or stage.get_instance_id() != _original_stage_id or stage.get_script() != _original_stage_script: return false
	if not _original_draw_owned(stage, _old_opaque, "PaintedForecourtOpaque", _original_opaque_id, _original_stage_id, _original_opaque_mesh_id): return false
	if not _original_draw_owned(stage, _old_shadow, "StaticSoftShadowLayer/BakedVolumeCastAndContact", _original_shadow_id, _original_shadow_parent_id, _original_shadow_mesh_id): return false
	var camera: Node = stage.get_node_or_null("Forecourt_18m_40degCamera")
	var light: Node = stage.get_node_or_null("SharedWarmKey")
	return is_instance_valid(camera) and camera.get_instance_id() == _original_camera_id and is_instance_valid(light) and light.get_instance_id() == _original_light_id

func _invalidate_binding(reason: String) -> void:
	visible = false
	var restoration: Dictionary = _restore_original_visibility()
	receipt["attached"] = false
	receipt["reason"] = reason
	receipt["restoration_complete"] = restoration.get("complete", false)
	set_process(false)

func _failed(reason: String) -> Dictionary:
	receipt = {"attached": false, "reason": reason, "native_verified": false, "art_accepted": false}
	return receipt.duplicate(true)

func _valid_mesh(data: Dictionary) -> bool:
	var vertices: Array = data.get("vertices", [])
	var normals: Array = data.get("normals", [])
	var colors: Array = data.get("colors", [])
	if vertices.is_empty() or vertices.size() % 3 != 0 or vertices.size() != normals.size() or vertices.size() != colors.size(): return false
	for index in range(vertices.size()):
		if not vertices[index] is Array or vertices[index].size() != 3 or not normals[index] is Array or normals[index].size() != 3 or not colors[index] is Array or colors[index].size() != 4: return false
		for component: Variant in vertices[index]:
			if not (component is float or component is int) or not is_finite(float(component)): return false
	return true

func _make_mesh(node_name: String, data: Dictionary, alpha: bool, groups: Array = []) -> MeshInstance3D:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for point: Array in data.vertices: vertices.append(Vector3(float(point[0]), float(point[1]), float(point[2])))
	for normal: Array in data.normals: normals.append(Vector3(float(normal[0]), float(normal[1]), float(normal[2])))
	for pigment: Array in data.colors: colors.append(Color(float(pigment[0]), float(pigment[1]), float(pigment[2]), float(pigment[3])))
	# Validate the entire selection before changing any copied color.
	if not alpha:
		var matched: Array[Dictionary] = []
		var names: Array[String] = []
		var skipped: Array[String] = []
		var errors: Array[String] = []
		var total := 0
		for value: Variant in groups:
			if not value is Dictionary:
				errors.append("invalid_group_record"); continue
			var group: Dictionary = value
			var group_name := str(group.get("name", ""))
			if group_name not in STONE_VALUE_GROUPS:
				skipped.append(group_name); continue
			var first := int(group.get("first_vertex", -1))
			var count := int(group.get("vertex_count", 0))
			if group_name in names:
				errors.append("duplicate_group:" + group_name); continue
			if first < 0 or count <= 0 or first % 3 != 0 or count % 3 != 0 or first + count > colors.size():
				errors.append("invalid_range:" + group_name); continue
			for prior: Dictionary in matched:
				if first < int(prior.first) + int(prior.count) and int(prior.first) < first + count:
					errors.append("overlapping_range:" + group_name)
			names.append(group_name)
			matched.append({"name":group_name,"first":first,"count":count})
			total += count
		var missing: Array[String] = []
		for expected: String in STONE_VALUE_GROUPS:
			if expected not in names: missing.append(expected)
		if not missing.is_empty(): errors.append("missing_expected_groups")
		if total != 14340: errors.append("expected_vertex_count_mismatch")
		var admitted := errors.is_empty() and matched.size() == 10
		_stone_value_receipt = {"status":"applied" if admitted else "not_applied_original_colors_retained", "matched_groups":matched, "matched_group_count":matched.size(), "matched_vertex_count":total, "applied_group_count":10 if admitted else 0, "applied_vertex_count":total if admitted else 0, "missing_groups":missing, "skipped_unselected_groups":skipped, "errors":errors, "native_verified":false}
		if admitted:
			for group: Dictionary in matched:
				for index in range(int(group.first), int(group.first) + int(group.count)):
					var up: float = absf(normals[index].y)
					var stone := Color("4D645F") # recessed/vertical stone
					if up >= 0.95: stone = Color("7A897D") # broad horizontal top
					elif up > 0.05: stone = Color("98A28A") # existing narrow bevel
					stone.a = colors[index].a
					colors[index] = stone
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	if not alpha: material.albedo_color = Color("adb6ab")
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 1.0
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if alpha:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.render_priority = -1
	var view := MeshInstance3D.new()
	view.name = node_name
	view.mesh = mesh
	view.material_override = material
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return view

func _make_floor(texture: Texture2D) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2(26.0, 26.0)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = texture
	material.albedo_color = Color("627d8e")
	# Four stones per original tile, 6.5 repeats over 26m: about 1m per stone.
	# UV/material drawing only. The generated PNG remains byte-for-byte intact.
	material.uv1_scale = Vector3(6.5, 6.5, 1.0)
	material.texture_repeat = true
	material.roughness = 1.0
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	var view := MeshInstance3D.new()
	view.name = "QuietPaintedFlagstoneCourt"
	view.mesh = plane
	view.material_override = material
	view.position.y = 0.0
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return view
