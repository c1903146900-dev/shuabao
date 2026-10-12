extends GdUnitTestSuite
# Disk-drift semantic regression only, in a dedicated disposable stage. No Owner,
# Frame or hot publication. Actual Inputs and Motion are never mocked.
const Inputs = preload("res://scripts/actor/actor_inputs.gd")
const Motion = preload("res://scripts/actor/actor_motion.gd")
const Hot = preload("res://scripts/harvest/tree_ground_hot012.gd")
const Core = preload("res://scripts/inventory/inventory_core012.gd")
const WORLD := "world_11111111111111111111111111111111"
const SETTINGS := "res://data/actor_settings.json"
const AUTHORITIES := "res://data/actor_authorities.json"
var _saved_disk: Dictionary = {}

func after_test() -> void:
	_restore_disk()

func _write_bytes(path: String, bytes: PackedByteArray) -> bool:
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null: return false
	file.store_buffer(bytes)
	var error: Error=file.get_error()
	file.close()
	return error==OK and FileAccess.get_file_as_bytes(path)==bytes

func _restore_disk() -> bool:
	var complete:=true
	for path in _saved_disk.keys():
		var written:=_write_bytes(path,_saved_disk[path])
		var same: bool=FileAccess.get_file_as_bytes(path)==_saved_disk[path]
		assert_bool(written and same).is_true()
		if written and same: _saved_disk.erase(path)
		else: complete=false
	return complete

func test_paired_whitespace_and_authority_update_still_changes_actor_source_identity() -> void:
	# The launcher gives this test its own fresh stage. It must never write the
	# frozen producer or shared source project. Fail before any disk write otherwise.
	var allowed:=OS.get_environment("TREE_GROUND_SOURCE_MUTATION_STAGE")
	assert_bool(allowed.is_absolute_path()).is_true()
	assert_str(ProjectSettings.globalize_path("res://").trim_suffix("/")).is_equal(allowed.trim_suffix("/"))
	if not allowed.is_absolute_path() or ProjectSettings.globalize_path("res://").trim_suffix("/")!=allowed.trim_suffix("/"): return
	for path in [SETTINGS,AUTHORITIES]:
		assert_bool(FileAccess.file_exists(path)).is_true()
		if not FileAccess.file_exists(path): return
		var original_bytes:=FileAccess.get_file_as_bytes(path)
		assert_bool(not original_bytes.is_empty()).is_true()
		if original_bytes.is_empty(): return
		_saved_disk[path]=original_bytes
	var original_inputs:=Inputs.new()
	assert_bool(original_inputs.load_file()).is_true()
	if not original_inputs.ready: return
	var document:=original_inputs.document()
	var original_motion:=Motion.new(WORLD,document)
	assert_bool(original_motion.ready).is_true()
	var state: Dictionary=original_motion.persistent_state()
	assert_bool(original_motion.validate_persistent_state(state).get("ok",false)).is_true()
	var before:=var_to_bytes(state)
	var raw: String=_saved_disk[SETTINGS].get_string_from_utf8()+" \n"
	var authority: Dictionary=JSON.parse_string(_saved_disk[AUTHORITIES].get_string_from_utf8())
	authority["_projection_sha256"]=raw.sha256_text()
	if not _write_bytes(SETTINGS,raw.to_utf8_buffer()) or not _write_bytes(AUTHORITIES,JSON.stringify(authority,"",true,true).to_utf8_buffer()):
		assert_bool(false).is_true()
		_restore_disk()
		return
	assert_str(Core._exact(JSON.parse_string(raw))).is_equal(Core._exact(document))
	assert_bool(original_motion.validate_persistent_state(state).get("ok",false)).is_true()
	var fresh_inputs:=Inputs.new()
	assert_bool(fresh_inputs.load_document(document)).is_true()
	assert_str(Core._exact(fresh_inputs.document())).is_equal(Core._exact(document))
	assert_bool(Core._exact(fresh_inputs.source_identity())!=Core._exact(state["source_identity"])).is_true()
	assert_bool(Core._exact(fresh_inputs.source_identity())!=Core._exact(original_inputs.source_identity())).is_true()
	# B local token equivalence on actual fresh Inputs identities; original
	# Motion rejection assertions below remain authoritative for this small gate.
	for identity in [fresh_inputs.source_identity(), original_inputs.source_identity(), state["source_identity"]]:
		assert_str(Hot._small_exact(identity)).is_equal(Core._exact(identity))
		assert_bool(Hot._small_exact(identity).is_empty()).is_false()
	assert_bool(Hot._small_exact(fresh_inputs.source_identity()) != Hot._small_exact(state["source_identity"])).is_true()
	var fresh_motion:=Motion.new(WORLD,document)
	assert_bool(fresh_motion.ready).is_true()
	assert_str(Core._exact(fresh_motion.persistent_state()["source_identity"])).is_equal(Core._exact(fresh_inputs.source_identity()))
	var rejected: Dictionary=fresh_motion.validate_persistent_state(state)
	assert_bool(rejected.get("ok",false)).is_false()
	assert_str(rejected.get("code","")).is_equal("ACTOR_SNAPSHOT_INCOMPATIBLE_SOURCE")
	assert_bool(var_to_bytes(state)==before).is_true()
	if not _restore_disk(): return
	var restored_inputs:=Inputs.new()
	assert_bool(restored_inputs.load_document(document)).is_true()
	assert_str(Core._exact(restored_inputs.source_identity())).is_equal(Core._exact(state["source_identity"]))
	assert_str(Hot._small_exact(restored_inputs.source_identity())).is_equal(Hot._small_exact(state["source_identity"]))
	print("TREE_GROUND_SOURCE_FRESHNESS original_disk_restored=true full_hot_admission=false")
