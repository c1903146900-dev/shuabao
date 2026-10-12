extends "res://scripts/actor/actor_terrain_space.gd"
## Exact profile6 fixture adapter. Static terrain semantics and epoch stay inherited.
const Native = preload("res://scripts/harvest/tree_native012.gd")
const TreeOwner = preload("res://scripts/harvest/tree_inventory_owner012.gd")
const TreeCore = preload("res://scripts/inventory/inventory_core012.gd")
var _owner_ref: WeakRef
var _service: RefCounted
var _tree_native: RefCounted
var _tree_prepare_attempted := false
var _tree_prepared_context: Dictionary = {}
var _tree_native_ready := false

func _init(terrain: Variant, terrain_store: RefCounted, owner: Object) -> void:
	super(terrain,terrain_store)
	_owner_ref=weakref(owner) if owner!=null else null
	_service=owner._inventory_owner if owner!=null else null

func _tree_owner_binding() -> bool:
	return _tree_owner_identity() and not _service._busy

func _tree_owner_identity() -> bool:
	var owner: Object=_owner_ref.get_ref() if _owner_ref!=null else null
	return owner!=null and is_instance_valid(owner) and owner.get_script()!=null and owner.get_script()==load("res://scripts/actor/actor_terrain_network_main.gd") and owner._save_store!=null and owner._save_store._lock_owned and owner._save_store._write_ready and owner._save_profile==6 and owner._save_profile_valid() and _tree_service_identity(owner) and owner._inventory_registry.verify_binding(6,owner._save_store).get("ok",false) and owner._inventory_owner==_service and _service!=null and _service.get_script()==TreeOwner and owner._actor_space==self and owner._terrain_store==_terrain_store and not owner._closing and not owner._fatal_shutdown

func _tree_service_identity(owner: Object) -> bool:
	return owner._inventory_registry_ready() and not owner._inventory_runtime_binding.is_empty() and owner._inventory_runtime_binding.get("registry")==owner._inventory_registry and owner._inventory_runtime_binding.get("owner")==_service and _service!=null and _service.get_script()==TreeOwner and _service._binding_valid() and _service._initialized and _service._authority==owner._authority and _service._contract._terrain==owner._terrain_session

func validate_completion_boundary(frame: Variant, ticket: Variant) -> Dictionary:
	if not _tree_owner_identity() or not _tree_native_ready or _tree_native==null or not frame is RefCounted or frame.get_script()!=load("res://scripts/actor/actor_frame_transaction.gd"): return {"ok":false,"code":"TREE_SPACE_COMPLETION_BINDING"}
	var owner: Object=_owner_ref.get_ref()
	if owner._bootstrap_frame!=frame or frame._space!=self or not frame._tree_pending is Dictionary or not is_same(frame._tree_pending.get("ticket"),ticket) or frame._tree_pending.get("service")!=_service or not _service._reserved_frame_matches(frame): return {"ok":false,"code":"TREE_SPACE_COMPLETION_TICKET"}
	var inherited: Dictionary=super.validate_actor_frame_boundary()
	if not inherited.get("ok",false): return inherited
	if frame._tree_pending.get("phase") not in ["detached","restoring"]: return {"ok":false,"code":"TREE_SPACE_COMPLETION_PHASE"}
	return _tree_native.validate_detached(frame._tree_pending.get("native_ticket"),_service.tree_snapshot()) if frame._tree_pending["phase"]=="detached" else _tree_native.validate_restored(frame._tree_pending.get("native_ticket"),_service.tree_snapshot())

func validate_ground_boundary(frame: Variant, ticket: Variant) -> Dictionary:
	# Keep ordinary validate_actor_frame_boundary's busy rejection. This exact
	# one-use Frame call validates ALL native actors and alive trees as usual.
	if not _tree_owner_identity() or not _tree_native_ready or _tree_native==null or not frame is RefCounted or frame.get_script()!=load("res://scripts/actor/actor_frame_transaction.gd"): return {"ok":false,"code":"TREE_SPACE_GROUND_BINDING"}
	var owner: Object=_owner_ref.get_ref()
	if owner._bootstrap_frame!=frame or frame._space!=self: return {"ok":false,"code":"TREE_SPACE_GROUND_FRAME"}
	var current: Dictionary=frame._ground_ticket_state(ticket,"validating")
	if not current.get("ok",false) or current.get("owner")!=owner or current.get("service")!=_service: return {"ok":false,"code":"TREE_SPACE_GROUND_TICKET"}
	var inherited: Dictionary=super.validate_actor_frame_boundary()
	if not inherited.get("ok",false): return inherited
	return _tree_native.validate_actual_actors(_service.tree_snapshot())

func configure(world: RefCounted, inputs: RefCounted) -> bool:
	if not _tree_owner_binding(): return _configuration_failed("TREE_SPACE_OWNER_BINDING")
	return super.configure(world,inputs)

func preparation_context() -> Dictionary:
	if not _tree_owner_binding(): return {}
	var owner: Object=_owner_ref.get_ref()
	var static_token: String=Native.static_context(self)
	var bundle_token: String=_service.boundary_token()
	var sources: Dictionary=TreeCore.Codec.encode([owner._authority.persistent_state(),owner._actor_model.persistent_state(),owner._world.public_component(),owner._terrain_component])
	if static_token.is_empty() or bundle_token.is_empty() or not sources.get("ok",false): return {}
	return {"owner":owner.get_instance_id(),"authority":owner._authority.get_instance_id(),"epoch":owner._authority.server_epoch,"world":owner._world.get_instance_id(),"model":owner._actor_model.get_instance_id(),"space":get_instance_id(),"service":_service.get_instance_id(),"store":owner._save_store.get_instance_id(),"registry":owner._inventory_registry.get_instance_id(),"bundle":bundle_token,"static":static_token,"source_state":JSON.stringify(sources["value"],"",true,true)}

func prepare_tree_boundary() -> Dictionary:
	if _tree_prepare_attempted or not _tree_owner_binding(): return {"ok":false,"code":"TREE_SPACE_PREPARE_ORDER"}
	_tree_prepare_attempted=true
	var context:=preparation_context()
	if context.is_empty(): return {"ok":false,"code":"TREE_SPACE_PREPARE_CONTEXT"}
	var owner: Object=_owner_ref.get_ref()
	var base: Dictionary=owner._actor_session.combine(owner._authority.persistent_state(),owner._actor_model)
	if base.get("ok",false): base=owner._terrain_session.combine(base["state"],owner._terrain_component)
	if base.get("ok",false): base=_service.combine_for_save(base["state"])
	if not base.get("ok",false): return base
	_tree_native=Native.new()
	var prepared: Dictionary=_tree_native.configure(base["state"],_service._tree_contract,self)
	if not prepared.get("ok",false): return prepared
	if preparation_context()!=context: return {"ok":false,"code":"TREE_SPACE_PREPARE_CHANGED"}
	_tree_prepared_context=context
	return {"ok":true,"pending":true,"context":context.duplicate(true)}

func confirm_tree_boundary(context: Variant) -> Dictionary:
	if _tree_native_ready or _tree_native==null or not context is Dictionary or _tree_prepared_context.is_empty() or context!=_tree_prepared_context or preparation_context()!=context: return {"ok":false,"code":"TREE_SPACE_CONFIRMATION_CHANGED"}
	var confirmed: Dictionary=_tree_native.confirm_initial(_service.tree_snapshot())
	if not confirmed.get("ok",false): return confirmed
	_tree_native_ready=true
	return validate_actor_frame_boundary()

func validate_actor_frame_boundary() -> Dictionary:
	var actual: Dictionary=super.validate_actor_frame_boundary()
	if not actual.get("ok",false): return actual
	if not _tree_native_ready or not _tree_owner_binding() or _tree_native==null: return {"ok":false,"code":"TREE_SPACE_NATIVE_NOT_READY"}
	# Never calls Frame publication or this virtual method through Native.
	return _tree_native.validate_actual_actors(_service.tree_snapshot())

func dispose() -> void:
	_tree_native_ready=false
	if _tree_native!=null: _tree_native.dispose()
	_tree_native=null
	_tree_prepared_context.clear()
	_service=null
	_owner_ref=null
	super.dispose()
