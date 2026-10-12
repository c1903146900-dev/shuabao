extends GdUnitTestSuite
## Private memo-function differential tests only; runtime authorization is not
## exercised here. The actual Native entry requires a real external SourceLease.
## Differential encoding tests only. No Owner, world generation, physics step,
## or native resource is created. An empty RID is accepted by static_context;
## none of these fixtures certifies collision, placement, or Native readiness.
## Load the heavy suite for syntax only; no instance or fixture is constructed.
const RuntimeSyntax = preload("res://tests/harvest/TreeNativeLeaseEncoding012Test.gd")
const AdmissionSyntax = preload("res://tests/harvest/TreeFullAdmission012Test.gd")
const Native = preload("res://scripts/harvest/tree_native012.gd")
const Space = preload("res://scripts/actor/actor_terrain_space.gd")
const ROOTS := ["_terrain", "_supported_regions", "_spaces"]

func _fixture() -> Dictionary:
	var space := Space.new({}, null)
	space._terrain = {"rows":[{"cell":[0,0],"kind":"中文\"\\\n/","zero":-0.0}]}
	space._supported_regions = [{"layer":{"name":"surface"},"bounds":[0,0,1,1],"cells":[[0,0]]}]
	space._spaces = {"surface":{"rid":RID(),"identity":{"name":"surface"},"materialized_bounds":[],"coverage_mode":"exact_cell_union_v1","materialized_cells":{"0,0":true},"cell_coverage_bounds":[0,0,1,1]}}
	space._supported_cell_count = 1
	space._validated_artifact_sha256 = "a".repeat(64)
	space._radius = 32.0
	space._half = 0.2
	space._static_epoch = 7
	var native := Native.new()
	native._space = space
	native._epoch = space._static_epoch
	native._spaces_root = space._spaces
	var original: String = Native.static_context(space)
	assert_bool(not original.is_empty()).is_true()
	native._static_token = original
	return {"space":space,"native":native,"original":original}

func _freeze(value: Variant) -> void:
	if value is Dictionary:
		for key in value: _freeze(value[key])
		value.make_read_only()
	elif value is Array:
		for item in value: _freeze(item)
		value.make_read_only()

func _freeze_roots(space: RefCounted) -> void:
	for field in ROOTS: _freeze(space.get(field))

func _assert_original_encoding(f: Dictionary) -> String:
	var expected: String = Native.static_context(f["space"])
	assert_str(f["native"]._memoize_static_identity()).is_equal(expected)
	return expected

func _warm(f: Dictionary) -> Dictionary:
	_freeze_roots(f["space"])
	assert_str(_assert_original_encoding(f)).is_equal(f["original"])
	var proof: Dictionary = f["native"]._static_encoding_proof
	assert_bool(not proof.is_empty() and proof.is_read_only()).is_true()
	assert_bool(is_same(proof,f["native"]._static_encoding_proof_root)).is_true()
	assert_bool(f["native"]._static_encoding_matches()).is_true()
	return proof

func _change_nested(space: RefCounted, field: String) -> void:
	match field:
		"_terrain": space._terrain["rows"][0]["kind"] = "changed"
		"_supported_regions": space._supported_regions[0]["bounds"][2] = 2
		"_spaces": space._spaces["surface"]["materialized_cells"]["1,0"] = true

func test_unfrozen_roots_never_gain_an_encoding_certificate() -> void:
	var f := _fixture()
	for ignored in range(2):
		assert_str(_assert_original_encoding(f)).is_equal(f["original"])
		assert_bool(f["native"]._static_encoding_proof.is_empty()).is_true()
		assert_bool(f["native"]._static_encoding_matches()).is_false()
	_change_nested(f["space"],"_terrain")
	assert_str(_assert_original_encoding(f)).is_not_equal(f["original"])
	assert_bool(f["native"]._static_encoding_proof.is_empty()).is_true()

func test_each_shallow_readonly_root_rejects_a_mutable_descendant() -> void:
	for shallow in ROOTS:
		var f := _fixture()
		var space: RefCounted = f["space"]
		for field in ROOTS:
			if field == shallow: space.get(field).make_read_only()
			else: _freeze(space.get(field))
		assert_bool(space.get(shallow).is_read_only()).is_true()
		assert_bool(Native._deep_readonly(space.get(shallow))).is_false()
		assert_str(_assert_original_encoding(f)).is_equal(f["original"])
		assert_bool(f["native"]._static_encoding_proof.is_empty()).is_true()
		_change_nested(space,shallow)
		assert_str(_assert_original_encoding(f)).is_not_equal(f["original"])
		assert_bool(f["native"]._static_encoding_proof.is_empty()).is_true()

func test_deepreadonly_real_roots_reuse_the_same_proof_and_encoding() -> void:
	var f := _fixture()
	var space: RefCounted = f["space"]
	var aliases: Array = [space._terrain["rows"],space._terrain["rows"][0],space._supported_regions[0],space._supported_regions[0]["bounds"],space._spaces["surface"],space._spaces["surface"]["identity"],space._spaces["surface"]["materialized_bounds"],space._spaces["surface"]["materialized_cells"],space._spaces["surface"]["cell_coverage_bounds"]]
	var proof := _warm(f)
	for alias in aliases: assert_bool(alias.is_read_only()).is_true()
	for ignored in range(3):
		assert_str(_assert_original_encoding(f)).is_equal(f["original"])
		assert_bool(is_same(proof,f["native"]._static_encoding_proof)).is_true()
		assert_bool(f["native"]._static_encoding_matches()).is_true()

func test_equal_root_replacement_is_a_miss_and_uses_original_encoding() -> void:
	for field in ROOTS:
		var f := _fixture()
		var prior := _warm(f)
		var space: RefCounted = f["space"]
		var old_root: Variant = space.get(field)
		var replacement: Variant = old_root.duplicate(true)
		_freeze(replacement)
		space.set(field,replacement)
		assert_bool(is_same(old_root,space.get(field))).is_false()
		assert_bool(f["native"]._static_encoding_matches()).is_false()
		assert_str(_assert_original_encoding(f)).is_equal(f["original"])
		# Original encoding accepts an equal copy. The enclosing SourceLease is
		# responsible for rejecting a replaced live root; this is not its bypass.
		assert_bool(is_same(prior,f["native"]._static_encoding_proof)).is_false()
		assert_bool(f["native"]._static_encoding_matches()).is_true()
		assert_str(f["native"]._static_token).is_equal(f["original"])

func test_changed_root_contents_cannot_reuse_or_replace_original_token() -> void:
	for field in ROOTS:
		var f := _fixture()
		_warm(f)
		var space: RefCounted = f["space"]
		var replacement: Variant = space.get(field).duplicate(true)
		space.set(field,replacement)
		_change_nested(space,field)
		_freeze(replacement)
		assert_bool(f["native"]._static_encoding_matches()).is_false()
		assert_str(_assert_original_encoding(f)).is_not_equal(f["original"])
		assert_bool(f["native"]._static_encoding_proof.is_empty()).is_true()
		assert_str(f["native"]._static_token).is_equal(f["original"])

func test_a_drifted_graph_frozen_before_first_proof_is_not_certified() -> void:
	var f := _fixture()
	_change_nested(f["space"],"_spaces")
	_freeze_roots(f["space"])
	assert_str(_assert_original_encoding(f)).is_not_equal(f["original"])
	assert_bool(f["native"]._static_encoding_proof.is_empty()).is_true()
	assert_str(f["native"]._static_token).is_equal(f["original"])

func test_invalid_entry_mode_bounds_type_and_fields_keep_original_failure() -> void:
	for change in ["mode","bounds_type","nonempty_materialized_bounds","extra_field","rid_type"]:
		var f := _fixture()
		_warm(f)
		var space: RefCounted = f["space"]
		space._spaces = space._spaces.duplicate(true)
		var entry: Dictionary = space._spaces["surface"]
		match change:
			"mode": entry["coverage_mode"] = "rectangle_shortcut"
			"bounds_type": entry["cell_coverage_bounds"] = "not an Array"
			"nonempty_materialized_bounds": entry["materialized_bounds"] = [[0,0,1,1]]
			"extra_field": entry["unknown"] = true
			"rid_type": entry["rid"] = "not a RID"
		_freeze(space._spaces)
		assert_bool(f["native"]._static_encoding_matches()).is_false()
		assert_str(_assert_original_encoding(f)).is_equal("")
		assert_bool(f["native"]._static_encoding_proof.is_empty()).is_true()
		assert_str(f["native"]._static_token).is_equal(f["original"])

func test_bounds_geometry_and_empty_rid_are_not_certified_by_encoding() -> void:
	var f := _fixture()
	f["space"]._spaces["surface"]["cell_coverage_bounds"] = [0,0,-1,0]
	var encoded: String = Native.static_context(f["space"])
	assert_bool(not encoded.is_empty()).is_true()
	assert_str(_assert_original_encoding(f)).is_equal(encoded)
	assert_bool(f["native"]._static_encoding_proof.is_empty()).is_true()
	assert_bool(f["native"]._ready or f["native"]._confirmed).is_false()
	# The unchanged scanner checks Array type, not valid coverage geometry.
	# Full configuration and native collision tests must reject/validate that.

func test_each_encoded_scalar_drift_misses_and_retains_the_original_token() -> void:
	for change in [["_supported_cell_count",2],["_validated_artifact_sha256","b".repeat(64)],["_radius",33.0],["_half",0.3]]:
		var f := _fixture()
		_warm(f)
		f["space"].set(change[0],change[1])
		assert_bool(f["native"]._static_encoding_matches()).is_false()
		assert_str(_assert_original_encoding(f)).is_not_equal(f["original"])
		assert_bool(f["native"]._static_encoding_proof.is_empty()).is_true()
		assert_str(f["native"]._static_token).is_equal(f["original"])

func test_scalar_negative_zero_bits_cannot_hit_positive_zero_proof() -> void:
	var f := _fixture()
	f["space"]._half = 0.0 # Encoding fixture only; not valid actor geometry.
	f["original"] = Native.static_context(f["space"])
	f["native"]._static_token = f["original"]
	_warm(f)
	var positive: String = f["native"]._static_scalar_encoding()
	var ieee:=PackedByteArray([0,0,0,0,0,0,0,128])
	var negative: float=ieee.decode_double(0)
	assert_str(Native.Core._exact(negative)).is_equal('["float64_le","0000000000000080"]')
	f["space"]._half=negative
	assert_str(Native.Core._exact(f["space"]._half)).is_equal('["float64_le","0000000000000080"]')
	assert_str(f["native"]._static_scalar_encoding()).is_not_equal(positive)
	assert_bool(f["native"]._static_encoding_matches()).is_false()
	assert_str(_assert_original_encoding(f)).is_not_equal(f["original"])
	assert_bool(f["native"]._static_encoding_proof.is_empty()).is_true()

func test_epoch_drift_misses_without_rebasing_the_native_validation_epoch() -> void:
	var f := _fixture()
	var prior := _warm(f)
	var epoch: int = f["native"]._epoch
	f["space"]._static_epoch += 1
	assert_bool(f["native"]._static_encoding_matches()).is_false()
	# Epoch is an outer _validate guard, not a field in static_context's bytes.
	assert_str(_assert_original_encoding(f)).is_equal(f["original"])
	assert_bool(is_same(prior,f["native"]._static_encoding_proof)).is_false()
	assert_int(f["native"]._epoch).is_equal(epoch)
	assert_int(f["space"]._static_epoch).is_not_equal(epoch)

func test_another_space_object_cannot_hit_the_first_spaces_proof() -> void:
	var f := _fixture()
	var prior := _warm(f)
	var other := Space.new({},null)
	for field in ROOTS: other.set(field,f["space"].get(field))
	for field in ["_supported_cell_count","_validated_artifact_sha256","_radius","_half","_static_epoch"]:
		other.set(field,f["space"].get(field))
	f["space"] = other
	f["native"]._space = other
	assert_bool(f["native"]._static_encoding_matches()).is_false()
	assert_str(_assert_original_encoding(f)).is_equal(f["original"])
	assert_bool(is_same(prior,f["native"]._static_encoding_proof)).is_false()
	assert_bool(is_same(f["native"]._static_encoding_proof["space"],other)).is_true()

func test_forged_proof_replacement_is_ignored_even_when_readonly() -> void:
	var f := _fixture()
	var prior := _warm(f)
	var forged: Dictionary = prior.duplicate(false)
	forged["encoding"] = "forged encoding"
	forged.make_read_only()
	f["native"]._static_encoding_proof = forged
	assert_bool(f["native"]._static_encoding_matches()).is_false()
	assert_str(_assert_original_encoding(f)).is_equal(f["original"])
	assert_bool(is_same(forged,f["native"]._static_encoding_proof)).is_false()
	assert_bool(f["native"]._static_encoding_matches()).is_true()

func test_proof_root_replacement_cannot_claim_the_prior_proof_identity() -> void:
	var f := _fixture()
	var prior := _warm(f)
	var replacement: Dictionary = prior.duplicate(false)
	replacement.make_read_only()
	f["native"]._static_encoding_proof_root = replacement
	assert_bool(f["native"]._static_encoding_matches()).is_false()
	assert_str(_assert_original_encoding(f)).is_equal(f["original"])
	assert_bool(is_same(prior,f["native"]._static_encoding_proof)).is_false()
	assert_bool(f["native"]._static_encoding_matches()).is_true()

func test_changed_original_token_does_not_make_the_proof_authoritative() -> void:
	var f := _fixture()
	_warm(f)
	f["native"]._static_token = "caller chosen token"
	assert_bool(f["native"]._static_encoding_matches()).is_false()
	assert_str(_assert_original_encoding(f)).is_equal(f["original"])
	assert_bool(f["native"]._static_encoding_proof.is_empty()).is_true()
	assert_str(f["native"]._static_token).is_equal("caller chosen token")

func test_unsupported_codec_leaf_cannot_be_cached_by_readonly_containers() -> void:
	var f := _fixture()
	f["space"]._terrain["object"] = RefCounted.new()
	_freeze_roots(f["space"])
	assert_str(_assert_original_encoding(f)).is_equal("")
	assert_bool(f["native"]._static_encoding_proof.is_empty()).is_true()

func test_dispose_clears_both_proof_roots_and_null_space_stays_uncached() -> void:
	var f := _fixture()
	_warm(f)
	var native: RefCounted = f["native"]
	assert_bool(native._bodies.is_empty() and native._shapes.is_empty()).is_true()
	native.dispose()
	assert_bool(native._static_encoding_proof.is_empty()).is_true()
	assert_bool(native._static_encoding_proof_root.is_empty()).is_true()
	assert_bool(native._space == null).is_true()
	assert_bool(native._static_encoding_matches()).is_false()
	assert_str(native._memoize_static_identity()).is_equal(Native.static_context(null))
	assert_str(native._memoize_static_identity()).is_equal("")
	assert_bool(native._static_encoding_proof.is_empty()).is_true()

func test_standalone_actual_entry_never_uses_memo_without_real_frame_lease() -> void:
	var f:=_fixture()
	_warm(f) # Exercise the pure memo seam, not an authoritative certificate.
	assert_str(f["native"]._static_identity()).is_equal(Native.static_context(f["space"]))
	assert_bool(f["native"]._static_encoding_proof.is_empty()).is_true()
	assert_bool(f["native"]._encoding_runtime_context().is_empty()).is_true()

func test_joint_private_proof_forgery_cannot_authorize_standalone_changed_root() -> void:
	var f:=_fixture()
	var proof:=_warm(f)
	var replacement: Dictionary=f["space"]._terrain.duplicate(true)
	replacement["rows"][0]["kind"]="changed"
	_freeze(replacement)
	f["space"]._terrain=replacement
	var forged: Dictionary=proof.duplicate(false)
	forged["terrain"]=replacement
	forged.make_read_only()
	f["native"]._static_encoding_proof=forged
	f["native"]._static_encoding_proof_root=forged
	# An internally rewritten memo is not a source certificate. The real entry
	# takes the original scanner because no real Frame/lease is bound.
	assert_str(f["native"]._static_identity()).is_equal(Native.static_context(f["space"]))
	assert_str(f["native"]._static_identity()).is_not_equal(f["original"])
