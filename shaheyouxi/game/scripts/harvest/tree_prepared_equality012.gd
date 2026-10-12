extends RefCounted
## Equality only, never an authority or state-validity certificate.
## The sole production caller supplies this invocation's full-validated original
## _plan_fixture_completion result on the left. No cached/external left is valid.
## Each independently validated object remains whole; singleton wrappers retain
## original field depth. Every original Codec budget and full Store gate remain.
const Codec = preload("res://scripts/save/exact_scalar_codec.gd")
const FIELDS := ["ok","bundle_token","base","request","plan","tree_plan","fixture_only"]
const REQUEST_FIELDS := ["tree_id","event_id","profile"]
const PLAN_FIELDS := ["ok","state","source_tokens","request","replay","created_drop_ids","published","durable","fixture_only"]
const TREE_PLAN_FIELDS := ["ok","state","source_token","fixture_only","published","durable","tree_id","completion_id","outputs","replay","must_not_create_drops"]
const BASE_FIELDS := ["world_id","world_seconds","revision","next_auto_due_world_seconds","profiles","world_component","actor_component","terrain_component"]
const STATE_FIELDS := ["world_id","world_seconds","revision","next_auto_due_world_seconds","profiles","world_component","actor_component","terrain_component","inventory_contract","inventory_component","tree_contract","tree_component"]
const LEDGER_FIELDS := ["schema_version","contract","world_id","seed_decimal","revision","fixture_only","trees","completions"]

static func matches_recomputed(verified: Variant, requested: Variant) -> bool:
	if not _shape(verified) or not _shape(requested): return false
	for key in FIELDS:
		# This boundary is fixed, not recursive chunking of oversized values.
		var left: Dictionary = Codec.encode({key:verified[key]})
		if not left.get("ok",false): return false
		var right: Dictionary = Codec.encode({key:requested[key]})
		if not right.get("ok",false): return false
		if JSON.stringify(left["value"],"",true,true)!=JSON.stringify(right["value"],"",true,true): return false
	return true

static func _shape(value: Variant) -> bool:
	if not _fields(value,FIELDS,true) or not _true(value["ok"]) or not _true(value["fixture_only"]) or not _text(value["bundle_token"]): return false
	if not _root(value["base"],false) or not _fields(value["request"],REQUEST_FIELDS,true): return false
	var request: Dictionary = value["request"]
	for key in REQUEST_FIELDS:
		if not _text(request[key]): return false
	var plan: Variant = value["plan"]
	if not _fields(plan,PLAN_FIELDS,true) or not _true(plan["ok"]) or not _true(plan["fixture_only"]) or not _false(plan["published"]) or not _false(plan["durable"]) or typeof(plan["replay"])!=TYPE_BOOL: return false
	if not _root(plan["state"],true) or not _fields(plan["source_tokens"],["tree","inventory","boundary"],true) or not _fields(plan["request"],["tree_id","completion_id","profile_id"],true) or not plan["created_drop_ids"] is Array: return false
	for key in plan["source_tokens"]:
		if not _text(plan["source_tokens"][key]): return false
	for key in plan["request"]:
		if not _text(plan["request"][key]): return false
	# Necessary Codec lower bound only; not a new gameplay quantity limit.
	if plan["created_drop_ids"].size()>Codec.MAX_NODES: return false
	for drop_id in plan["created_drop_ids"]:
		if not _text(drop_id): return false
	if plan["request"]["tree_id"]!=request["tree_id"] or plan["request"]["completion_id"]!=request["event_id"] or plan["request"]["profile_id"]!=request["profile"]: return false
	var trees: Variant = value["tree_plan"]
	if not _fields(trees,TREE_PLAN_FIELDS,true) or not _true(trees["ok"]) or not _true(trees["fixture_only"]) or not _false(trees["published"]) or not _false(trees["durable"]): return false
	if not _ledger(trees["state"]) or not _text(trees["source_token"]) or not _text(trees["tree_id"]) or not _text(trees["completion_id"]) or not trees["outputs"] is Array or typeof(trees["replay"])!=TYPE_BOOL or typeof(trees["must_not_create_drops"])!=TYPE_BOOL: return false
	if trees["replay"]!=plan["replay"] or trees["must_not_create_drops"]!=trees["replay"] or trees["tree_id"]!=request["tree_id"] or trees["completion_id"]!=request["event_id"] or trees["source_token"]!=plan["source_tokens"]["tree"]: return false
	if trees["outputs"].size()>Codec.MAX_NODES: return false
	for output in trees["outputs"]:
		if not _fields(output,["content_id","quantity"],true) or not _text(output["content_id"]) or typeof(output["quantity"])!=TYPE_INT: return false
	return true

static func _root(value: Variant, combined: bool) -> bool:
	if not _fields(value,STATE_FIELDS if combined else BASE_FIELDS,false): return false
	if not _text(value["world_id"]) or typeof(value["world_seconds"]) not in [TYPE_INT,TYPE_FLOAT] or typeof(value["revision"]) not in [TYPE_INT,TYPE_FLOAT] or typeof(value["next_auto_due_world_seconds"]) not in [TYPE_INT,TYPE_FLOAT]: return false
	for key in ["profiles","world_component","actor_component","terrain_component"]:
		if not value[key] is Dictionary: return false
	if combined:
		if not _text(value["inventory_contract"]) or not value["inventory_component"] is Dictionary or not _text(value["tree_contract"]) or not _ledger(value["tree_component"]): return false
	return true

static func _ledger(value: Variant) -> bool:
	if not _fields(value,LEDGER_FIELDS,false): return false
	return typeof(value["schema_version"])==TYPE_INT and _text(value["contract"]) and _text(value["world_id"]) and _text(value["seed_decimal"]) and typeof(value["revision"])==TYPE_INT and _true(value["fixture_only"]) and value["trees"] is Dictionary and value["completions"] is Dictionary

static func _fields(value: Variant, fields: Array, ordered: bool) -> bool:
	if not value is Dictionary or value.size()!=fields.size(): return false
	var keys: Array = value.keys()
	for index in keys.size():
		if typeof(keys[index])!=TYPE_STRING or not fields.has(keys[index]) or (ordered and keys[index]!=fields[index]): return false
	return true
static func _true(value: Variant) -> bool:
	return typeof(value)==TYPE_BOOL and value==true
static func _false(value: Variant) -> bool:
	return typeof(value)==TYPE_BOOL and value==false
static func _text(value: Variant) -> bool:
	return typeof(value)==TYPE_STRING and not value.is_empty()
