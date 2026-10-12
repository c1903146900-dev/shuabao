extends RefCounted
## Non-publishing isolated tree ledger. Plans never mutate the live root; a future
## closed TreeSession/Frame owner must publish tree+ground candidates together.
const Definition = preload("res://scripts/harvest/tree_definition012.gd")
const Seed = preload("res://scripts/worldgen/world_seed.gd")
const Address = preload("res://scripts/world/spatial_address.gd")
const Codec = preload("res://scripts/save/exact_scalar_codec.gd")
const Authority = preload("res://scripts/network/server_authority.gd")
const CONTRACT := "sandbox012-isolated-tree-ledger-v1"
const MAX_TREES := 512 # Finite fixture bound, not a natural population parameter.
const MAX_REVISION := 9007199254740991
const FIELDS := ["schema_version","contract","world_id","seed_decimal","revision","fixture_only","trees","completions"]
var ready := false
var _definition: RefCounted
var _world_id := ""
var _seed: int = 0
var _state: Dictionary = {}
func _init(world_id: String, seed_decimal: String) -> void:
	var checked: Dictionary = Seed.from_decimal(seed_decimal)
	if not Authority._valid_id(world_id,"world_") or not checked.get("ok",false): return
	_definition = Definition.new()
	if not _definition.ready: return
	_world_id = world_id
	_seed = checked["value"]
	_state = {"schema_version":1,"contract":CONTRACT,"world_id":world_id,"seed_decimal":seed_decimal,"revision":0,"fixture_only":true,"trees":{},"completions":{}}
	ready = true
func snapshot() -> Dictionary:
	return _state.duplicate(true) if ready else {}
func token() -> String:
	return exact_token(_state) if ready else ""
func plan_fixture_tree(layer: Dictionary, cell: Array, entry_rectangles: Array, protected_rectangles: Array, expected_token: String) -> Dictionary:
	if not ready or token()!=expected_token or layer.get("world_id")!=_world_id: return _bad("TREE_FIXTURE_STALE_OR_SCOPE")
	var site: Dictionary = _definition.inspect_fixture_site(layer,cell,entry_rectangles,protected_rectangles)
	if not site.get("ok",false): return site
	var identity: Dictionary = _definition.fixture_instance_id(_seed,layer,cell)
	if not identity.get("ok",false): return identity
	var id: String = identity["instance_id"]
	if _state["trees"].has(id) or _state["trees"].size()>=MAX_TREES or _state["revision"]>=MAX_REVISION: return _bad("TREE_FIXTURE_DUPLICATE_OR_CAPACITY")
	var candidate := snapshot()
	candidate["trees"][id] = {"content_id":"tree_putong","layer":Address.layer(_world_id,layer["body_instance_id"],"surface",0),"cell":cell.duplicate(),"stage":"mature","status":"alive","completion_id":null}
	candidate["revision"] += 1
	return _plan(candidate,expected_token,{"tree_id":id,"outputs":[],"replay":false})
func plan_completion(tree_id: String, completion_id: String, profile_id: String, now: float, expected_token: String) -> Dictionary:
	if not ready or expected_token!=token() or not is_finite(now) or now<0.0 or not Authority._valid_id(profile_id,"player_"): return _bad("TREE_COMPLETION_STALE_OR_CONTEXT")
	if not _state["trees"].has(tree_id) or completion_id!=completion_identity(tree_id): return _bad("TREE_COMPLETION_IDENTITY")
	if _state["completions"].has(completion_id):
		var prior: Dictionary = _state["completions"][completion_id]
		if prior["tree_id"]!=tree_id or prior["profile_id"]!=profile_id: return _bad("TREE_COMPLETION_REPLAY_PARAMETERS")
		return _plan(snapshot(),expected_token,{"tree_id":tree_id,"completion_id":completion_id,"outputs":prior["outputs"].duplicate(true),"replay":true,"must_not_create_drops":true})
	if _state["trees"][tree_id]["status"]!="alive" or _state["revision"]>=MAX_REVISION: return _bad("TREE_ALREADY_FELLED_OR_CAPACITY")
	var candidate := snapshot()
	var outputs: Array = outcomes(tree_id,completion_id)
	if outputs.is_empty(): return _bad("TREE_OUTCOME_UNAVAILABLE")
	candidate["trees"][tree_id]["status"] = "felled"
	candidate["trees"][tree_id]["completion_id"] = completion_id
	candidate["completions"][completion_id] = {"tree_id":tree_id,"profile_id":profile_id,"completed_world_seconds":now,"outputs":outputs,"outcome_algorithm":"sha256_rejection_v1"}
	candidate["revision"] += 1
	return _plan(candidate,expected_token,{"tree_id":tree_id,"completion_id":completion_id,"outputs":outputs.duplicate(true),"replay":false,"must_not_create_drops":false})
func outcomes(tree_id: String, completion_id: String) -> Array:
	if not ready or _definition == null or not _definition.ready or tree_id.is_empty() or completion_id!=completion_identity(tree_id): return []
	# Engineering RNG domain only; quantities come from the locked projection.
	# Choice is stable under retry/order; completed values are also persisted.
	var domain := exact_token(["tree-outcomes-v1",_seed,_world_id,tree_id,completion_id])
	var wood: Array = _definition._rules["harvest"]["wood_quantity_range"]
	var seed: Array = _definition._rules["harvest"]["mature_seed_quantity_range"]
	var wood_count: int = _bounded_roll(domain+"/wood",int(wood[0]),int(wood[1]))
	if wood_count<0: return []
	var result: Array = [{"content_id":"mucai","quantity":wood_count}]
	var seeds: int = _bounded_roll(domain+"/seed",int(seed[0]),int(seed[1]))
	if seeds<0: return []
	if seeds>0: result.append({"content_id":"seed_shumu","quantity":seeds})
	return result
func validate_snapshot(value: Variant) -> Dictionary:
	if not ready or not _fields(value,FIELDS) or value["schema_version"]!=1 or typeof(value["schema_version"])!=TYPE_INT or value["contract"]!=CONTRACT or value["world_id"]!=_world_id or value["seed_decimal"]!=str(_seed) or value["fixture_only"]!=true or typeof(value["fixture_only"])!=TYPE_BOOL or typeof(value["revision"])!=TYPE_INT or value["revision"]<0 or value["revision"]>MAX_REVISION or not value["trees"] is Dictionary or not value["completions"] is Dictionary or value["trees"].size()>MAX_TREES or value["completions"].size()>value["trees"].size(): return _bad("TREE_LEDGER_CONTRACT")
	var occupied: Dictionary = {}
	var referenced: Dictionary = {}
	for id in value["trees"]:
		var tree: Variant = value["trees"][id]
		if not id is String or not _fields(tree,["content_id","layer","cell","stage","status","completion_id"]) or tree["content_id"]!="tree_putong" or tree["stage"]!="mature" or tree["status"] not in ["alive","felled"]: return _bad("TREE_LEDGER_INSTANCE")
		var site: Dictionary = _definition.inspect_fixture_site(tree["layer"],tree["cell"],[],[])
		if not site.get("ok",false) or tree["layer"]["world_id"]!=_world_id: return _bad("TREE_LEDGER_INSTANCE_SITE")
		if _definition.fixture_instance_id(_seed,tree["layer"],tree["cell"])["instance_id"]!=id: return _bad("TREE_LEDGER_INSTANCE_ID")
		var place := Address.key(tree["layer"])+"/"+str(tree["cell"])
		if occupied.has(place): return _bad("TREE_LEDGER_DUPLICATE_CELL")
		occupied[place]=true
		if tree["status"]=="alive":
			if tree["completion_id"]!=null: return _bad("TREE_LEDGER_ALIVE_COMPLETION")
		else:
			if tree["completion_id"]!=completion_identity(id) or not value["completions"].has(tree["completion_id"]): return _bad("TREE_LEDGER_MISSING_COMPLETION")
			if referenced.has(tree["completion_id"]): return _bad("TREE_LEDGER_DUPLICATE_COMPLETION")
			referenced[tree["completion_id"]]=id
	if referenced.size()!=value["completions"].size(): return _bad("TREE_LEDGER_ORPHAN_COMPLETION")
	for event in value["completions"]:
		if not event is String or not referenced.has(event): return _bad("TREE_LEDGER_ORPHAN_COMPLETION")
		var record: Variant = value["completions"][event]
		if not _fields(record,["tree_id","profile_id","completed_world_seconds","outputs","outcome_algorithm"]) or record["tree_id"]!=referenced[event] or not Authority._valid_id(record["profile_id"],"player_") or typeof(record["completed_world_seconds"])!=TYPE_FLOAT or not is_finite(record["completed_world_seconds"]) or record["completed_world_seconds"]<0.0 or record["outcome_algorithm"]!="sha256_rejection_v1" or not record["outputs"] is Array or record["outputs"].is_empty() or exact_token(record["outputs"])!=exact_token(outcomes(record["tree_id"],event)): return _bad("TREE_LEDGER_COMPLETION_RECORD")
	if not Codec.encode(value).get("ok",false): return _bad("TREE_LEDGER_EXACT_BUDGET")
	return {"ok":true,"fixture_only":true}
func trusted_restore(value: Variant) -> Dictionary:
	var checked := validate_snapshot(value)
	if checked.get("ok",false): _state=value.duplicate(true)
	return checked
func _plan(candidate: Dictionary, source: String, extra: Dictionary) -> Dictionary:
	var checked := validate_snapshot(candidate)
	if not checked.get("ok",false): return checked
	var result := {"ok":true,"state":candidate,"source_token":source,"fixture_only":true,"published":false,"durable":false}
	result.merge(extra)
	return result
static func completion_identity(tree_id: String) -> String:
	return "harvest_"+("tree-completion-v1/"+tree_id).sha256_text().substr(0,32)
static func exact_token(value: Variant) -> String:
	var encoded: Dictionary = Codec.encode(value)
	return JSON.stringify(encoded["value"],"",true,true).sha256_text() if encoded.get("ok",false) else ""
static func _bounded_roll(domain: String, lower: int, upper: int) -> int:
	var count: int = upper-lower+1
	var bound: int = 4294967296 - (4294967296 % count)
	var counter: int = 0
	while counter<128:
		var bytes: PackedByteArray = (domain+"/"+str(counter)).sha256_buffer()
		var sample: int = bytes.decode_u32(0)
		if sample<bound: return lower+(sample%count)
		counter+=1
	# Fail closed on a bounded entropy rejection; never substitute a count.
	return -1
static func _fields(value: Variant, names: Array) -> bool:
	if not value is Dictionary or value.size()!=names.size(): return false
	for name in names:
		if not value.has(name): return false
	return true
static func _bad(code: String) -> Dictionary:
	return {"ok":false,"code":code}
