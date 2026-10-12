extends "res://tests/harvest/TreeFrameCompletion012Test.gd"
## Real Owner/Frame/SourceLease gates. Each method runs separately and consumes
## a previously verified full Store fixture; no fabricated source certificate.
func _warm_runtime() -> Dictionary:
	assert_bool(not OS.get_environment("TREE_ATOMIC_FIXTURE_INPUT").is_empty()).is_true()
	if OS.get_environment("TREE_ATOMIC_FIXTURE_INPUT").is_empty(): return {}
	var f: Dictionary=await _opened_alive_frame()
	if f.is_empty(): return {}
	var native: RefCounted=f["native"]
	var frame: RefCounted=f["frame"]
	assert_bool(native._encoding_runtime_context()==[frame,frame._source_lease]).is_true()
	assert_bool(native.validate_actual_actors(f["trees"]).get("ok",false)).is_true()
	assert_bool(not native._static_encoding_proof.is_empty()).is_true()
	assert_bool(native._static_encoding_matches()).is_true()
	assert_bool(is_same(native._encoding_frame_ref.get_ref(),frame)).is_true()
	assert_bool(is_same(native._encoding_lease_ref.get_ref(),frame._source_lease)).is_true()
	return f

func test_real_lease_hit_keeps_actor_native_checks_and_original_frame_delta() -> void:
	var f: Dictionary=await _warm_runtime()
	if f.is_empty(): return
	var native: RefCounted=f["native"]
	var frame: RefCounted=f["frame"]
	var space: RefCounted=f["space"]
	var proof: Dictionary=native._static_encoding_proof
	for ignored in range(3):
		assert_bool(native.validate_actual_actors(f["trees"]).get("ok",false)).is_true()
		assert_bool(is_same(proof,native._static_encoding_proof)).is_true()
	var shape: RID=space._actors[f["fixture"]["actor_id"]]["circle"]
	PhysicsServer2D.shape_set_data(shape,space._half+0.1)
	await get_tree().physics_frame
	assert_bool(native.validate_actual_actors(f["trees"]).get("ok",false)).is_false()
	PhysicsServer2D.shape_set_data(shape,space._half)
	await get_tree().physics_frame
	assert_bool(native.validate_actual_actors(f["trees"]).get("ok",false)).is_true()
	var old_clock: float=f["owner"]._authority.world_seconds
	var start:=Time.get_ticks_usec()
	var step: Dictionary=frame.submit(0.125,[])
	assert_bool(step.get("pending",false)).is_true()
	if not step.get("pending",false): return
	await get_tree().physics_frame
	var confirmed: Dictionary=frame.confirm(step["ticket"])
	assert_bool(confirmed.get("confirmed",false)).is_true()
	assert_float(f["owner"]._authority.world_seconds).is_equal(old_clock+0.125)
	assert_bool(is_same(proof,native._static_encoding_proof)).is_true()
	print("TREE_NATIVE_LEASE_REAL_FRAME ",JSON.stringify({"ok":confirmed.get("confirmed",false),"elapsed_usec":Time.get_ticks_usec()-start,"delta":0.125,"memo_hit":is_same(proof,native._static_encoding_proof)}))

func _assert_closed(f: Dictionary) -> void:
	var before: float=f["owner"]._authority.world_seconds
	var result: Dictionary=f["frame"].submit(0.125,[])
	assert_bool(result.get("fatal",false)).is_true()
	assert_bool(result.get("delta_consumed",false)).is_false()
	assert_float(f["owner"]._authority.world_seconds).is_equal(before)
	assert_bool(f["frame"].save_confirmed_owner("normal_shutdown").get("ok",false)).is_false()

func test_real_lease_released_cannot_reuse_hot_encoding() -> void:
	var f: Dictionary=await _warm_runtime()
	if f.is_empty(): return
	f["frame"]._source_lease.release()
	assert_bool(f["native"]._encoding_runtime_context().is_empty()).is_true()
	f["native"]._static_identity()
	assert_bool(f["native"]._static_encoding_proof.is_empty()).is_true()
	_assert_closed(f)

func test_real_lease_replaced_cannot_reuse_hot_encoding() -> void:
	var f: Dictionary=await _warm_runtime()
	if f.is_empty(): return
	var prior: RefCounted=f["frame"]._source_lease
	f["frame"]._source_lease=load("res://scripts/actor/actor_frozen_source_lease.gd").new()
	assert_bool(f["native"]._encoding_runtime_context().is_empty()).is_true()
	f["native"]._static_identity()
	assert_bool(f["native"]._static_encoding_proof.is_empty()).is_true()
	_assert_closed(f)
	prior.release()

func test_real_external_lease_rejects_changed_root_with_both_private_proofs_forged() -> void:
	var f: Dictionary=await _warm_runtime()
	if f.is_empty(): return
	var native: RefCounted=f["native"]
	var replacement: Dictionary=f["space"]._terrain.duplicate(true)
	replacement["artifact_sha256"]="b".repeat(64)
	Definition._freeze(replacement)
	f["space"]._terrain=replacement
	var forged: Dictionary=native._static_encoding_proof.duplicate(false)
	forged["terrain"]=replacement
	forged.make_read_only()
	native._static_encoding_proof=forged
	native._static_encoding_proof_root=forged
	assert_bool(native._encoding_runtime_context().is_empty()).is_true()
	assert_bool(not f["frame"]._source_lease.guard().get("ok",false)).is_true()
	assert_str(native._static_identity()).is_equal(Native.static_context(f["space"]))
	assert_str(native._static_identity()).is_not_equal(native._static_token)
	assert_bool(native._static_encoding_proof.is_empty()).is_true()
	_assert_closed(f)
