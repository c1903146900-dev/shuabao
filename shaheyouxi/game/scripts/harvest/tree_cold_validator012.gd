extends RefCounted
## Closed profile6 cold admission. Existing profiles4/5 retain their validators.
## No world restore, generation, inventory mutation or native-body publication.
const InventoryCold = preload("res://scripts/inventory/inventory_cold_validator012.gd")
const InventorySession = preload("res://scripts/inventory/inventory_world_session012.gd")
const TreeSession = preload("res://scripts/harvest/tree_world_session012.gd")
const Core = preload("res://scripts/inventory/inventory_core012.gd")
var ready := false
var _binding: RefCounted
var _terrain: RefCounted
var _authority: RefCounted
func _init(terrain: Variant, authority: Variant) -> void:
	_binding=InventoryCold.new(terrain,authority)
	if not _binding.ready: return
	_terrain=terrain
	_authority=authority
	ready=true
func binding_matches(terrain: Variant, authority: Variant) -> bool:
	return ready and _binding!=null and _binding.get_script()==InventoryCold and _terrain==terrain and _authority==authority and _binding.binding_matches(terrain,authority)
func validate_combined_state(value: Variant) -> Dictionary:
	if not binding_matches(_terrain,_authority): return _bad("TREE_COLD_BINDING_CHANGED")
	if not Core._fields(value,InventorySession.FIELDS+TreeSession.EXTRA_FIELDS) or value["tree_contract"]!=TreeSession.CONTRACT or not Core._world_id_valid(value["world_id"]) or not value["tree_component"] is Dictionary or not value["tree_component"].get("seed_decimal") is String: return _bad("TREE_COLD_CONTRACT_NO_MIGRATION")
	var core:=Core.new(value["world_id"],"v2_tree_seed")
	var inner:=InventorySession.new(_terrain,core,_authority,value["world_id"])
	var contract:=TreeSession.new(inner,_authority,value["tree_component"]["seed_decimal"])
	if not core.ready or not inner.ready or not contract.ready: return _bad("TREE_COLD_NOT_READY")
	return contract.validate_combined_state(value)
func validate_runtime_state(value: Variant) -> Dictionary:
	var checked:=validate_combined_state(value)
	if not checked.get("ok",false): return checked
	# Until an independently validated native H1 registry exists, refuse before
	# any real Owner/authority/world restoration. Valid data is never discarded.
	for tree in value["tree_component"]["trees"].values():
		if tree["status"]=="alive": return _bad("TREE_NATIVE_COLLISION_UNSUPPORTED")
	return {"ok":true}
static func _bad(code: String) -> Dictionary:
	return {"ok":false,"code":code,"recoverable_corruption":false}
