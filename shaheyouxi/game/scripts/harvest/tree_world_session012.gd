extends RefCounted
## Closed profile6 fixture candidate. No registry installation, migration or live
## publication. Old inventory/terrain complete validation still runs in full.
const InventorySession = preload("res://scripts/inventory/inventory_world_session012.gd")
const Ledger = preload("res://scripts/harvest/tree_ledger012.gd")
const Definition = preload("res://scripts/harvest/tree_definition012.gd")
const Core = preload("res://scripts/inventory/inventory_core012.gd")
const SaveStore = preload("res://scripts/save/save_store.gd")
const BoundedStore = preload("res://scripts/inventory/inventory_world_save_store012.gd")
const Authority = preload("res://scripts/network/server_authority.gd")
const Address = preload("res://scripts/world/spatial_address.gd")
const CONTRACT := "sandbox012-world-tree-fixture-v1"
const PROFILE := 6
const MAX_BYTES := 4194304
const EXTRA_FIELDS := ["tree_contract","tree_component"]
var ready := false
var _inner: RefCounted
var _ledger: RefCounted
var _authority: RefCounted
var _budget_store: RefCounted
var _budget_identity: RefCounted
var _inner_inventory: RefCounted
var _inner_terrain: RefCounted
var _inventory_rules_token := ""
var _inventory_rules_identity := ""
var _inventory_tree_rules := false
var _world_id := ""
var _seed_decimal := ""
var _content_revision := ""
var _protocol := 0
func _init(inner: Variant, authority: Variant, seed_decimal: String) -> void:
	if not inner is RefCounted or inner.get_script()!=InventorySession or not inner.ready or not authority is RefCounted or authority.get_script()!=Authority: return
	var ledger := Ledger.new(inner._world_id,seed_decimal)
	if not ledger.ready or inner._content_revision!=authority.catalogue_hash or inner._protocol!=authority.protocol_version: return
	_inner=inner
	_inner_inventory=inner._inventory
	_inner_terrain=inner._terrain
	_inventory_rules_token=Core._exact(inner._inventory._rules)
	_inventory_rules_identity=inner._inventory._rules_identity
	_inventory_tree_rules=inner._inventory._tree_rules
	_ledger=ledger
	_authority=authority
	_world_id=inner._world_id
	_seed_decimal=seed_decimal
	_content_revision=authority.catalogue_hash
	_protocol=authority.protocol_version
	_budget_store=SaveStore.new("",1,1,_content_revision,_protocol,Callable(),PROFILE,MAX_BYTES,true)
	_budget_identity=_budget_store
	ready=true
func combine(inventory_state: Dictionary, tree_state: Variant) -> Dictionary:
	if not Core._fields(inventory_state,InventorySession.FIELDS): return _bad("TREE_INNER_CONTRACT_NO_MIGRATION")
	var candidate: Dictionary=inventory_state.duplicate(true)
	candidate["tree_contract"]=CONTRACT
	candidate["tree_component"]=tree_state.duplicate(true) if tree_state is Dictionary else tree_state
	var checked:=validate_combined_state(candidate)
	return {"ok":true,"state":candidate,"fixture_only":true} if checked["ok"] else checked
func validate_combined_state(value: Variant) -> Dictionary:
	if not _binding_valid(): return _bad("TREE_SESSION_BINDING_CHANGED")
	var fields: Array=InventorySession.FIELDS.duplicate()
	fields.append_array(EXTRA_FIELDS)
	if not Core._fields(value,fields) or value["tree_contract"]!=CONTRACT: return _bad("TREE_WORLD_CONTRACT_NO_MIGRATION")
	var checked: Dictionary=_ledger.validate_snapshot(value["tree_component"])
	if not checked.get("ok",false): return _closed(checked)
	# Original full schema5 validation is not replaced by a hash or cached proof.
	checked=_inner.validate_combined_state(inventory_state(value))
	if not checked.get("ok",false): return _closed(checked)
	checked=_validate_tree_dynamic_state(value)
	if not checked.get("ok",false): return checked
	# Full NEW profile envelope, with actual tree data and worst allowed metadata.
	var text: String=_budget_store._encode(value,Core.MAX_SEQUENCE,"manual","W".repeat(BoundedStore.MAX_REASON),63)
	if text.is_empty() or text.to_utf8_buffer().size()>MAX_BYTES: return _bad("TREE_WORLD_FINAL_ENVELOPE_TOO_LARGE")
	return {"ok":true,"fixture_only":true}
# Internal semantic slice only. Production callers must already have valid
# binding, closed combined shape, Core and Ledger validation, and a current valid
# static-world proof (the full entry supplies original complete inner5).
# This helper grants neither admission nor publication authority; its existence
# never permits callers to bypass complete validation or either envelope budget.
func _validate_tree_dynamic_state(value: Dictionary) -> Dictionary:
	var world: Dictionary=value["world_component"]
	if value["world_id"]!=_world_id or world["layout"]["seed_decimal"]!=_seed_decimal: return _bad("TREE_WORLD_SEED_BINDING")
	for id in value["tree_component"]["trees"]:
		var tree: Dictionary=value["tree_component"]["trees"][id]
		var radius: float=float(world["layout"]["body"]["radius_cells"])
		var center:=Vector2(float(tree["cell"][0])+0.5,float(tree["cell"][1])+0.5)
		if center.length_squared()>radius*radius: return _bad("TREE_OUTSIDE_WORLD_BODY")
		var regions: Dictionary=regions_for_layer(world,tree["layer"])
		var site: Dictionary=_ledger._definition.inspect_fixture_site(tree["layer"],tree["cell"],regions["entries"],regions["protected"])
		if not site.get("ok",false): return _closed(site)
		# A canonical address alone cannot grant admission to another body.
		if tree["layer"]["body_instance_id"]!=world["layout"]["spawn"]["layer"]["body_instance_id"]: return _bad("TREE_BODY_NOT_MATERIALIZED")
	for event in value["tree_component"]["completions"]:
		var completion: Dictionary=value["tree_component"]["completions"][event]
		if not value["profiles"].has(completion["profile_id"]) or completion["completed_world_seconds"]>value["world_seconds"]: return _bad("TREE_COMPLETION_AUTHORITY_CONTEXT")
	var cohorts: Dictionary={}
	for drop in value["inventory_component"].get("ground",{}).values():
		for lot in drop["lots"]:
			if lot.get("source_kind","")!="natural_harvest": continue
			var event: String=lot["completion_id"]
			if not value["tree_component"]["completions"].has(event): return _bad("TREE_GROUND_COMPLETION_MISSING")
			var completion: Dictionary=value["tree_component"]["completions"][event]
			var tree: Dictionary=value["tree_component"]["trees"][completion["tree_id"]]
			if Address.key(tree["layer"])!=Address.key(drop["layer"]): return _bad("TREE_GROUND_SOURCE_LAYER")
			var elapsed: float=value["world_seconds"]-completion["completed_world_seconds"]
			if absf(lot["remaining_lifetime"]-maxf(0.0,300.0-elapsed))>0.000001 or absf(lot["remaining_delay"]-maxf(0.0,0.5-elapsed))>0.000001: return _bad("TREE_GROUND_SOURCE_TIMER_MISMATCH")
			var content: String=drop["stack"]["content_id"]
			var maximum: int=0
			for output in completion["outputs"]:
				if output["content_id"]==content: maximum=output["quantity"]
			var cohort:=event+"/"+content
			cohorts[cohort]=cohorts.get(cohort,0)+lot["quantity"]
			if maximum==0 or cohorts[cohort]>maximum: return _bad("TREE_GROUND_OUTPUT_DUPLICATED")
	return {"ok":true,"fixture_only":true}
func make_store(path: String, automatic_slots: int, manual_slots: int) -> RefCounted:
	if not _binding_valid() or path.is_empty() or automatic_slots<1 or automatic_slots>64 or manual_slots<1 or manual_slots>63: return null
	return BoundedStore.new(path,automatic_slots,manual_slots,_content_revision,_protocol,validate_combined_state,PROFILE,MAX_BYTES,true)
func _binding_valid() -> bool:
	return ready and _inner!=null and _inner.get_script()==InventorySession and _inner.ready and _inner._inventory==_inner_inventory and _inner._terrain==_inner_terrain and _inner_inventory._rules_identity==_inventory_rules_identity and _inner_inventory._tree_rules==_inventory_tree_rules and Core._exact(_inner_inventory._rules)==_inventory_rules_token and _inner._world_id==_world_id and _inner._content_revision==_content_revision and _inner._protocol==_protocol and _ledger!=null and _ledger.get_script()==Ledger and _ledger.ready and _ledger._world_id==_world_id and str(_ledger._seed)==_seed_decimal and _authority!=null and _authority.get_script()==Authority and _authority.catalogue_hash==_content_revision and _authority.protocol_version==_protocol and _budget_store!=null and _budget_store==_budget_identity and _budget_store.get_script()==SaveStore and _budget_store._schema_version==PROFILE and _budget_store._maximum_bytes==MAX_BYTES and _budget_store._exact_scalars and _budget_store._content_revision==_content_revision and _budget_store._network_protocol_version==_protocol
static func inventory_state(value: Dictionary) -> Dictionary:
	var result:=value.duplicate(true)
	for field in EXTRA_FIELDS: result.erase(field)
	return result
static func regions_for_layer(world: Dictionary, layer: Dictionary) -> Dictionary:
	# Only call after original complete-world validation. This is a projection of
	# real layout/prefab reservations, never caller-supplied empty permission.
	var entries: Array=[]
	var protected: Array=[]
	for connection in world["layout"]["connections"]:
		for endpoint in connection["endpoints"]:
			if Address.key(endpoint["layer"])==Address.key(layer): entries.append(_rectangle(connection["safety_rect"]))
	for prefab in world["prefab_instances"]:
		for region in prefab["protected_areas"]:
			if Address.key(region["layer"])==Address.key(layer): protected.append(_rectangle(region["rect"]))
		# Prefab connections have local layer IDs but their anchors carry validated
		# canonical layers. Protect either matching endpoint's same safety box.
		for connection in prefab["connections"]:
			for anchor in prefab["anchors"]:
				if anchor["instance_id"] in [connection["upper_anchor_instance_id"],connection["lower_anchor_instance_id"]] and Address.key(anchor["layer"])==Address.key(layer):
					entries.append(_rectangle(connection["safety_rect"]))
	return {"entries":entries,"protected":protected}
static func _rectangle(rectangle: Array) -> Dictionary:
	return {"origin":[int(rectangle[0]),int(rectangle[1])],"size":[int(rectangle[2]),int(rectangle[3])]}
static func _closed(value: Dictionary) -> Dictionary:
	var result:=value.duplicate(true)
	result["ok"]=false
	result["recoverable_corruption"]=false
	return result
static func _bad(code: String) -> Dictionary:
	return {"ok":false,"code":code,"recoverable_corruption":false}
