extends GdUnitTestSuite
## Original real Frame/Owner diagnostics, no sockets/GUI and no validation bypass.
## Records measured sections plus authoritative ground cohort/trajectory/totals.
const FrameFixture = preload("res://tests/inventory/InventoryGroundFrame012Test.gd")
const GroundView = preload("res://scripts/inventory/inventory_ground_view012.gd")
const PlayView = preload("res://scripts/actor/actor_terrain_play_view.gd")
var fixture
func before() -> void:
	fixture = FrameFixture.new()
	add_child(fixture) # _presence awaits the actual shared SceneTree physics frame.
	fixture.before()
func after_test() -> void:
	fixture.after_test()
func after() -> void:
	fixture.after()
	fixture.free()
func _wood(component: Dictionary) -> int:
	var total: int = 0
	for player in component["players"].values():
		for stack in player["bag"] + player["hotbar"] + [player["carry"]]:
			if stack != null and stack["content_id"] == "mucai": total += stack["quantity"]
	for record in component.get("ground", {}).values():
		if record["stack"]["content_id"] == "mucai": total += record["stack"]["quantity"]
	return total
func test_actual_ground_hot_path_timings_and_projection_conservation() -> void:
	var rows: Array = []
	var state: Dictionary = fixture._fixture_state()
	var profile: String = state["inventory_component"]["players"].keys()[0]
	var player: Dictionary = state["inventory_component"]["players"][profile]
	player["hotbar"][0] = player["carry"] # Unique fixture gun.
	player["bag"][0]["quantity"] = 997
	player["carry"] = player["bag"][0].duplicate(true)
	player["carry"]["quantity"] = 7
	player["carry_origin"] = {"container":"bag","owner":profile,"slot":0}
	player["hotbar"][1] = player["carry"].duplicate(true)
	player["hotbar"][1]["quantity"] = 10
	var owner: Node = fixture._owner()
	assert_bool(fixture._open(owner).get("new_world",false)).is_true()
	assert_bool(owner._restore_authority_state(state)["ok"]).is_true()
	await fixture._runtime(owner)
	await fixture._presence(owner,fixture._hello(owner,profile))
	var before: Dictionary = owner._inventory_owner.snapshot()
	var started: int = Time.get_ticks_usec()
	var drop: Dictionary = owner._bootstrap_frame.apply_confirmed_inventory_drop(owner,profile,"right_half",{"container":"bag","owner":profile,"slot":0},before["revision"],20,Vector2.RIGHT)
	var drop_usec: int = Time.get_ticks_usec() - started
	assert_bool(drop.get("ok",false)).is_true()
	if not drop.get("ok",false):
		fixture._fixtures._dispose_owner(owner)
		return
	assert_int(_wood(owner._inventory_owner.snapshot())).is_equal(1014)
	var first: Dictionary = owner._inventory_owner.snapshot()
	assert_int(first["ground"].size()).is_equal(1)
	assert_int(first["ground"].values()[0]["stack"]["quantity"]).is_equal(4)
	for index in range(3):
		started = Time.get_ticks_usec()
		var submitted: Dictionary = owner._bootstrap_frame.submit(1.0/60.0,[])
		var submit_usec: int = Time.get_ticks_usec() - started
		assert_bool(submitted.get("pending",false)).is_true()
		await get_tree().physics_frame
		started = Time.get_ticks_usec()
		assert_bool(owner._bootstrap_frame.confirm(submitted["ticket"]).get("confirmed",false)).is_true()
		var confirm_usec: int = Time.get_ticks_usec() - started
		started = Time.get_ticks_usec()
		var advanced: Dictionary = owner._bootstrap_frame.advance_confirmed_ground(owner)
		var advance_usec: int = Time.get_ticks_usec() - started
		assert_bool(advanced.get("ok",false)).is_true()
		var current: Dictionary = owner._inventory_owner.snapshot()
		assert_int(_wood(current)).is_equal(1014)
		assert_int(current["ground"].values()[0]["stack"]["quantity"]).is_equal(4)
		assert_float(current["ground_clock"]).is_equal(owner._authority.world_seconds)
		# Repeat only the original validation helpers read-only to isolate cost.
		started = Time.get_ticks_usec()
		var base: Dictionary = owner._bootstrap_frame._inventory_terrain_base(owner)
		var terrain_combine_usec: int = Time.get_ticks_usec() - started
		assert_bool(base.get("ok",false)).is_true()
		started = Time.get_ticks_usec()
		assert_bool(owner._inventory_owner.combine_for_save(base["state"]).get("ok",false)).is_true()
		var inventory_combine_usec: int = Time.get_ticks_usec() - started
		rows.append({"index":index,"clock":owner._authority.world_seconds,"submit_usec":submit_usec,"confirm_usec":confirm_usec,"advance_usec":advance_usec,"terrain_combine_usec":terrain_combine_usec,"inventory_combine_usec":inventory_combine_usec,"wood_total":_wood(current),"ground":current["ground"].duplicate(true)})
	var final_component: Dictionary = owner._inventory_owner.snapshot()
	var actor_id: String = owner._authority.public_snapshot()["players"][profile]["player_instance_id"]
	var actor: Dictionary = owner._actor_model.persistent_state()["actors"][actor_id]
	var identity := {"world_id":owner._authority.world_id,"server_epoch":owner._authority.server_epoch,"player_profile_id":profile,"player_instance_id":actor_id,"peer_id":11,"input_generation":owner._actor_model._input_generations[actor_id]}
	var public_rows: Array = []
	for id in final_component["ground"]:
		var record: Dictionary = final_component["ground"][id]
		if record["layer"] == actor["layer"]:
			public_rows.append({"id":id,"position":record["position"].duplicate(),"content_id":record["stack"]["content_id"],"quantity":record["stack"]["quantity"]})
	var packet := {"schema_version":1,"contract":"inventory012-private-ground-sync-v1","identity":identity,"view":owner._inventory_owner.view_for(profile,1),"layer":actor["layer"].duplicate(true),"world_seconds":owner._authority.world_seconds,"ground":public_rows}
	assert_bool(GroundView.validate(packet,identity,owner._inventory_owner._core._rules)).is_true()
	var visual := PlayView.new()
	visual.consume_ground_view(packet["layer"],packet["ground"])
	assert_bool(var_to_bytes(visual._ground_records) == var_to_bytes(public_rows)).is_true()
	assert_int(visual._ground_records.size()).is_equal(1)
	assert_int(visual._ground_records[0]["quantity"]).is_equal(4)
	visual.free()
	var throw_probes: Array = []
	for direction in [Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP]:
		var origin := Vector2(actor["position"][0],actor["position"][1])
		var probe: Dictionary = owner._bootstrap_frame.ThrowQuery.landing(owner._actor_space,actor["layer"],origin,direction,3.0)
		throw_probes.append({"direction":[direction.x,direction.y],"result":probe,"distance":origin.distance_to(probe["landing"]) if probe.get("ok",false) else -1.0})
	var report: Dictionary = {"throw_probes":throw_probes,"hot_boundary_stats":owner._inventory_owner._hot_boundary.statistics(),"kind":"actual_frame_ground_hot_path_diagnostic","synthetic_items":true,"socket":false,"gui":false,"drop_usec":drop_usec,"after_drop":first["ground"],"public_rows":public_rows,"projection_only_not_rpc":true,"rows":rows,"complete":true}
	var output: String = OS.get_environment("SANDBOX_GROUND_PROFILE_OUTPUT")
	assert_bool(output.is_absolute_path()).is_true()
	if output.is_absolute_path():
		var file := FileAccess.open(output,FileAccess.WRITE)
		assert_object(file).is_not_null()
		if file != null:
			file.store_string(JSON.stringify(report,"",true,true))
			file.close()
	fixture._fixtures._dispose_owner(owner)
