extends RefCounted
## No cache and no reduced validator. This removes only the duplicate successful
## inner admission when the entire synchronous validator graph is the original.
## Empty result requests the original path, including its error precedence.
const Combined = preload("res://scripts/inventory/inventory_world_session012.gd")
const TreeSession = preload("res://scripts/harvest/tree_world_session012.gd")
const Ledger = preload("res://scripts/harvest/tree_ledger012.gd")
const Definition = preload("res://scripts/harvest/tree_definition012.gd")
const Core = preload("res://scripts/inventory/inventory_core012.gd")
const Terrain = preload("res://scripts/actor/actor_terrain_session_state.gd")
const Legacy = preload("res://scripts/actor/actor_session_state.gd")
const World = preload("res://scripts/world_session/world_component.gd")
const TerrainStore = preload("res://scripts/terrain/combined_terrain_store.gd")
const Entry = preload("res://scripts/terrain/required_entry_terrain_store.gd")
const Surface = preload("res://scripts/terrain/surface_approach_store.gd")
const SurfaceRules = preload("res://scripts/terrain/surface_approach_rules.gd")
const Layout = preload("res://scripts/worldgen/layout_validator.gd")
const Prefab = preload("res://scripts/prefab/prefab_validator.gd")
const Inputs = preload("res://scripts/worldgen/generation_inputs.gd")
const Store = preload("res://scripts/save/save_store.gd")

static func try_combine(inner: Variant, outer: Variant, base: Dictionary, inventory: Dictionary, trees: Dictionary) -> Dictionary:
	if not standard_graph(inner,outer) or not Core._fields(base,Terrain.FIELDS) or not data_only([base,inventory,trees]): return {}
	# Exactly InventorySession.combine's insertion/deep-copy order. The full
	# TreeSession validator still invokes the original full inner validator.
	var candidate: Dictionary=base.duplicate(true)
	candidate["inventory_contract"]=Combined.CONTRACT
	candidate["inventory_component"]=inventory.duplicate(true)
	var result: Dictionary=outer.combine(candidate,trees)
	return result if result.get("ok",false) else {}

static func standard_graph(inner: Variant, outer: Variant) -> bool:
	if not _script(inner,Combined) or not _script(outer,TreeSession) or not is_same(inner,outer._inner): return false
	if not _script(outer._authority,Combined.Authority): return false
	if not _script(outer._ledger,Ledger) or not _script(outer._ledger._definition,Definition) or not outer._ledger._definition.ready: return false
	if not _script(inner._inventory,Core) or not _script(inner._terrain,Terrain): return false
	var terrain: RefCounted=inner._terrain
	if not _script(terrain._legacy,Legacy) or not _script(terrain._terrain_store,TerrainStore): return false
	var world: Variant=terrain._legacy._world
	if not _script(world,World) or not _validators(world._layout_validator,world._prefab_validator): return false
	var stores: RefCounted=terrain._terrain_store
	if not _entry(stores._entry_store) or not _script(stores._surface_store,Surface): return false
	if not _entry(stores._surface_store._base) or not _script(stores._surface_store._rules,SurfaceRules): return false
	# An exact script can still hold a replaced configuration containing an
	# Object with _get callbacks. Such graphs must keep the old call order.
	var configs: Array=[outer._ledger._definition._rules,inner._inventory._rules,terrain._legacy._actor_document,world._generation,world._template,stores._initial_input_digests,stores._surface_store._rules.settings,stores._surface_store._rules.generation,stores._surface_store._rules._initial_input_digests]
	for entry in [stores._entry_store,stores._surface_store._base]:
		configs.append_array([entry._generation,entry._prefab,entry._bundle])
	for validators in [[world._layout_validator,world._prefab_validator],[stores._entry_store._layout_validator,stores._entry_store._prefab_validator],[stores._surface_store._base._layout_validator,stores._surface_store._base._prefab_validator]]:
		configs.append_array([validators[0]._inputs.data,validators[1]._generation.data,validators[1]._prefab])
	if not data_only(configs): return false
	var budget: Variant=inner._budget_store
	if not _script(budget,Store): return false
	return budget._schema_version==Combined.SCHEMA and budget._maximum_bytes==Combined.MAX_BYTES and budget._exact_scalars and budget._content_revision==inner._content_revision and budget._network_protocol_version==inner._protocol

static func _entry(value: Variant) -> bool:
	return _script(value,Entry) and _validators(value._layout_validator,value._prefab_validator)

static func _validators(layout: Variant, prefab: Variant) -> bool:
	return _script(layout,Layout) and _script(prefab,Prefab) and _script(layout._inputs,Inputs) and _script(prefab._generation,Inputs)

static func _script(value: Variant, expected: Script) -> bool:
	return value is RefCounted and value.get_script()==expected

static func data_only(value: Variant) -> bool:
	return _data_only(value,0,[0])

static func _data_only(value: Variant, depth: int, count: Array) -> bool:
	count[0]+=1
	if depth>64 or count[0]>100000: return false
	match typeof(value):
		TYPE_NIL,TYPE_BOOL,TYPE_INT,TYPE_FLOAT,TYPE_STRING:
			return true
		TYPE_ARRAY:
			for item in value:
				if not _data_only(item,depth+1,count): return false
			return true
		TYPE_DICTIONARY:
			for key in value:
				if typeof(key)!=TYPE_STRING or not _data_only(value[key],depth+1,count): return false
			return true
	return false
