extends RefCounted
## Read-only geometry/identity seam for isolated trees. It cannot publish natural
## entities: the authoritative generation density/Biome mapping remains absent.
const Address = preload("res://scripts/world/spatial_address.gd")
const Codec = preload("res://scripts/save/exact_scalar_codec.gd")
const RULES_PATH := "res://data/tree_rules012.json"
const RULES_SHA256 := "1a4f86db21a2b939bef552df923c268d324269161f0e38f2af8b7d417896724c"
var ready := false
var _rules: Dictionary = {}
func _init() -> void:
	var text := FileAccess.get_file_as_string(RULES_PATH)
	if text.sha256_text() != RULES_SHA256: return
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary or parsed.get("contract") != "sandbox012-tree-authority-projection-v1" or parsed.get("runtime_published") != false: return
	_rules = parsed
	_freeze(_rules)
	ready = true
func natural_generation_readiness() -> Dictionary:
	if not ready: return _bad("TREE_RULES_INVALID")
	return {"ok":false,"code":"TREE_NATURAL_GENERATION_DESIGN_BLOCKED","missing":["planet_ids","biome_ids","density"]}
func inspect_fixture_site(layer: Variant, cell: Variant, entry_safety_rectangles: Variant, protected_rectangles: Variant) -> Dictionary:
	# Rectangles come from the explicit fixture's validated layout, not a client
	# boolean claiming permission. This result is geometry, not spawn authority.
	if not ready or not Address.valid_layer(layer) or layer["reference_frame"] != "celestial_local" or layer["map_kind"] != "surface" or layer["depth"] != 0 or not _cell(cell): return _bad("TREE_FIXTURE_LAYER_OR_CELL_INVALID")
	if not entry_safety_rectangles is Array or not protected_rectangles is Array: return _bad("TREE_FIXTURE_REGIONS_INVALID")
	for region_index in range(2):
		var regions: Array = entry_safety_rectangles if region_index == 0 else protected_rectangles
		for rectangle in regions:
			if not rectangle is Dictionary or rectangle.size()!=2 or not rectangle.has("origin") or not rectangle.has("size") or not _cell(rectangle["origin"]) or not _cell(rectangle["size"]) or rectangle["size"][0] <= 0 or rectangle["size"][1] <= 0: return _bad("TREE_FIXTURE_REGIONS_INVALID")
			if region_index == 0 and rectangle["size"] != [int(_rules["entry_safety_square_side_cells"]),int(_rules["entry_safety_square_side_cells"])]: return _bad("TREE_FIXTURE_ENTRY_SAFETY_SIZE")
			var right: int = rectangle["origin"][0] + rectangle["size"][0]
			var bottom: int = rectangle["origin"][1] + rectangle["size"][1]
			if cell[0] >= rectangle["origin"][0] and cell[0] < right and cell[1] >= rectangle["origin"][1] and cell[1] < bottom: return _bad("TREE_FIXTURE_PROTECTED_CELL")
	var anchor := Vector2(float(cell[0])+0.5,float(cell[1])+0.5)
	var offset: Array = _rules["collision"]["center_offset_cells"]
	var size: Array = _rules["collision"]["size_cells"]
	var dimensions := Vector2(size[0],size[1])
	var rect := Rect2(anchor+Vector2(offset[0],offset[1])-dimensions/2.0,dimensions)
	return {"ok":true,"fixture_only":true,"spawn_authorized":false,"logical_cell":cell.duplicate(),"anchor":[anchor.x,anchor.y],"height_class":"H1","collision_rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y]}
func fixture_instance_id(world_seed: Variant, layer: Variant, cell: Variant) -> Dictionary:
	# The saved integer seed is supplied once; this never obtains fresh entropy.
	if not ready or typeof(world_seed)!=TYPE_INT or not Address.valid_layer(layer) or not _cell(cell): return _bad("TREE_FIXTURE_IDENTITY_INVALID")
	var canonical_layer: Dictionary = Address.layer(layer["world_id"],layer["body_instance_id"],layer["map_kind"],int(layer["depth"]))
	var encoded: Dictionary = Codec.encode(["tree-instance-v1",world_seed,canonical_layer,"tree_putong",cell])
	if not encoded.get("ok",false): return encoded
	return {"ok":true,"fixture_only":true,"instance_id":"entity_tree_"+JSON.stringify(encoded["value"],"",true,true).sha256_text().substr(0,32)}
static func _cell(value: Variant) -> bool:
	if not value is Array or value.size()!=2: return false
	for axis in value:
		if typeof(axis)!=TYPE_INT or axis < -2147483647 or axis > 2147483647: return false
	return true
static func _bad(code: String) -> Dictionary:
	return {"ok":false,"code":code}

static func _freeze(value: Variant) -> void:
	if value is Dictionary:
		for key in value: _freeze(value[key])
		value.make_read_only()
	elif value is Array:
		for item in value: _freeze(item)
		value.make_read_only()
