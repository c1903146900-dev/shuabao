extends RefCounted
## Pure technical template expansion. No random source, file I/O or scene spawn.
const Validator = preload("res://scripts/prefab/prefab_validator.gd")
const Address = preload("res://scripts/world/spatial_address.gd")
var validator: RefCounted
var ready: bool = false
var instantiation_calls: int = 0

func _init(generation_document: Dictionary, prefab_document: Dictionary) -> void:
	validator = Validator.new(generation_document, prefab_document)
	ready = validator.ready

func instantiate(value: Variant, world_id: String, body_instance_id: String, prefab_instance_id: String, origin: Variant) -> Dictionary:
	var checked: Dictionary = validator.validate_template(value)
	if not checked["ok"]:
		return checked
	if not SandboxServerAuthority._valid_id(world_id, "world_") or not Address.is_body_instance_id(body_instance_id) or not Validator.valid_prefab_instance_id(prefab_instance_id) or not Validator._cell(origin):
		return Validator._bad("PREFAB_INSTANCE_IDENTITY_INVALID")
	var template: Dictionary = checked["template"]
	var canonical_origin: Array = Validator._integers(origin)
	instantiation_calls += 1
	var instance: Dictionary = {
		"schema_version": Validator.FORMAT_VERSION, "artifact_kind": Validator.INSTANCE_KIND,
		"template_id": template["template_id"], "template_revision": template["revision"],
		"template_sha256": Validator.template_digest(template), "source_template": template.duplicate(true),
		"world_id": world_id, "body_instance_id": body_instance_id, "body_content_id": template["body_content_id"],
		"prefab_instance_id": prefab_instance_id, "origin": canonical_origin,
		"sources": template["sources"].duplicate(true), "formal_world_allowed": false,
		"layers": [], "objects": [], "anchors": [], "connections": [], "protected_areas": []
	}
	var layers: Dictionary = {}
	var objects: Dictionary = {}
	var anchors: Dictionary = {}
	for source in template["layers"]:
		var row: Dictionary = source.duplicate(true)
		row["address"] = Address.layer(world_id, body_instance_id, source["map_kind"], int(source["depth"]))
		row["bounds"] = Validator.translated_rect(source["bounds"], canonical_origin)
		layers[source["local_id"]] = row["address"]
		instance["layers"].append(row)
	for source in template["objects"]:
		var row: Dictionary = source.duplicate(true)
		row["instance_id"] = Validator.runtime_id("entity", world_id, body_instance_id, prefab_instance_id, source["local_id"])
		row["layer"] = layers[source["layer_id"]].duplicate(true)
		row["rect"] = Validator.translated_rect(source["rect"], canonical_origin)
		objects[source["local_id"]] = row["instance_id"]
		instance["objects"].append(row)
	for source in template["anchors"]:
		var row: Dictionary = source.duplicate(true)
		row["instance_id"] = Validator.runtime_id("anchor", world_id, body_instance_id, prefab_instance_id, source["local_id"])
		row["object_instance_id"] = "" if source["object_local_id"] == "" else objects[source["object_local_id"]]
		row["layer"] = layers[source["layer_id"]].duplicate(true)
		row["cell"] = Validator.translated_cell(source["cell"], canonical_origin)
		anchors[source["local_id"]] = row
		instance["anchors"].append(row)
	for source in template["connections"]:
		var row: Dictionary = source.duplicate(true)
		row["instance_id"] = Validator.runtime_id("connection", world_id, body_instance_id, prefab_instance_id, source["local_id"])
		row["upper_anchor_instance_id"] = anchors[source["upper_anchor_id"]]["instance_id"]
		row["lower_anchor_instance_id"] = anchors[source["lower_anchor_id"]]["instance_id"]
		var cell: Array = anchors[source["upper_anchor_id"]]["cell"]
		row["body_rect"] = Validator.centered_rect(cell, int(source["body_side_cells"]))
		row["safety_rect"] = Validator.centered_rect(cell, int(source["safety_side_cells"]))
		instance["connections"].append(row)
	for source in template["protected_areas"]:
		var row: Dictionary = source.duplicate(true)
		row["layer"] = layers[source["layer_id"]].duplicate(true)
		row["rect"] = Validator.translated_rect(source["rect"], canonical_origin)
		instance["protected_areas"].append(row)
	return validator.validate_instance(instance, world_id)
