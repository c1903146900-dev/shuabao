extends RefCounted
## Transactional technical editor document. GUI is a consumer, not an authority.
const Validator = preload("res://scripts/prefab/prefab_validator.gd")
const Factory = preload("res://scripts/prefab/prefab_instantiator.gd")
const Store = preload("res://scripts/prefab/prefab_store.gd")
const Templates = preload("res://scripts/prefab/technical_templates.gd")
const WORLD := "world_00900900900900900900900900900900"
const BOUNDS := [-8, -6, 17, 13] # Explicit editor fixture extent, not game balance.
var ready: bool = false
var template: Dictionary = {}
var preview: Dictionary = {}
var dirty: bool = false
var last_error: String = ""
var _validator: RefCounted
var _factory: RefCounted
var _store: RefCounted
var _generation: Dictionary
var _directory: String
var _saved_revision: String = ""
var _saved_template: Dictionary = {}
var _sequence: int = 0

func _init(generation: Dictionary, prefab: Dictionary, directory: String = "user://prefab_previews/editor009") -> void:
	_generation = generation.duplicate(true)
	_directory = directory.trim_suffix("/")
	_validator = Validator.new(generation, prefab)
	_factory = Factory.new(generation, prefab)
	_store = Store.new(generation, prefab, _directory)
	ready = _validator.ready and _store.ready
	if not ready:
		last_error = "EDITOR_INPUTS_NOT_READY"

func new_template(identity: String, discard_changes: bool = false) -> Dictionary:
	if not ready:
		return _error("EDITOR_INPUTS_NOT_READY")
	if dirty and not discard_changes:
		return _error("EDITOR_UNSAVED_CHANGES")
	if not Validator._token(identity) or not identity.begins_with("fixture_") or identity.length() <= 8:
		return _error("EDITOR_TEMPLATE_ID_INVALID")
	if identity in saved_template_ids():
		return _error("EDITOR_TEMPLATE_EXISTS_OPEN_INSTEAD")
	var candidate: Dictionary = Templates._base(identity, _generation["sources"])
	for depth in range(3):
		var layer_id: String = "layer_%d" % depth
		candidate["layers"].append(Templates._layer(layer_id, depth, BOUNDS.duplicate()))
		candidate["objects"].append(Templates._fixture("ground_%d" % depth, "fixture_ground", layer_id, "H0", BOUNDS.duplicate(), false))
	var checked: Dictionary = _validator.validate_template(candidate)
	if not checked["ok"]:
		return _forward(checked)
	template = checked["template"]
	preview = {}
	_saved_revision = ""
	_saved_template = {}
	_sequence = 0
	dirty = true
	last_error = ""
	return {"ok": true, "template": template, "formal_world_allowed": false}

func open_template(identity: String, discard_changes: bool = false) -> Dictionary:
	if dirty and not discard_changes:
		return _error("EDITOR_UNSAVED_CHANGES")
	var loaded: Dictionary = _store.load_template(identity)
	if not loaded.get("ok", false):
		return _forward(loaded)
	template = loaded["template"].duplicate(true)
	_saved_template = template.duplicate(true)
	_saved_revision = loaded["revision_sha256"]
	preview = {}
	dirty = false
	last_error = ""
	return {"ok": true, "template": template, "formal_world_allowed": false}

func save_template() -> Dictionary:
	if template.is_empty():
		return _error("EDITOR_NO_DOCUMENT")
	var checked: Dictionary = _validator.validate_template(template)
	if not checked["ok"]:
		return _forward(checked)
	var candidate: Dictionary = checked["template"]
	if not _saved_revision.is_empty() and candidate != _saved_template:
		candidate["revision"] = int(_saved_template["revision"]) + 1
	var saved: Dictionary = _store.save_template(candidate, _saved_revision)
	if not saved.get("ok", false):
		return _forward(saved)
	template = candidate
	_saved_template = candidate.duplicate(true)
	_saved_revision = saved["revision_sha256"]
	preview = {}
	dirty = false
	last_error = ""
	return saved

func validate_current() -> Dictionary:
	if template.is_empty():
		return _error("EDITOR_NO_DOCUMENT")
	var result: Dictionary = _validator.validate_template(template)
	if result["ok"]:
		last_error = ""
	return _forward(result) if not result["ok"] else result

func test_instance() -> Dictionary:
	if template.is_empty():
		return _error("EDITOR_NO_DOCUMENT")
	var result: Dictionary = _factory.instantiate(template, WORLD, "body_0001", "prefab_editor_preview", [30, 30])
	if not result.get("ok", false):
		preview = {}
		return _forward(result)
	preview = result["instance"].duplicate(true)
	last_error = ""
	return result

func place(tool: String, depth: Variant, cell: Array) -> Dictionary:
	if tool == "erase":
		return erase(depth, cell)
	if template.is_empty():
		return _error("EDITOR_NO_DOCUMENT")
	if not Validator._cell(cell):
		return _error("EDITOR_CELL_INVALID")
	if not Validator._cell([0, depth]):
		return _error("EDITOR_LAYER_INVALID")
	var candidate: Dictionary = template.duplicate(true)
	var layer_id: String = _layer_id(candidate, int(depth))
	if layer_id.is_empty():
		return _error("EDITOR_LAYER_INVALID")
	var canonical_cell: Array = Validator._integers(cell)
	if tool in ["wall", "floor", "container", "boss"]:
		var content_id: String = "fixture_" + tool
		var plane: String = "H0_OVERLAY" if tool == "floor" else "H1"
		for object in candidate["objects"]:
			if object["layer_id"] == layer_id and object["plane"] == plane and object["content_id"] == content_id and object["rect"] == [canonical_cell[0], canonical_cell[1], 1, 1]:
				return {"ok": true, "changed": false, "formal_world_allowed": false}
		var local_id: String = _new_id("object", candidate)
		candidate["objects"].append(Templates._fixture(local_id, content_id, layer_id, plane, [canonical_cell[0], canonical_cell[1], 1, 1], tool != "floor"))
		if tool in ["container", "boss"]:
			candidate["anchors"].append(Templates._anchor(_new_id("anchor", candidate), tool, layer_id, canonical_cell, local_id))
	elif tool == "spawn":
		var found: bool = false
		for anchor in candidate["anchors"]:
			if anchor["kind"] == "spawn" and anchor["layer_id"] == layer_id:
				anchor["cell"] = canonical_cell
				found = true
		if not found:
			candidate["anchors"].append(Templates._anchor(_new_id("spawn", candidate), "spawn", layer_id, canonical_cell))
	elif tool == "entry":
		var lower_id: String = _layer_id(candidate, int(depth) + 1)
		if lower_id.is_empty():
			return _error("EDITOR_NO_LOWER_LAYER")
		for existing in candidate["connections"]:
			for anchor in candidate["anchors"]:
				if anchor["local_id"] == existing["upper_anchor_id"] and anchor["layer_id"] == layer_id and anchor["cell"] == canonical_cell:
					return {"ok": true, "changed": false, "formal_world_allowed": false}
		var upper_anchor: String = _new_id("entrance", candidate)
		candidate["anchors"].append(Templates._anchor(upper_anchor, "entrance", layer_id, canonical_cell))
		var lower_anchor: String = _new_id("entrance", candidate)
		candidate["anchors"].append(Templates._anchor(lower_anchor, "entrance", lower_id, canonical_cell.duplicate()))
		var rule: Dictionary = {}
		for row in _generation["connections"]:
			if row["upper"]["depth"] == depth and row["lower"]["depth"] == depth + 1:
				rule = row
		if rule.is_empty() or not rule["natural_allowed"]:
			return _error("PREFAB_CONNECTION_LAYER_OR_MODE_FORBIDDEN")
		candidate["connections"].append({"local_id":_new_id("connection", candidate), "upper_anchor_id":upper_anchor, "lower_anchor_id":lower_anchor, "mode":"natural", "body_side_cells":int(rule["body_side_cells"]), "safety_side_cells":int(rule["safety_side_cells"])})
	else:
		return _error("EDITOR_TOOL_INVALID")
	return _commit_edit(candidate)

func erase(depth: Variant, cell: Array) -> Dictionary:
	if template.is_empty():
		return _error("EDITOR_NO_DOCUMENT")
	if not Validator._cell(cell):
		return _error("EDITOR_CELL_INVALID")
	if not Validator._cell([0, depth]):
		return _error("EDITOR_LAYER_INVALID")
	var candidate: Dictionary = template.duplicate(true)
	var layer_id: String = _layer_id(candidate, int(depth))
	if layer_id.is_empty():
		return _error("EDITOR_LAYER_INVALID")
	for plane in ["H1", "H0_OVERLAY", "H0_DECAL"]:
		for object in candidate["objects"].duplicate():
			if object["layer_id"] == layer_id and object["plane"] == plane and Validator._contains(object["rect"], cell):
				candidate["objects"].erase(object)
				for anchor in candidate["anchors"].duplicate():
					if anchor["object_local_id"] == object["local_id"]:
						candidate["anchors"].erase(anchor)
				return _commit_edit(candidate)
	for anchor in candidate["anchors"].duplicate():
		if anchor["layer_id"] != layer_id or anchor["cell"] != Validator._integers(cell):
			continue
		if anchor["kind"] == "entrance":
			for connection in candidate["connections"].duplicate():
				if anchor["local_id"] in [connection["upper_anchor_id"], connection["lower_anchor_id"]]:
					candidate["connections"].erase(connection)
					for paired in candidate["anchors"].duplicate():
						if paired["local_id"] in [connection["upper_anchor_id"], connection["lower_anchor_id"]]:
							candidate["anchors"].erase(paired)
		else:
			candidate["anchors"].erase(anchor)
		return _commit_edit(candidate)
	return {"ok": true, "changed": false, "formal_world_allowed": false}

func saved_template_ids() -> Array:
	var result: Array = []
	if not ready:
		return result
	var directory := DirAccess.open(_directory.path_join("templates"))
	if directory == null:
		return result
	for filename in directory.get_files():
		if filename.ends_with(".json") and Validator._token(filename.trim_suffix(".json")):
			result.append(filename.trim_suffix(".json"))
	result.sort()
	return result

func _commit_edit(candidate: Dictionary) -> Dictionary:
	var checked: Dictionary = _validator.validate_template(candidate)
	if not checked["ok"]:
		return _forward(checked)
	if checked["template"] == template:
		return {"ok": true, "changed": false, "formal_world_allowed": false}
	template = checked["template"]
	preview = {}
	dirty = true
	last_error = ""
	return {"ok": true, "changed": true, "template": template, "formal_world_allowed": false}

func _new_id(kind: String, candidate: Dictionary) -> String:
	var used: Dictionary = {}
	for group in ["layers", "objects", "anchors", "connections", "protected_areas"]:
		for row in candidate[group]:
			used[row["local_id"]] = true
	for _attempt in range(1024): # More than the complete bounded record set.
		_sequence += 1
		var value: String = "edit_%s_%d" % [kind, _sequence]
		if not used.has(value):
			return value
	return ""

static func _layer_id(document: Dictionary, depth: int) -> String:
	for layer in document["layers"]:
		if layer["depth"] == depth:
			return layer["local_id"]
	return ""

func _forward(result: Dictionary) -> Dictionary:
	last_error = str(result.get("code", "EDITOR_OPERATION_FAILED"))
	return result

func _error(code: String) -> Dictionary:
	last_error = code
	return {"ok": false, "code": code, "formal_world_allowed": false}

static func error_message(code: String) -> String:
	var messages: Dictionary = {
		"EDITOR_INPUTS_NOT_READY":"正式来源未就绪，禁止编辑", "EDITOR_UNSAVED_CHANGES":"有未保存修改，请先确认是否放弃", "EDITOR_TEMPLATE_ID_INVALID":"模板ID须为fixture_开头的英文小写、数字或下划线", "EDITOR_TEMPLATE_EXISTS_OPEN_INSTEAD":"同名模板已存在，请用打开", "EDITOR_NO_DOCUMENT":"请先新建或打开模板", "EDITOR_CELL_INVALID":"格子坐标无效", "EDITOR_LAYER_INVALID":"地图层不存在", "EDITOR_NO_LOWER_LAYER":"当前已是最深层，不能添加向下入口", "EDITOR_TOOL_INVALID":"未知工具", "PREFAB_OBJECT_OCCUPANCY_CONFLICT":"该高度面已有对象，请先擦除", "PREFAB_TRAVEL_ANCHOR_BLOCKED":"出生点或入口被对象覆盖", "PREFAB_CONNECTION_SAFETY_BLOCKED":"入口安全区不能覆盖实体或液体", "PREFAB_CONNECTION_SAFETY_OUT_OF_BOUNDS":"入口安全区超出模板边界", "PREFAB_CONNECTION_BODY_OVERLAP":"入口本体重叠", "PREFAB_OBJECT_GEOMETRY_OR_ID_INVALID":"对象超出边界或ID无效", "PREFAB_TEMPLATE_REVISION_CONFLICT":"磁盘模板已变化，请重新打开，未覆盖", "PREFAB_TEMPLATE_REVISION_SEQUENCE_INVALID":"模板版本不连续，未覆盖", "PREFAB_NOT_FOUND_NO_REGENERATION":"模板不存在，不会自动重建", "PREFAB_CHECKSUM_MISMATCH":"文件校验失败，拒绝读取", "PREFAB_JSON_INVALID":"文件内容损坏，拒绝读取"}
	return messages.get(code, "操作被拒绝：" + code)
