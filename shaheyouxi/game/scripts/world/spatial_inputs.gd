extends RefCounted
## Small typed view over current batch's verified source projection.
const Address = preload("res://scripts/world/spatial_address.gd")
var ready: bool = false
var data: Dictionary = {}
var last_error: String = ""

func load_file(path: String = "res://data/spatial_settings.json") -> bool:
	return load_document(JSON.parse_string(FileAccess.get_file_as_string(path)))

func load_document(document: Variant) -> bool:
	ready = false
	data = {}
	last_error = ""
	if not document is Dictionary or document.get("schema_version") != 1 or document.get("project") != "shaheyouxi_experiment_20261004" or document.get("artifact_kind") != "derived_authoritative_spatial_inputs":
		return _reject("空间数据身份或格式无效")
	var numeric: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/approved_source.json"))
	var assets: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/approved_asset_source.json"))
	var sources: Variant = document.get("sources")
	if not numeric is Dictionary or not assets is Dictionary or not sources is Dictionary:
		return _reject("缺少已核来源")
	if sources.get("shuzhi_sha256") != numeric.get("sha256") or sources.get("sucai_sha256") != assets.get("sha256"):
		return _reject("空间数据来源不匹配")
	var planes: Variant = document.get("planes")
	if not planes is Array or planes.size() != 4:
		return _reject("四高度平面缺失")
	for index in range(4):
		if not planes[index] is Dictionary or planes[index].get("id") != Address.PLANES[index]:
			return _reject("高度平面ID错误")
	var bodies: Variant = document.get("body_definitions")
	var start: Variant = document.get("starting_body")
	if not bodies is Dictionary or not start is Dictionary or start.get("body_id") != "xingxing_03" or start.get("biome_id") != "x03_db_wendai_linyuan" or not bodies.has(start["body_id"]):
		return _reject("首母星/区域引用错误")
	for body_id in bodies:
		if not body_id is String or not bodies[body_id] is Dictionary or bodies[body_id].get("body_id") != body_id or not bodies[body_id].get("raw_map_layers") is String:
			return _reject("天体定义结构错误")
	if not start.get("ground_resource_id") is String or start["ground_resource_id"].is_empty() or start.get("surface_depth") != 0 or not _integer_array_equals(start.get("underground_depths"), [1, 2]):
		return _reject("首母星层或地面引用无效")
	var parameters: Variant = document.get("parameters")
	if not parameters is Dictionary:
		return _reject("移动试验参数缺失")
	for key in ["movement_speed_cells_per_second", "actor_diameter_cells", "interaction_range_cells"]:
		var item: Variant = parameters.get(key)
		if not item is Dictionary or not _positive_number(item.get("value")) or not item.get("id") is String or not item.get("source_cell") is String:
			return _reject("移动试验参数无效")
	if float(parameters["actor_diameter_cells"]["value"]) < 0.2 or float(parameters["actor_diameter_cells"]["value"]) > 1.2 or float(parameters["movement_speed_cells_per_second"]["value"]) < 0.1 or float(parameters["movement_speed_cells_per_second"]["value"]) > 20.0 or float(parameters["interaction_range_cells"]["value"]) < 0.1 or float(parameters["interaction_range_cells"]["value"]) > 10.0:
		return _reject("参数超出本批受测实现范围，需另行验证")
	var definitions: Variant = document.get("object_definitions")
	if not definitions is Dictionary or definitions.size() != 3:
		return _reject("本批对象定义缺失")
	var catalogue := SandboxContentCatalogue.new()
	if catalogue.load_file() != OK:
		return _reject("正式ID目录不可用")
	for content_id in ["jianzhu_diban_00", "jianzhu_qiang_00", "gongzuotai_jichu"]:
		var item: Variant = definitions.get(content_id)
		if not item is Dictionary or item.get("content_id") != content_id or catalogue.get_content(content_id).is_empty() or not _positive_size(item.get("footprint_cells")):
			return _reject("对象ID或占格无效")
		var is_floor: bool = content_id == "jianzhu_diban_00"
		if item.get("plane") != ("H0_OVERLAY" if is_floor else "H1") or typeof(item.get("blocks_motion")) != TYPE_BOOL or item.get("blocks_motion") != (not is_floor):
			return _reject("对象高度/阻挡语义错误")
		if is_floor:
			if item.get("collision_rect_cells") != null:
				return _reject("零高度地板不产生H1碰撞")
		else:
			var shape: Variant = item.get("collision_rect_cells")
			if not shape is Dictionary or not _integer_array_equals(shape.get("offset"), [0, 0]) or not _integer_array_equals(shape.get("size"), item["footprint_cells"]):
				return _reject("本批实体碰撞须与正式占地一致")
	data = document.duplicate(true)
	ready = true
	return true

func parameter(key: String) -> float:
	return float(data["parameters"][key]["value"]) if ready and data["parameters"].has(key) else NAN

static func _positive_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) > 0.0

static func _positive_size(value: Variant) -> bool:
	return value is Array and value.size() == 2 and Address.is_integer(value[0]) and Address.is_integer(value[1]) and value[0] > 0 and value[1] > 0

func _reject(message: String) -> bool:
	last_error = message
	return false

static func _integer_array_equals(value: Variant, expected: Array) -> bool:
	# JSON numbers are floats; Array equality is type-strict in Godot4.6.
	if not value is Array or value.size() != expected.size():
		return false
	for index in range(expected.size()):
		if not Address.is_integer(value[index]) or not Address.is_integer(expected[index]) or int(value[index]) != int(expected[index]):
			return false
	return true
