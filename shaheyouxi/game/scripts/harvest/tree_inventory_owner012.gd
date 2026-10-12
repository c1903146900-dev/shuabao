extends RefCounted
const PreparedEquality = preload("res://scripts/harvest/tree_prepared_equality012.gd")
## Explicit profile6 service. Original profile5 InventoryOwner stays unchanged. The actual network
## owner must authenticate/queue/recheck requests at a confirmed Frame boundary.
## Atomic authoritative actions are NOT durable receipts. No save-file I/O here.
const FullAdmission = preload("res://scripts/harvest/tree_full_admission012.gd")
const DropPlan = preload("res://scripts/inventory/inventory_drop_plan012.gd")
const Ground = preload("res://scripts/inventory/inventory_ground012.gd")
const Core = preload("res://scripts/inventory/inventory_core012.gd")
const Combined = preload("res://scripts/inventory/inventory_world_session012.gd")
const View = preload("res://scripts/inventory/ui012/inventory_view012.gd")
const TreeSession = preload("res://scripts/harvest/tree_world_session012.gd")
const TreeTransaction = preload("res://scripts/harvest/tree_transaction012.gd")
const Ledger = preload("res://scripts/harvest/tree_ledger012.gd")
const Codec = preload("res://scripts/save/exact_scalar_codec.gd")
var ready: bool = false
var _initialized: bool = false
var _busy: bool = false
var _completion_reservation: Dictionary = {}
var _world_id: String = ""
var _bundle: Dictionary = {}
var _core: RefCounted:
	get: return _bundle.get("core")
var _trees: RefCounted:
	get: return _bundle.get("trees")
var _tree_contract: RefCounted
var _contract: RefCounted
var _access: Dictionary = {}
var _authority: RefCounted
var _catalogue_hash: String = ""
var _protocol: int = 0

func _init(terrain: RefCounted, authority: RefCounted) -> void:
	# Construct only after successful ordinary authority restore, or for a new
	# authority. Cold-load validation is a separate read-only registry path.
	if authority == null or authority.get_script() != Combined.Authority: return
	_authority = authority
	_world_id = authority.world_id
	_catalogue_hash = authority.catalogue_hash
	_protocol = authority.protocol_version
	var core := Core.new(_world_id,"v2_tree_seed")
	_replace_bundle(core,null)
	_contract = Combined.new(terrain, core, authority)
	ready = core.ready and _contract.ready

func _binding_valid() -> bool:
	return ready and _authority != null and _authority.get_script() == Combined.Authority and _authority.world_id == _world_id and _authority.catalogue_hash == _catalogue_hash and _authority.protocol_version == _protocol and _bundle_valid()

func initialize_empty(base: Dictionary) -> Dictionary:
	if not _binding_valid() or _initialized or _busy: return _bad("INVENTORY_OWNER_ALREADY_BOUND")
	var checked: Dictionary = _contract.combine(base,_core.snapshot())
	if not checked.get("ok",false): return checked
	var ledger:=Ledger.new(_world_id,base["world_component"]["layout"]["seed_decimal"])
	var wrapper:=TreeSession.new(_contract,_authority,base["world_component"]["layout"]["seed_decimal"])
	if not ledger.ready or not wrapper.ready: return _bad("TREE_OWNER_NOT_READY")
	checked=wrapper.combine(checked["state"],ledger.snapshot())
	if not checked.get("ok",false): return checked
	_tree_contract=wrapper
	_replace_bundle(_core,ledger)
	_initialized=true
	return {"ok":true}

func initialize_loaded(value: Variant) -> Dictionary:
	if not _binding_valid() or _initialized or _busy: return _bad("INVENTORY_OWNER_ALREADY_BOUND")
	if not value is Dictionary or not value.get("tree_component") is Dictionary or not value["tree_component"].get("seed_decimal") is String: return _bad("TREE_OWNER_LOAD_CONTRACT")
	var seed: String=value["tree_component"]["seed_decimal"]
	var wrapper:=TreeSession.new(_contract,_authority,seed)
	if not wrapper.ready: return _bad("TREE_OWNER_NOT_READY")
	var checked: Dictionary=wrapper.validate_combined_state(value)
	if not checked.get("ok",false): return checked
	var candidate:=Core.new(_world_id,"v2_tree_seed")
	var ledger:=Ledger.new(_world_id,seed)
	checked=candidate.trusted_restore(value["inventory_component"])
	if not checked.get("ok",false): return checked
	checked=ledger.trusted_restore(value["tree_component"])
	if not checked.get("ok",false): return checked
	_tree_contract=wrapper
	_replace_bundle(candidate,ledger)
	_initialized=true
	return {"ok":true}

func snapshot() -> Dictionary:
	return _core.snapshot() if _binding_valid() and _initialized else {}

func has_ground_component() -> bool:
	return _binding_valid() and _initialized and _core._state.get("schema_version") in [2,3]

func revision() -> int:
	return _core.revision() if _binding_valid() and _initialized else -1

func boundary_token() -> String:
	return _bundle["token"] if _binding_valid() and _initialized else ""

func tree_snapshot() -> Dictionary:
	return _trees.snapshot() if _binding_valid() and _initialized else {}

func combine_for_save(base: Dictionary) -> Dictionary:
	if not _binding_valid() or not _initialized or _busy: return _bad("INVENTORY_OWNER_NOT_AVAILABLE")
	return _combine(base,_core,_trees)

func _combine(base: Dictionary, core: RefCounted, trees: RefCounted) -> Dictionary:
	var inner: Dictionary=_contract.combine(base,core.snapshot())
	return _tree_contract.combine(inner["state"],trees.snapshot()) if inner.get("ok",false) else inner

func _combine_for_publication(base: Dictionary, core: RefCounted, trees: RefCounted) -> Dictionary:
	# Decide before any potentially overridden snapshot call. Nonstandard
	# objects execute precisely the original path, not a speculative extra call.
	if core==null or core.get_script()!=Core or trees==null or trees.get_script()!=Ledger or trees._definition==null or trees._definition.get_script()!=FullAdmission.Definition or not trees._definition.ready or not FullAdmission.standard_graph(_contract,_tree_contract):
		return _combine(base,core,trees)
	var checked: Dictionary=FullAdmission.try_combine(_contract,_tree_contract,base,core.snapshot(),trees.snapshot())
	# Failure and nonstandard graphs retain the exact original error ordering.
	return checked if checked.get("ok",false) else _combine(base,core,trees)

func prepare_new_player(base: Dictionary, authenticated_profile: String) -> Dictionary:
	# Only the real newly confirmed join calls this. Resume never creates a bag.
	if not _binding_valid() or not _initialized or _busy: return _bad("INVENTORY_OWNER_NOT_AVAILABLE")
	_busy = true
	var candidate := _copy_core()
	if candidate == null:
		_busy = false
		return _bad("INVENTORY_OWNER_COPY_INVALID")
	var action: Dictionary = candidate.trusted_create_player(authenticated_profile)
	var result := _publish_checked(base, candidate, action)
	_busy = false
	return result

func apply_left(base: Dictionary, authenticated_profile: String, address: Variant, expected_revision: Variant, sequence: Variant, hot_context: Dictionary = {}) -> Dictionary:
	# No client can call this directly. Peer/epoch/incarnation and FIFO cutoffs
	# belong to the actual network owner, not a client-supplied profile field.
	if not _binding_valid() or not _initialized or _busy: return _bad("INVENTORY_OWNER_NOT_AVAILABLE")
	_busy = true
	var candidate := _copy_core()
	if candidate == null:
		_busy = false
		return _bad("INVENTORY_OWNER_COPY_INVALID")
	if address is Dictionary and address.get("container") is String and address.get("container") == "chest" and address.get("owner") is String and _access.get(authenticated_profile, {}).has(address["owner"]):
		var grant: Dictionary = candidate.trusted_set_chest_access(authenticated_profile, address["owner"], true)
		if not grant.get("ok", false):
			_busy = false
			return grant
	var action: Dictionary = candidate.click_slot(authenticated_profile, address, expected_revision, sequence)
	var result := _publish_checked(base, candidate, action, hot_context)
	_busy = false
	return result

func drop_requires_world(profile: String, kind: String, address: Variant, expected_revision: Variant, sequence: Variant) -> Dictionary:
	if not _binding_valid() or not _initialized or _busy: return _bad("INVENTORY_OWNER_NOT_AVAILABLE")
	var candidate := _copy_core()
	if candidate == null: return _bad("INVENTORY_OWNER_COPY_INVALID")
	for chest in _access.get(profile, {}): candidate.trusted_set_chest_access(profile, chest, true)
	var planned: Dictionary = DropPlan.prepare(candidate, profile, kind, address, expected_revision, sequence)
	return {"ok": true, "required": planned["drop"] != null} if planned.get("ok", false) else planned

func apply_drop(base: Dictionary, profile: String, kind: String, address: Variant, expected_revision: Variant, sequence: Variant, layer: Dictionary, origin: Vector2, landing: Vector2, now: float, hot_context: Dictionary = {}) -> Dictionary:
	if not _binding_valid() or not _initialized or _busy: return _bad("INVENTORY_OWNER_NOT_AVAILABLE")
	_busy = true
	var candidate := _copy_core()
	if candidate == null:
		_busy = false
		return _bad("INVENTORY_OWNER_COPY_INVALID")
	for chest in _access.get(profile, {}): candidate.trusted_set_chest_access(profile, chest, true)
	var planned: Dictionary = Ground.prepare_drop(candidate, profile, kind, address, expected_revision, sequence, layer, origin, landing, now)
	if not planned.get("ok", false):
		_busy = false
		return planned
	var restored: Dictionary = candidate.trusted_restore(planned["state"])
	var result := _publish_checked(base, candidate, planned if restored.get("ok", false) else restored, hot_context)
	_busy = false
	return result

func advance_ground(base: Dictionary, now: float, pickup_range: float, pickup_speed: float, hot_context: Dictionary = {}) -> Dictionary:
	if not _binding_valid() or not _initialized or _busy: return _bad("INVENTORY_OWNER_NOT_AVAILABLE")
	_busy = true
	var candidate := _copy_core()
	if candidate == null:
		_busy = false
		return _bad("INVENTORY_OWNER_COPY_INVALID")
	var original: Dictionary = candidate.snapshot()
	var original_token: String = Core._exact(original)
	var delta: float = maxf(0.0, now - float(original.get("ground_clock", now)))
	var planned: Dictionary = Ground.advance(candidate, now)
	if not planned.get("ok", false):
		_busy = false
		return planned
	var restored: Dictionary = candidate.trusted_restore(planned["state"])
	if not restored.get("ok", false):
		_busy = false
		return restored
	var active: Dictionary = {}
	var players: Dictionary = _authority.public_snapshot()["players"]
	for profile in players:
		var actor_id: String = players[profile]["player_instance_id"]
		if not base["actor_component"]["actors"].has(actor_id):
			_busy = false
			return _bad("GROUND_PICKUP_ACTOR_MISSING")
		var actor: Dictionary = base["actor_component"]["actors"][actor_id]
		active[profile] = {"layer": actor["layer"].duplicate(true), "position": actor["position"].duplicate()}
	# Values are source-pinned by actor_settings; current exact approved values.
	var picked: Dictionary = Ground.pickup(candidate, active, delta, pickup_range, pickup_speed)
	if not picked.get("ok", false):
		_busy = false
		return picked
	restored = candidate.trusted_restore(picked["state"])
	picked["source_token"] = original_token
	var result := _publish_ground_checked(base, candidate, picked if restored.get("ok", false) else restored, hot_context, now, pickup_range, pickup_speed) if hot_context.has("ground_ticket") else _publish_checked(base, candidate, picked if restored.get("ok", false) else restored, hot_context)
	_busy = false
	return result


func trusted_set_access(profile: String, chest: String, allowed: bool) -> Dictionary:
	# The real owner must establish current actor, range, layer and F context.
	if not _binding_valid() or not _initialized or _busy: return _bad("INVENTORY_OWNER_NOT_AVAILABLE")
	var state: Dictionary = _core.snapshot()
	if not state["players"].has(profile) or not state["chests"].has(chest): return _bad("INVENTORY_ACCESS_SCOPE_INVALID")
	if not _access.has(profile): _access[profile] = {}
	if allowed: _access[profile][chest] = true
	else: _access[profile].erase(chest)
	return {"ok": true}

func close_view(profile: String) -> Dictionary:
	if not _binding_valid() or not _initialized or _busy or not _core.snapshot()["players"].has(profile): return _bad("INVENTORY_PLAYER_UNKNOWN")
	_access.erase(profile)
	return {"ok": true, "revision": revision()}

func view_for(_profile: String, _view_sequence: int) -> Dictionary:
	return {} # No legacy-v1 client view is certified for profile6 yet.

func _copy_core() -> RefCounted:
	var candidate := Core.new(_world_id,"v2_tree_seed")
	return candidate if candidate.trusted_restore(_core.snapshot()).get("ok", false) else null

func _publish_ground_checked(base: Dictionary, candidate: RefCounted, action: Dictionary, context: Dictionary, now: float, pickup_range: float, pickup_speed: float) -> Dictionary:
	# Exact actual Frame capability only. Ordinary/direct full service calls and
	# every non-ground operation keep the unchanged full publication path below.
	if not action.get("ok",false): return action
	if not _binding_valid() or not _initialized: return _bad("TREE_OWNER_BUNDLE_CHANGED")
	var prior: String=_bundle["token"]
	if action.has("source_token") and action["source_token"]!=Core._exact(_core.snapshot()): return _bad("INVENTORY_WHOLE_STATE_STALE")
	if not Core._fields(context,["frame","lease","ground_ticket"]) or not context["frame"] is RefCounted or context["frame"].get_script()!=load("res://scripts/actor/actor_frame_transaction.gd") or context["lease"]!=context["frame"]._source_lease: return _bad("TREE_GROUND_FRAME_CONTEXT")
	var checked: Dictionary=context["frame"]._validate_tree_ground_candidate(self,base,candidate,context["ground_ticket"],now,pickup_range,pickup_speed)
	if not checked.get("ok",false): return checked
	if not _binding_valid() or _bundle["token"]!=prior: return _bad("TREE_OWNER_BUNDLE_CHANGED")
	_replace_bundle(candidate,_trees)
	var result: Dictionary=action.duplicate(true)
	result["authoritative"]=true
	result["published"]=true
	result["durable"]=false
	return result

func _publish_checked(base: Dictionary, candidate: RefCounted, action: Dictionary, _hot_context: Dictionary = {}) -> Dictionary:
	if not action.get("ok",false): return action
	if not _binding_valid() or not _initialized: return _bad("TREE_OWNER_BUNDLE_CHANGED")
	var prior: String=_bundle["token"]
	if action.has("source_token") and action["source_token"]!=Core._exact(_core.snapshot()): return _bad("INVENTORY_WHOLE_STATE_STALE")
	# Profile6 never borrows the old5 hot certificate. Full new6 admission occurs
	# before the one aggregate root swap; the untouched tree root remains owned.
	var checked: Dictionary=_combine_for_publication(base,candidate,_trees)
	if not checked.get("ok",false): return checked
	if not _binding_valid() or _bundle["token"]!=prior: return _bad("TREE_OWNER_BUNDLE_CHANGED")
	_replace_bundle(candidate,_trees)
	var result: Dictionary=action.duplicate(true)
	result["authoritative"]=true
	result["published"]=true
	result["durable"]=false
	return result

# Explicit fixture-only completion settlement. First-hit timing is not defined;
# no keypress/network endpoint calls this API. The real Frame owns the ticket.
func plan_fixture_completion(base: Dictionary, tree_id: String, event_id: String, profile: String, expected_bundle: String) -> Dictionary:
	if not _binding_valid() or not _initialized or _busy or expected_bundle!=boundary_token(): return _bad("TREE_OWNER_COMPLETION_UNAVAILABLE")
	return _plan_fixture_completion(base,tree_id,event_id,profile,expected_bundle)

func _plan_fixture_completion(base: Dictionary, tree_id: String, event_id: String, profile: String, expected_bundle: String) -> Dictionary:
	if not _binding_valid() or expected_bundle!=boundary_token(): return _bad("TREE_OWNER_COMPLETION_STALE")
	var full:=_combine(base,_core,_trees)
	if not full.get("ok",false): return full
	var transaction:=TreeTransaction.new(_tree_contract,full["state"])
	if not transaction.ready: return _bad("TREE_OWNER_COMPLETION_INVALID")
	var planned: Dictionary=transaction.plan_completion(tree_id,event_id,profile,transaction.tokens())
	if not planned.get("ok",false): return planned
	var tree_plan: Dictionary=_trees.plan_completion(tree_id,event_id,profile,full["state"]["world_seconds"],_trees.token())
	if not tree_plan.get("ok",false): return tree_plan
	return {"ok":true,"bundle_token":expected_bundle,"base":base.duplicate(true),"request":{"tree_id":tree_id,"event_id":event_id,"profile":profile},"plan":planned,"tree_plan":tree_plan,"fixture_only":true}

func reserve_fixture_completion(frame: Variant, prepared: Variant) -> Dictionary:
	if _busy or not _completion_reservation.is_empty() or not _completion_frame_matches(frame) or frame._tree_pending.get("phase")!="preparing" or not prepared is Dictionary or not prepared.get("request") is Dictionary or not prepared.get("base") is Dictionary or not prepared.get("bundle_token") is String: return _bad("TREE_OWNER_COMPLETION_RESERVATION")
	var request: Dictionary=prepared["request"]
	if not Core._fields(request,["tree_id","event_id","profile"]): return _bad("TREE_OWNER_COMPLETION_REQUEST")
	for value in request.values():
		if not value is String: return _bad("TREE_OWNER_COMPLETION_REQUEST")
	var verified:=_plan_fixture_completion(prepared["base"],request["tree_id"],request["event_id"],request["profile"],prepared["bundle_token"])
	if not verified.get("ok",false): return verified
	if not PreparedEquality.matches_recomputed(verified,prepared): return _bad("TREE_OWNER_COMPLETION_PLAN_CHANGED")
	if verified["plan"]["replay"]: return _bad("TREE_OWNER_COMPLETION_REPLAY_NO_RESERVATION")
	var frozen: Dictionary=verified.duplicate(true)
	Ledger.Definition._freeze(frozen)
	_completion_reservation={"frame":weakref(frame),"ticket":frame._tree_pending["ticket"],"prepared":frozen,"published_token":""}
	_completion_reservation.make_read_only()
	_busy=true
	return {"ok":true,"reserved":true}

func publish_reserved_completion(frame: Variant) -> Dictionary:
	if not _reserved_frame_matches(frame) or frame._tree_pending.get("phase")!="detached" or not _completion_reservation["published_token"].is_empty(): return _bad("TREE_OWNER_COMPLETION_RESERVATION")
	var prepared: Dictionary=_completion_reservation["prepared"]
	var request: Dictionary=prepared["request"]
	var verified:=_plan_fixture_completion(prepared["base"],request["tree_id"],request["event_id"],request["profile"],prepared["bundle_token"])
	if not verified.get("ok",false): return verified
	if not PreparedEquality.matches_recomputed(verified,prepared): return _bad("TREE_OWNER_COMPLETION_PLAN_CHANGED")
	var next: Dictionary=verified["plan"]["state"]
	var core:=Core.new(_world_id,"v2_tree_seed")
	var trees:=Ledger.new(_world_id,_trees.snapshot()["seed_decimal"])
	if not core.trusted_restore(next["inventory_component"]).get("ok",false) or not trees.trusted_restore(next["tree_component"]).get("ok",false): return _bad("TREE_OWNER_COMPLETION_RESTORE")
	var checked:=_combine(prepared["base"],core,trees)
	if not checked.get("ok",false): return checked
	if Core._exact(checked["state"])!=Core._exact(next) or not _reserved_frame_matches(frame) or boundary_token()!=prepared["bundle_token"]: return _bad("TREE_OWNER_COMPLETION_FINAL_CAS")
	# One logical tree+ground ownership publication, with no await/callback.
	_replace_bundle(core,trees)
	var reservation: Dictionary=_completion_reservation.duplicate(false)
	reservation["published_token"]=boundary_token()
	reservation.make_read_only()
	_completion_reservation=reservation
	return {"ok":true,"published":true,"durable":false,"created_drop_ids":verified["plan"]["created_drop_ids"].duplicate(),"bundle_token":boundary_token()}

func release_completion_reservation(frame: Variant, published: bool) -> Dictionary:
	if not _reserved_frame_matches(frame): return _bad("TREE_OWNER_COMPLETION_RESERVATION")
	var expected: String=_completion_reservation["published_token"] if published else _completion_reservation["prepared"]["bundle_token"]
	if expected.is_empty() or boundary_token()!=expected or (not published and not _completion_reservation["published_token"].is_empty()): return _bad("TREE_OWNER_COMPLETION_RELEASE_CHANGED")
	if frame._tree_pending.get("phase")!=("published" if published else "restored"): return _bad("TREE_OWNER_COMPLETION_RELEASE_PHASE")
	_completion_reservation={}
	_busy=false
	return {"ok":true}

func _completion_frame_matches(frame: Variant) -> bool:
	if not frame is RefCounted or frame.get_script()!=load("res://scripts/actor/actor_frame_transaction.gd") or frame._source_lease==null or not frame._tree_pending is Dictionary or not frame._tree_pending.get("ticket") is RefCounted or frame._tree_pending.get("service")!=self: return false
	var owner: Object=frame._source_lease.bound_save_owner()
	return owner!=null and owner._bootstrap_frame==frame and owner._inventory_owner==self and owner._save_profile==6 and owner._arguments.get("test_entry")=="true" and owner._arguments.get("tree_fixture_profile")=="isolated"

func _reserved_frame_matches(frame: Variant) -> bool:
	return _busy and not _completion_reservation.is_empty() and _completion_reservation.is_read_only() and _completion_frame_matches(frame) and _completion_reservation["frame"].get_ref()==frame and is_same(frame._tree_pending["ticket"],_completion_reservation["ticket"])

func _bundle_valid() -> bool:
	if not Core._fields(_bundle,["core","trees","token","rules_token"]) or not _bundle.is_read_only() or _core==null or _core.get_script()!=Core or not _core.ready or not _core._tree_rules or _core._rules_identity!=Core.TREE_RULES_SHA256 or Core._exact(_core._rules)!=_bundle["rules_token"] or _core._world_id!=_world_id: return false
	if _initialized and (_trees==null or _trees.get_script()!=Ledger or not _trees.ready or _trees._world_id!=_world_id or _tree_contract==null or _tree_contract.get_script()!=TreeSession or not _tree_contract.ready or not _tree_contract._binding_valid() or str(_trees._seed)!=_tree_contract._seed_decimal or _trees.snapshot().get("seed_decimal")!=_tree_contract._seed_decimal): return false
	# Getter access is not mutation authority. An out-of-Frame mutation through
	# an internal RefCounted immediately invalidates this certificate and lineage.
	return _bundle["token"]==Core._exact([_core.snapshot(),_trees.snapshot() if _trees!=null else null])

func _replace_bundle(core: RefCounted, trees: RefCounted) -> void:
	var next: Dictionary={"core":core,"trees":trees,"rules_token":Core._exact(core._rules),"token":Core._exact([core.snapshot(),trees.snapshot() if trees!=null else null])}
	next.make_read_only()
	_bundle=next

static func _bad(code: String) -> Dictionary:
	return {"ok": false, "code": code}
