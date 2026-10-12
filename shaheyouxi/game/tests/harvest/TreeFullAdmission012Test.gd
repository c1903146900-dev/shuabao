extends "res://tests/harvest/TreeTransaction012Test.gd"
const TreeOwner = preload("res://scripts/harvest/tree_inventory_owner012.gd")
const Admission = preload("res://scripts/harvest/tree_full_admission012.gd")

func _cost_fixture() -> Dictionary:
	var f:=_joint_fixture()
	if f.is_empty(): return {}
	var state: Dictionary=f["joint"].snapshot()
	var service:=TreeOwner.new(f["owner"]._terrain_session,f["owner"]._authority)
	assert_bool(service.initialize_loaded(state).get("ok",false)).is_true()
	f["service"]=service
	var mirror_owner:=_empty_owner()
	var mirror:=TreeOwner.new(mirror_owner._terrain_session,mirror_owner._authority)
	assert_bool(mirror.initialize_loaded(state).get("ok",false)).is_true()
	f["mirror"]=mirror
	f["base"]=Combined.terrain_state(TreeSession.inventory_state(state))
	assert_bool(Admission.standard_graph(service._contract,service._tree_contract)).is_true()
	return f

func _same_admission(f: Dictionary, base: Dictionary, core: RefCounted, trees: RefCounted) -> void:
	var service: RefCounted=f["service"]
	var source:=var_to_bytes([base,core.snapshot(),trees.snapshot()])
	var t:=Time.get_ticks_usec()
	var old: Dictionary=service._combine(base,core,trees)
	var old_usec:=Time.get_ticks_usec()-t
	t=Time.get_ticks_usec()
	var fresh: Dictionary=f.get("mirror",service)._combine_for_publication(base,core,trees)
	var new_usec:=Time.get_ticks_usec()-t
	assert_bool(var_to_bytes(fresh)==var_to_bytes(old)).is_true()
	assert_bool(var_to_bytes([base,core.snapshot(),trees.snapshot()])==source).is_true()
	print("TREE_FULL_ADMISSION_DIFF ",JSON.stringify({"ok":old.get("ok",false),"code":old.get("code",""),"old_usec":old_usec,"new_usec":new_usec,"state_bytes_equal":var_to_bytes(fresh)==var_to_bytes(old)}))

func test_success_alive_and_felled_exact_roots_use_one_complete_inner_admission() -> void:
	var f:=_cost_fixture()
	if f.is_empty(): return
	var service: RefCounted=f["service"]
	var terrain: RefCounted=f["owner"]._terrain_store
	# Actual successful full validators, not a mock acceptance or reduced budget.
	_same_admission(f,f["base"],service._core,service._trees)
	var before_count: int=terrain.full_restore_validations+terrain.exact_restore_cache_hits
	assert_bool(service._combine_for_publication(f["base"],service._core,service._trees).get("ok",false)).is_true()
	assert_int(terrain.full_restore_validations+terrain.exact_restore_cache_hits-before_count).is_equal(1)
	var joint: RefCounted=f["joint"]
	assert_bool(joint.commit(joint.plan_completion(f["tree_id"],f["event"],f["profile"],joint.tokens())).get("ok",false)).is_true()
	var full: Dictionary=joint.snapshot()
	var core:=Core.new(WORLD,"v2_tree_seed")
	var trees:=TreeLedger.new(WORLD,full["tree_component"]["seed_decimal"])
	assert_bool(core.trusted_restore(full["inventory_component"])["ok"]).is_true()
	assert_bool(trees.trusted_restore(full["tree_component"])["ok"]).is_true()
	_same_admission(f,Combined.terrain_state(TreeSession.inventory_state(full)),core,trees)

func test_errors_keep_original_precedence_and_nonstandard_encoder_falls_back() -> void:
	var f:=_cost_fixture()
	if f.is_empty(): return
	var service: RefCounted=f["service"]
	f["mirror"]=service # Deliberately exercise this graph's actual mutations below.
	var base: Dictionary=f["base"].duplicate(true)
	base["inventory_contract"]="must_not_be_overwritten"
	_same_admission(f,base,service._core,service._trees)
	assert_str(service._combine_for_publication(base,service._core,service._trees)["code"]).is_equal("INVENTORY_WORLD_BASE_CONTRACT_INVALID")
	base=f["base"].duplicate(true)
	base["profiles"]={}
	var trees:=TreeLedger.new(WORLD,service._trees._state["seed_decimal"])
	trees._state={"malformed":true}
	_same_admission(f,base,service._core,trees)
	assert_str(service._combine_for_publication(base,service._core,trees)["code"]).is_equal("INVENTORY_WORLD_PROFILE_MISMATCH")
	# Changed original encoder configuration follows the old path; it is not
	# silently repaired or accepted through a differently configured proof.
	service._contract._budget_store._exact_scalars=false
	assert_bool(Admission.standard_graph(service._contract,service._tree_contract)).is_false()
	_same_admission(f,f["base"],service._core,service._trees)
	service._contract._budget_store._exact_scalars=true
	var original: RefCounted=service._contract
	service._contract=Combined.new(f["owner"]._terrain_session,service._core,f["owner"]._authority)
	assert_bool(Admission.standard_graph(service._contract,service._tree_contract)).is_false()
	_same_admission(f,f["base"],service._core,service._trees)
	service._contract=original

func _opaque_core(f: Dictionary, opaque: Dictionary) -> RefCounted:
	var core:=Core.new(WORLD,"v2_tree_seed")
	var state: Dictionary=f["service"]._core.snapshot()
	state["players"][f["profile"]]["bag"][0]={"content_id":"wuqi_huoqi_tansuo_01","quantity":1,"item_instance_id":"item_cost_gun","protected_instance_id":"protected_cost_gun","state":opaque}
	# Deliberately untrusted candidate, including overflow cases. Both actual
	# full validators must decide; never publish or trusted_restore invalid data.
	core._state=state
	return core

func test_complete_new6_four_mib_edge_and_exact_opaque_scalar_bytes() -> void:
	var f:=_cost_fixture()
	if f.is_empty(): return
	var service: RefCounted=f["service"]
	var opaque: Dictionary={"text":"中文\"\\\n\r\t/","bits":-0.0,"integer":Core.MAX_SEQUENCE,"blob":""}
	var core:=_opaque_core(f,opaque)
	var valid: Dictionary=service._combine(f["base"],core,service._trees)
	assert_bool(valid.get("ok",false)).is_true()
	if not valid.get("ok",false): return
	var store: RefCounted=service._tree_contract._budget_store
	var overhead: int=store._encode(valid["state"],Core.MAX_SEQUENCE,"manual","W".repeat(TreeSession.BoundedStore.MAX_REASON),63).to_utf8_buffer().size()
	for offset in [-1,0,1]:
		opaque["blob"]="x".repeat(TreeSession.MAX_BYTES-overhead+offset)
		core=_opaque_core(f,opaque)
		_same_admission(f,f["base"],core,service._trees)
		var result: Dictionary=service._combine_for_publication(f["base"],core,service._trees)
		assert_bool(result.get("ok",false)).is_equal(offset<=0)
		if offset>0: assert_str(result["code"]).is_equal("TREE_WORLD_FINAL_ENVELOPE_TOO_LARGE")

func test_complete_new6_codec_nodes_and_depth_cannot_bypass_full_limits() -> void:
	var f:=_cost_fixture()
	if f.is_empty(): return
	var service: RefCounted=f["service"]
	var core:=_opaque_core(f,{"items":[]})
	var valid: Dictionary=service._combine(f["base"],core,service._trees)
	assert_bool(valid.get("ok",false)).is_true()
	if not valid.get("ok",false): return
	var store: RefCounted=service._tree_contract._budget_store
	var text: String=store._encode(valid["state"],Core.MAX_SEQUENCE,"manual","W".repeat(TreeSession.BoundedStore.MAX_REASON),63)
	var envelope: Dictionary=JSON.parse_string(text)
	var hot=load("res://scripts/inventory/inventory_hot_boundary012.gd")
	var initial_nodes: int=hot.encoded_nodes(JSON.parse_string(envelope["payload_json"]))
	for offset in [-1,0,1]:
		var items: Array=[]
		items.resize(Codec.MAX_NODES-initial_nodes+offset)
		items.fill(false)
		core=_opaque_core(f,{"items":items})
		_same_admission(f,f["base"],core,service._trees)
		assert_bool(service._combine_for_publication(f["base"],core,service._trees).get("ok",false)).is_equal(offset<=0)
	for depth in [54,59,64,65]:
		var chain: Variant="leaf"
		for ignored in range(depth): chain=[chain]
		core=_opaque_core(f,{"chain":chain})
		_same_admission(f,f["base"],core,service._trees)

class CountingCore:
	extends "res://scripts/inventory/inventory_core012.gd"
	var snapshot_calls: int=0
	func snapshot() -> Dictionary:
		snapshot_calls+=1
		return super.snapshot()

class CallbackConfig:
	extends RefCounted
	var reads: int=0
	func _get(_property: StringName) -> Variant:
		reads+=1
		return [0.0,0.0]

func test_stateful_snapshot_and_object_config_never_enter_speculative_validation() -> void:
	var f:=_cost_fixture()
	if f.is_empty(): return
	var service: RefCounted=f["service"]
	var core:=CountingCore.new(WORLD,"v2_tree_seed")
	assert_bool(core.trusted_restore(service._core.snapshot()).get("ok",false)).is_true()
	var old: Dictionary=service._combine(f["base"],core,service._trees)
	assert_int(core.snapshot_calls).is_equal(1)
	core.snapshot_calls=0
	var fresh: Dictionary=service._combine_for_publication(f["base"],core,service._trees)
	assert_int(core.snapshot_calls).is_equal(1)
	assert_bool(var_to_bytes(fresh)==var_to_bytes(old)).is_true()
	var definition: RefCounted=service._tree_contract._ledger._definition
	var rules: Dictionary=definition._rules.duplicate(true)
	var callback:=CallbackConfig.new()
	rules["collision"]=callback
	definition._rules=rules
	assert_bool(Admission.standard_graph(service._contract,service._tree_contract)).is_false()
	assert_int(callback.reads).is_equal(0)
	var base: Dictionary=f["base"].duplicate(true)
	base["profiles"]={}
	old=service._combine(base,service._core,service._trees)
	fresh=service._combine_for_publication(base,service._core,service._trees)
	assert_bool(var_to_bytes(fresh)==var_to_bytes(old)).is_true()
	assert_str(fresh["code"]).is_equal("INVENTORY_WORLD_PROFILE_MISMATCH")
	assert_int(callback.reads).is_equal(0)
