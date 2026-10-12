extends RefCounted
const Core = preload("res://scripts/inventory/inventory_core012.gd")
const State = preload("res://scripts/actor/actor_state.gd")
const Address = preload("res://scripts/world/spatial_address.gd")
const Live = preload("res://scripts/inventory/inventory_live012.gd")
static func validate(packet: Variant, identity: Dictionary, rules: Dictionary) -> bool:
	if not Core._fields(packet, ["schema_version", "contract", "identity", "view", "layer", "world_seconds", "ground"]) or typeof(packet["schema_version"]) != TYPE_INT or packet["schema_version"] != 1 or packet["contract"] != "inventory012-private-ground-sync-v1" or packet["identity"] != identity or not Live.identity_valid(identity): return false
	if not Address.valid_layer(packet["layer"]) or packet["layer"]["world_id"] != identity["world_id"] or not State.valid_clock(packet["world_seconds"]) or not packet["ground"] is Array or packet["ground"].size() > Core.MAX_GROUND or var_to_bytes(packet).size() > Core.MAX_BYTES: return false
	var ids: Dictionary = {}
	for record in packet["ground"]:
		if not Core._fields(record, ["id", "position", "content_id", "quantity"]) or not Core._id(record["id"]) or ids.has(record["id"]) or not State.valid_pair(record["position"]) or not record["content_id"] is String or not rules["item_rules"].has(record["content_id"]) or typeof(record["quantity"]) != TYPE_INT or record["quantity"] < 1 or record["quantity"] > rules["item_rules"][record["content_id"]]["max_stack"]: return false
		ids[record["id"]] = true
	return true
