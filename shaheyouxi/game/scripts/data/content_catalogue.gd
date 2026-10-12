class_name SandboxContentCatalogue
extends RefCounted
## Derived from verified shuzhi.xlsx. Registration does not unlock gameplay.

var _content: Dictionary = {}
var _player_index: Dictionary = {}
var _enum_descriptors: Array = []
var source_sha256: String = ""
var last_error: String = ""
var ready: bool = false

func load_file(path: String = "res://data/catalogue.json") -> Error:
	_clear()
	if not FileAccess.file_exists(path):
		return _reject("正式数据文件不存在", ERR_FILE_NOT_FOUND)
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return _reject("正式数据JSON无法解析", ERR_PARSE_ERROR)
	return load_document(parser.data)

func load_document(document: Variant) -> Error:
	_clear()
	if not document is Dictionary:
		return _reject("正式数据必须是对象")
	if document.get("schema_version") != 1 or document.get("project") != "shaheyouxi_experiment_20261004":
		return _reject("正式数据版本或项目身份不匹配")
	if document.get("artifact_kind") != "derived_authoritative_catalogue":
		return _reject("测试数据或未登记产物不能用于正式目录")
	var source: Variant = document.get("source")
	var catalogue: Variant = document.get("catalogue")
	if not source is Dictionary or not catalogue is Dictionary:
		return _reject("缺少来源或数据目录")
	var approved: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/approved_source.json"))
	if not approved is Dictionary or not _required_texts(approved, ["name", "library_file_id", "file_id", "sha256"]):
		return _reject("本包缺少已核准的来源身份")
	for key in ["name", "library_file_id", "file_id", "sha256"]:
		if source.get(key) != approved[key]:
			return _reject("数据来源与本包已核准身份不匹配")
	var digest: String = source["sha256"]
	if digest.length() != 64 or not digest.is_valid_hex_number(false):
		return _reject("来源哈希无效")
	var content: Variant = catalogue.get("content_by_id")
	var index: Variant = catalogue.get("player_index_by_id")
	var enums: Variant = catalogue.get("enum_descriptors")
	var categories: Variant = catalogue.get("player_categories")
	if not content is Dictionary or not index is Dictionary or not enums is Array or not categories is Array:
		return _reject("目录字段类型不正确")
	if content.is_empty() or index.is_empty() or enums.is_empty() or categories.is_empty():
		return _reject("正式基础目录不允许为空")
	var enum_keys: Dictionary = {}
	for row in enums:
		if not row is Dictionary or not _required_texts(row, ["group", "value", "meaning", "notes"]):
			return _reject("枚举描述缺少必填文字")
		var key := JSON.stringify([row["group"], row["value"]])
		if enum_keys.has(key):
			return _reject("枚举描述复合键重复")
		enum_keys[key] = true
	var category_by_id: Dictionary = {}
	for row in categories:
		if not row is Dictionary or not _required_texts(row, ["major_category", "subcategory", "description"]):
			return _reject("分类记录缺少必填文字")
		if not _is_integer(row.get("subcategory_id")):
			return _reject("分类编号必须是整数")
		var category_id: int = int(row["subcategory_id"])
		if category_by_id.has(category_id):
			return _reject("分类编号重复")
		category_by_id[category_id] = row
	var expected_index: Dictionary = {}
	for content_id in content:
		if not content_id is String or content_id.is_empty() or content_id != content_id.strip_edges():
			return _reject("正式ID格式错误")
		var row: Variant = content[content_id]
		if not row is Dictionary or not _required_texts(row, ["name", "category", "system", "status", "index_status"]):
			return _reject("正式ID缺少必填文字字段")
		if row.get("id") != content_id:
			return _reject("正式ID键与记录不一致")
		if row.get("subcategory_id") != null and not _is_integer(row["subcategory_id"]):
			return _reject("正式ID的小类编号类型错误")
		for key in ["major_category", "subcategory", "acquisition_source"]:
			if row.get(key) != null and not row[key] is String:
				return _reject("正式ID可空文字字段类型错误")
		if row["index_status"] == "纳入玩家索引":
			expected_index[content_id] = true
	for content_id in index:
		var row: Variant = index[content_id]
		if not row is Dictionary or row.get("id") != content_id:
			return _reject("玩家索引记录格式不正确")
		if not _required_texts(row, ["name", "category", "system", "status", "major_category", "subcategory", "index_object_type"]):
			return _reject("玩家索引缺少必填文字字段")
		if row.get("acquisition_source") != null and not row["acquisition_source"] is String:
			return _reject("玩家索引可空来源文字类型错误")
		if not content.has(content_id) or not expected_index.has(content_id):
			return _reject("玩家索引引用缺失或内容不应进入玩家索引")
		if not _is_integer(row.get("subcategory_id")) or not category_by_id.has(int(row["subcategory_id"])):
			return _reject("玩家索引分类引用缺失")
		for key in ["name", "category", "system", "status", "major_category", "subcategory_id", "subcategory"]:
			if row[key] != content[content_id].get(key):
				return _reject("玩家索引与正式ID投影不一致")
		for key in ["major_category", "subcategory"]:
			if row[key] != category_by_id[int(row["subcategory_id"])][key]:
				return _reject("玩家索引与分类投影不一致")
	if index.size() != expected_index.size():
		return _reject("玩家索引集合不完整")
	_content = content.duplicate(true)
	_player_index = index.duplicate(true)
	_enum_descriptors = enums.duplicate(true)
	source_sha256 = digest
	ready = true
	return OK

func content_count() -> int:
	return _content.size() if ready else 0

func player_index_count() -> int:
	return _player_index.size() if ready else 0

func get_content(content_id: String) -> Dictionary:
	return _content.get(content_id, {}).duplicate(true) if ready else {}

func get_player_index(content_id: String) -> Dictionary:
	return _player_index.get(content_id, {}).duplicate(true) if ready else {}

func enum_descriptors() -> Array:
	# Semantic descriptions, not automatically generated executable enum tokens.
	return _enum_descriptors.duplicate(true) if ready else []

func _required_texts(row: Dictionary, fields: Array) -> bool:
	for key in fields:
		if not row.get(key) is String or row[key].strip_edges().is_empty():
			return false
	return true

func _is_integer(value: Variant) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	return is_finite(float(value)) and float(value) == floor(float(value))

func _clear() -> void:
	ready = false
	_content.clear()
	_player_index.clear()
	_enum_descriptors.clear()
	source_sha256 = ""
	last_error = ""

func _reject(message: String, error: Error = ERR_INVALID_DATA) -> Error:
	last_error = message
	return error
