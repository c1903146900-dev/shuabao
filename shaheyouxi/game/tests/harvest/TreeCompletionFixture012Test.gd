extends GdUnitTestSuite
## Real profile6 Store fixture preparation only; not a gameplay save receipt.
const Helper = preload("res://tests/harvest/TreeFrameCompletion012Test.gd")
const Ledger = preload("res://scripts/harvest/tree_ledger012.gd")
var helper
func before() -> void:
	helper=Helper.new()
	add_child(helper)
	helper.before()
func after_test() -> void:
	helper.after_test()
func after() -> void:
	helper.after()
	helper.free()
func test_prepare_complete_alive_store_fixture() -> void:
	var path:=OS.get_environment("TREE_ATOMIC_FIXTURE_OUTPUT")
	var source:=OS.get_environment("TREE_ATOMIC_STAGE_SHA")
	assert_bool(path.is_absolute_path() and source.length()==64).is_true()
	if not path.is_absolute_path() or source.length()!=64: return
	assert_bool(not DirAccess.dir_exists_absolute(path)).is_true()
	if DirAccess.dir_exists_absolute(path): return
	var f: Dictionary=await helper._alive_state()
	assert_bool(not f.is_empty()).is_true()
	if f.is_empty(): return
	# New isolated host fixture, never mutate any prior saved fixture or live authority.
	f["state"]["profiles"][f["profile"]]["role"] = "HOST"
	print("TREE_FIXTURE_PHASE generated_host_fixture ",Time.get_ticks_msec())
	var owner: Node=helper.support._owner(path)
	if owner==null: return
	var opened: Dictionary=helper.support._open(owner)
	assert_bool(opened.get("ok",false) and opened.get("new_world",false)).is_true()
	if not opened.get("ok",false) or not opened.get("new_world",false): return
	var saved: Dictionary=owner._save_store.save_main(f["state"],"isolated_tree_completion_fixture")
	print("TREE_FIXTURE_PHASE real_store_saved ",Time.get_ticks_msec()," ",JSON.stringify(saved))
	assert_bool(saved.get("ok",false)).is_true()
	if not saved.get("ok",false): return
	owner._save_store.close()
	var files: Dictionary={}
	for relative in ["main.json","auto/auto_01.json","world_identity.json"]:
		assert_bool(FileAccess.file_exists(path.path_join(relative))).is_true()
		if not FileAccess.file_exists(path.path_join(relative)): return
		files[relative]=FileAccess.get_sha256(path.path_join(relative))
	assert_str(files["main.json"]).is_equal(files["auto/auto_01.json"])
	var index: Dictionary={"kind":"isolated_tree_completion_fixture_v1","fixture_role":"HOST","source_stage_sha256":source,"world_id":f["state"]["world_id"],"tree_id":f["tree_id"],"profile":f["profile"],"actor_id":f["actor_id"],"state_token":Ledger.exact_token(f["state"]),"files":files,"reason":"isolated_tree_completion_fixture","sequence":saved["sequence"]}
	var file:=FileAccess.open(path.get_base_dir().path_join("fixture_index.json"),FileAccess.WRITE)
	assert_object(file).is_not_null()
	if file==null: return
	file.store_string(JSON.stringify(index,"  ",true,true)+"\n")
	file.close()
	print("TREE_FIXTURE_COMPLETE ",Time.get_ticks_msec()," main_sha=",files["main.json"])
