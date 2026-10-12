extends GdUnitTestSuite
## One source-only gate: a strict-copied, previously green ENet publication is
## resumed by a fresh actual Owner. No new completion, socket, or rule change.
const Disk = preload("res://scripts/save/windows_generation_store.gd") # Bounded listing/link helpers only.
const Support = preload("res://tests/harvest/TreeOwnerFrame012Test.gd")
const Ground = preload("res://scripts/inventory/inventory_ground012.gd")
const TreeSpace = preload("res://scripts/harvest/tree_terrain_space012.gd")
const STAGE_SHA: String = "623a73dbc39177404aeb10ec58f502ac17b4e7fd49284dcaab8e1d24353c6f71"
const PROBE_SHA: String = "b3afb1ffb8fd63417a35438271fa972e392a3e062e9a52990581d1b6a5b36ea5"
const PAIR_SHA: String = "c59e5453b4ae58c6816732035a92db64b0304454af8381344192c504963ea81c"
const GUARD_SHA: String = "4e85c5f56ae7aa99488aec78a8828e211bb91799074a3dc8b7593627cc3e06a6"
const MAIN_SHA: String = "b335888ca2ab94605db43a8b0aafb8518ef0cb096b6320d38b3650437800639c"
const STEP: float = 0.125 # Technical Frame delta only; gameplay settings stay intact.
const STEPS: int = 12
const EPSILON: float = 0.000001
var support: Variant

func before() -> void:
	support = Support.new()
	add_child(support)
	support.before()

func after_test() -> void:
	# Includes owners retained by an early-return failure, native RIDs and Store.
	support.after_test()

func after() -> void:
	support.after()
	support.free()

func test_published_schema3_fresh_owner_full_then_hot_natural_pickup_and_empty_clock() -> void:
	var f: Dictionary = await _opened_published_runtime()
	if f.is_empty(): return
	var server: Node = f["owner"]
	var state: Dictionary = f["state"]
	var original: Dictionary = state["inventory_component"]
	var tree_bytes: PackedByteArray = var_to_bytes(state["tree_component"])
	var all_totals: Dictionary = _item_totals(original)
	var profile: String = f["profile"]
	var actor_id: String = state["profiles"][profile]["player_instance_id"]
	var clock_start: float = state["world_seconds"]
	var born: float = f["completion"]["completed_world_seconds"]
	var expected_player: Dictionary = _player_totals(original["players"][profile])
	for id in original["ground"]:
		_add_stack(expected_player, original["ground"][id]["stack"])
	var service: RefCounted = f["service"]
	var frame: RefCounted = f["frame"]
	var space: RefCounted = f["space"]
	var first_started: int = Time.get_ticks_usec()
	var first: Dictionary = frame.advance_confirmed_ground(server)
	var first_usec: int = Time.get_ticks_usec() - first_started
	if not _need(first.get("ok", false) and first.get("published", false), "first full ground publication"): return
	if not _need(frame._ground_full_checks == 1 and frame._ground_hot_checks == 0, "one full admission before any hot hit"): return
	if not _need(var_to_bytes(service.snapshot()) == var_to_bytes(original), "zero elapsed first call preserves protected lots exactly"): return
	if not _runtime_clean(frame, service, space, f["tree_id"]): return
	if not _need(frame._ground_certificate.has("metrics"), "full check supplies metrics"): return
	var metrics: Dictionary = frame._ground_certificate["metrics"]
	if not _negative_time_is_rejected(frame, service, server, clock_start): return
	var protected_steps: int = 0
	var pickup_step: int = -1
	var empty_steps: int = 0
	var hot_usec: Array = []
	var clock: float = clock_start
	for step in range(STEPS):
		var previous: Dictionary = service.snapshot()
		var was_empty: bool = previous["ground"].is_empty()
		clock += STEP
		var advanced: Dictionary = await _advance_actual_tick(f, clock, step + 1)
		if advanced.is_empty(): return
		var elapsed_usec: int = advanced["advance_usec"]
		hot_usec.append(elapsed_usec)
		if not _need(frame._ground_full_checks == 1 and frame._ground_hot_checks == step + 1, "consecutive hot hit without hidden full fallback " + str(step + 1)): return
		if not _runtime_clean(frame, service, space, f["tree_id"]): return
		if not _need(is_same(metrics, frame._ground_certificate["metrics"]), "same proven static metrics " + str(step + 1)): return
		var current: Dictionary = service.snapshot()
		if not _need(current.get("schema_version") == 3 and current.get("ground_clock") == clock, "schema3 clock advances even with empty ground " + str(step + 1)): return
		if not _need(current["ground_serial"] == original["ground_serial"] and _item_totals(current) == all_totals and var_to_bytes(service.tree_snapshot()) == tree_bytes, "no creation, loss, or tree change " + str(step + 1)): return
		if not _natural_timers(current, f["event"], born, clock): return
		if clock - born < Ground.BASE_DELAY:
			protected_steps += 1
			if not _need(not current["ground"].is_empty() and var_to_bytes(current["players"]) == var_to_bytes(original["players"]), "no premature natural pickup"): return
		if current["ground"].is_empty() and pickup_step < 0:
			pickup_step = step + 1
			if not _need(not was_empty and clock - born >= Ground.BASE_DELAY and clock - born < Ground.LIFETIME, "ground emptied by eligible pickup before lifetime expiry"): return
			if not _need(_player_totals(current["players"][profile]) == expected_player, "all natural outputs reached the actual resumed player"): return
		if was_empty:
			empty_steps += 1
			if not _need(current["ground"].is_empty() and current["ground_clock"] == previous["ground_clock"] + STEP, "already-empty ground still advances exactly one delta"): return
			if not _need(var_to_bytes(current["players"]) == var_to_bytes(previous["players"]), "empty-ground ticking cannot create player items"): return
		print("TREE_GROUND_PUBLISHED_STEP ", JSON.stringify({"step": step + 1, "world_seconds": clock, "ground_clock": current["ground_clock"], "ground_count": current["ground"].size(), "full_calls": frame._ground_full_checks, "hot_calls": frame._ground_hot_checks, "advance_usec": elapsed_usec, "native_boundary_ok": true, "tickets_retired": true, "busy": false}))
	var final_inventory: Dictionary = service.snapshot()
	if not _need(protected_steps > 0 and pickup_step > 0 and empty_steps > 0 and final_inventory["ground"].is_empty(), "observed protected phase, actual pickup, and subsequent empty-ground ticks"): return
	if not _need(_player_totals(final_inventory["players"][profile]) == expected_player and _item_totals(final_inventory) == all_totals, "final pickup and whole inventory conservation"): return
	if not _negative_time_is_rejected(frame, service, server, clock): return
	# This is the original, independent full combine, not the hot helper, a
	# cached proof, a new durable save, or a claim about a new ENet execution.
	var base: Dictionary = frame._inventory_transaction_base(server)
	if not _need(base.get("ok", false) and base.get("state") is Dictionary, "final full base"): return
	var token_before: String = service.boundary_token()
	var full_started: int = Time.get_ticks_usec()
	var independent: Dictionary = service.combine_for_save(base["state"])
	var independent_usec: int = Time.get_ticks_usec() - full_started
	if not _need(independent.get("ok", false) and independent.get("state") is Dictionary, "independent original full admission"): return
	if not _need(var_to_bytes(independent["state"]["inventory_component"]) == var_to_bytes(final_inventory) and var_to_bytes(independent["state"]["tree_component"]) == tree_bytes and independent["state"]["world_seconds"] == clock, "independent full sees exact current published roots and clock"): return
	if not _need(service.boundary_token() == token_before and frame._ground_full_checks == 1 and frame._ground_hot_checks == STEPS, "independent full does not mutate publication or hot counters"): return
	if not _runtime_clean(frame, service, space, f["tree_id"]): return
	support.fixture._dispose_owner(server)
	if not _source_files_unchanged(f["store"], f["index"]): return
	if not _need(FileAccess.get_file_as_bytes(f["store"].path_join("main.json")) == f["main_bytes"], "source main exact bytes preserved"): return
	print("TREE_GROUND_PUBLISHED_SCHEMA3 ", JSON.stringify({"source_stage_sha256": STAGE_SHA, "source_main_sha256": MAIN_SHA, "profile": profile, "actor_id": actor_id, "step_seconds": STEP, "steps": STEPS, "first_full_calls": 1, "hot_calls": STEPS, "protected_steps": protected_steps, "pickup_step": pickup_step, "empty_ground_steps": empty_steps, "clock_start": clock_start, "clock_end": clock, "totals": all_totals, "tree_bytes_unchanged": true, "first_advance_usec": first_usec, "hot_advance_usec": hot_usec, "independent_full_usec": independent_usec, "source_files_unchanged": true, "new_enet_run": false, "ordinary_harvest_input": false, "new_save": false}))

func _opened_published_runtime() -> Dictionary:
	if not _require_test_identity(): return {}
	var f: Dictionary = _read_published_store()
	if f.is_empty(): return {}
	var server: Node = f["owner"]
	var state: Dictionary = f["state"]
	var original: Dictionary = state["inventory_component"]
	var tree_bytes: PackedByteArray = var_to_bytes(state["tree_component"])
	var profile: String = f["profile"]
	var actor_id: String = state["profiles"][profile]["player_instance_id"]
	var clock_start: float = state["world_seconds"]
	_phase("verified_published_store")
	var restored: Dictionary = server._restore_authority_state(state)
	if not _need(restored.get("ok", false), "fresh actual Owner restore"): return {}
	var service: RefCounted = server._inventory_owner
	if not _need(var_to_bytes(service.snapshot()) == var_to_bytes(original) and var_to_bytes(service.tree_snapshot()) == tree_bytes, "exact cold roots"): return {}
	if not _need(server._authority.active_peer_ids().is_empty() and server._terrain_generation_count == 0, "cold restore has no active transport or generation"): return {}
	if not _need(server._actor_space == null and server._bootstrap_frame == null, "native runtime not fabricated before preparation"): return {}
	var started: bool = await server._prepare_runtime_before_listen()
	if not _need(started, "actual native runtime preparation"): return {}
	if not _need(server._actor_space != null and server._actor_space.get_script() == TreeSpace, "actual tree terrain space"): return {}
	var frame: RefCounted = server._bootstrap_frame
	var space: RefCounted = server._actor_space
	if not _need(frame != null, "actual bootstrap Frame exists"): return {}
	var native: RefCounted = space._tree_native
	if not _need(native != null and not native._records.has(f["tree_id"]), "felled tree retained in ledger, absent from native collision"): return {}
	if not _need(space.validate_actor_frame_boundary().get("ok", false), "prepared native boundary"): return {}
	var hello: Dictionary = {"network_protocol_version": server._authority.protocol_version, "catalogue_sha256": server._authority.catalogue_hash, "display_name": state["profiles"][profile]["display_name"], "resume_profile_id": profile, "resume_secret": Support.resume_secret()}
	var prepared: Dictionary = frame.prepare_bootstrap_presence(11, hello, false)
	if not _need(prepared.get("ok", false) and prepared.get("prepared", false) and prepared.has("ticket"), "real presence prepare"): return {}
	var committed: Dictionary = frame.commit_bootstrap_presence(prepared["ticket"])
	if not _need(committed.get("pending", false) and committed.get("committed", false), "real presence commit"): return {}
	await get_tree().physics_frame
	var presence: Dictionary = frame.confirm_bootstrap_presence(prepared["ticket"])
	if not _need(presence.get("ok", false) and presence.get("confirmed", false), "real presence physics confirmation"): return {}
	if not _need(server._authority.active_peer_ids() == [11] and server._actor_model.active_actor_ids() == [actor_id], "actual resumed peer and actor"): return {}
	var active: Dictionary = server._authority.public_snapshot()["players"]
	if not _need(active.has(profile) and active[profile]["player_instance_id"] == actor_id, "saved profile is the real active pickup recipient"): return {}
	var present_inventory: Dictionary = service.snapshot()
	if not _need(server._authority.world_seconds == clock_start and server._actor_model.clock_seconds() == clock_start and present_inventory.get("ground_clock") == clock_start, "presence consumes no world time"): return {}
	if not _need(var_to_bytes(present_inventory) == var_to_bytes(original), "presence does not change published inventory"): return {}
	if not _need(server._actor_inputs.parameter("pickup_range_cells") == 3.0 and server._actor_inputs.parameter("pickup_attraction_speed_cells_per_second") == 8.0, "unchanged source pickup range and speed"): return {}
	if not _need(frame._ground_full_checks == 0 and frame._ground_hot_checks == 0, "first ground call is uncached"): return {}
	_phase("fresh_native_presence_confirmed")
	f["frame"] = frame
	f["space"] = space
	f["native"] = native
	f["service"] = service
	return f

func _advance_actual_tick(f: Dictionary, expected_clock: float, step_number: int) -> Dictionary:
	# Reusable by a separately selected save/cold gate. No completion, state
	# injection, or durable save is performed here.
	var server: Node = f["owner"]
	var frame: RefCounted = f["frame"]
	var submitted: Dictionary = frame.submit(STEP, [])
	if not _need(submitted.get("pending", false) and submitted.get("sealed", false) and submitted.get("delta_consumed", false) and submitted.has("ticket"), "actual positive Frame submit " + str(step_number)): return {}
	await get_tree().physics_frame
	var confirmed: Dictionary = frame.confirm(submitted["ticket"])
	if not _need(confirmed.get("ok", false) and confirmed.get("confirmed", false), "actual Frame confirm " + str(step_number)): return {}
	if not _need(server._authority.world_seconds == expected_clock and server._actor_model.clock_seconds() == expected_clock, "confirmed absolute clock " + str(step_number)): return {}
	var advance_started: int = Time.get_ticks_usec()
	var advanced: Dictionary = frame.advance_confirmed_ground(server)
	var elapsed_usec: int = Time.get_ticks_usec() - advance_started
	if not _need(advanced.get("ok", false) and advanced.get("published", false) and advanced.get("authoritative", false) and not advanced.get("durable", true), "hot ground publication " + str(step_number)): return {}
	return {"advanced": advanced, "advance_usec": elapsed_usec}

func _read_published_store() -> Dictionary:
	if not _require_test_identity(): return {}
	var root: String = OS.get_environment("TREE_ENET_COLD_INPUT")
	if not _need(root.is_absolute_path() and OS.get_environment("TREE_ENET_SAVED_STAGE_SHA") == STAGE_SHA, "strict copied published source and exact original stage required"): return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(root.path_join("cold_index.json")))
	if not _need(parsed is Dictionary, "cold index dictionary"): return {}
	var index: Dictionary = parsed
	if not _need(index.get("kind") == "actual_enet_tree_normal_v1" and index.get("source_stage_sha256") == STAGE_SHA and index.get("server_probe_sha256") == PROBE_SHA and index.get("source_pair_result_sha256") == PAIR_SHA and index.get("source_guard_sha256") == GUARD_SHA and index.get("files") is Dictionary, "pinned original green pair provenance"): return {}
	if not _need(index["files"].get("main.json") == MAIN_SHA and FileAccess.get_sha256(root.path_join("server_probe.json")) == PROBE_SHA, "published probe and main identity"): return {}
	var probe_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(root.path_join("server_probe.json")))
	if not _need(probe_value is Dictionary, "probe dictionary"): return {}
	var probe: Dictionary = probe_value
	if not _need(probe.get("ok", false) and probe.get("remote_disconnect", false) and not probe.get("fault_injection", true) and probe.get("mode") == "baseline" and probe.get("save_receipt") is Dictionary, "original real ENet baseline publication receipt"): return {}
	var receipt: Dictionary = probe["save_receipt"]
	if not _need(receipt.get("complete", false) and receipt.get("main_committed", false) and probe.get("published_tree_exact") is String and probe.get("published_inventory_exact") is String, "complete exact publication evidence"): return {}
	var expected_tree: Variant = bytes_to_var(probe["published_tree_exact"].hex_decode())
	var published: Variant = bytes_to_var(probe["published_inventory_exact"].hex_decode())
	if not _need(expected_tree is Dictionary and published is Dictionary, "published exact roots decode"): return {}
	var store: String = root.path_join("store")
	if not _source_files_unchanged(store, index): return {}
	var main_bytes: PackedByteArray = FileAccess.get_file_as_bytes(store.path_join("main.json"))
	var server: Node = support._owner(store)
	if not _need(server != null, "fresh actual Owner allocation"): return {}
	var loaded: Dictionary = support._open(server)
	if not _need(loaded.get("ok", false) and loaded.get("loaded_from") == "main" and loaded.get("state") is Dictionary and loaded.get("sequence") == receipt.get("sequence"), "real Store main restore and sequence"): return {}
	var state: Dictionary = loaded["state"]
	var encoded: Dictionary = Support.Codec.encode(state)
	if not _need(encoded.get("ok", false), "restored exact state encode"): return {}
	if not _need(JSON.stringify(encoded["value"], "", true, true).sha256_text() == receipt.get("state_sha256"), "original saved complete state receipt"): return {}
	var inventory: Dictionary = state["inventory_component"]
	var trees: Dictionary = state["tree_component"]
	if not _need(inventory.get("schema_version") == 3 and published.get("schema_version") == 3 and inventory.get("ground_clock") == state["world_seconds"] and not inventory["ground"].is_empty(), "actual saved schema3 ground and exact loaded clock"): return {}
	if not _need(var_to_bytes(trees) == var_to_bytes(expected_tree) and _item_totals(inventory) == _item_totals(published), "published tree exact and complete inventory totals"): return {}
	if not _need(trees["completions"].size() == 1, "one original completion"): return {}
	var event: String = trees["completions"].keys()[0]
	var completion: Dictionary = trees["completions"][event]
	var profile: String = completion["profile_id"]
	var tree_id: String = completion["tree_id"]
	if not _need(trees["trees"].has(tree_id) and trees["trees"][tree_id]["status"] == "felled" and trees["trees"][tree_id]["completion_id"] == event, "original felled ledger entry"): return {}
	if not _need(state["profiles"].has(profile) and inventory["players"].has(profile), "original completion profile exists"): return {}
	if not _need(state["profiles"][profile]["secret_hash"] == Support.resume_secret().sha256_text() and state["profiles"][profile]["display_name"] is String, "original producer credential and stored display name; no rewrite"): return {}
	if not _need(state["actor_component"]["actors"].has(state["profiles"][profile]["player_instance_id"]), "original saved actor exists"): return {}
	var born: float = completion["completed_world_seconds"]
	if not _need(published["ground_clock"] == born and state["world_seconds"] >= born and state["world_seconds"] - born < Ground.BASE_DELAY, "save remains inside original newborn protection interval"): return {}
	if not _natural_timers(inventory, event, born, state["world_seconds"]): return {}
	var outputs: Dictionary = {}
	for output in completion["outputs"]: _add_stack(outputs, output)
	var saved_ground: Dictionary = {}
	for record in inventory["ground"].values(): _add_stack(saved_ground, record["stack"])
	if not _need(saved_ground == outputs, "all original natural outputs still on ground"): return {}
	if not _protected_save_exact(published, inventory): return {}
	return {"owner": server, "state": state, "profile": profile, "tree_id": tree_id, "event": event, "completion": completion, "store": store, "index": index, "main_bytes": main_bytes}

func _protected_save_exact(published: Dictionary, saved: Dictionary) -> bool:
	# Only the source's legitimate elapsed timers and clock may differ from its
	# published root. Normalization is confined to this detached assertion copy.
	var elapsed: float = saved["ground_clock"] - published["ground_clock"]
	if not _need(elapsed >= 0.0 and published["ground"].keys() == saved["ground"].keys(), "protected publication-to-save drop identity"): return false
	var normalized: Dictionary = published.duplicate(true)
	normalized["ground_clock"] = saved["ground_clock"]
	for id in normalized["ground"]:
		var old_lots: Array = normalized["ground"][id]["lots"]
		var new_lots: Array = saved["ground"][id]["lots"]
		if not _need(old_lots.size() == new_lots.size(), "protected lot identity"): return false
		for i in range(old_lots.size()):
			if not _need(old_lots[i]["remaining_delay"] > elapsed, "source save precedes natural pickup eligibility"): return false
			for timer in ["remaining_lifetime", "remaining_delay"]:
				if not _need(absf(new_lots[i][timer] - maxf(0.0, old_lots[i][timer] - elapsed)) <= EPSILON, "source elapsed timer " + timer): return false
				old_lots[i][timer] = new_lots[i][timer]
	return _need(var_to_bytes(normalized) == var_to_bytes(saved), "all non-timer source inventory bytes exactly preserved")

func _natural_timers(inventory: Dictionary, event: String, born: float, now: float) -> bool:
	var age: float = now - born
	if not _need(age >= 0.0 and age < Ground.LIFETIME, "absolute natural lot age remains before expiry"): return false
	for record in inventory["ground"].values():
		var quantity: int = 0
		for lot in record["lots"]:
			if not _need(lot.get("source_kind") == "natural_harvest" and lot.get("completion_id") == event and lot["thrower"] == null and lot["remaining_thrower_protection"] == null, "natural provenance and null thrower timers unchanged"): return false
			if not _need(absf(lot["remaining_delay"] - maxf(0.0, Ground.BASE_DELAY - age)) <= EPSILON and absf(lot["remaining_lifetime"] - (Ground.LIFETIME - age)) <= EPSILON, "natural lot timers match original absolute completion time"): return false
			quantity += lot["quantity"]
		if not _need(quantity == record["stack"]["quantity"], "remaining lot quantity equals ground stack"): return false
	return true

func _runtime_clean(frame: RefCounted, service: RefCounted, space: RefCounted, tree_id: String) -> bool:
	if not _need(not service._busy and service._completion_reservation.is_empty() and frame._ground_pending.is_empty() and frame._ground_provisional.is_empty() and frame._sealed.is_empty() and frame._bootstrap_presence.is_empty() and frame._tree_pending.is_empty(), "busy and all transaction tickets retired"): return false
	if not _need(not frame._ground_invalidated and not frame._ground_certificate.is_empty() and frame._ground_hot.certificate_matches(frame, frame._ground_certificate), "live actual Frame ground certificate"): return false
	if not _need(frame._ground_certificate.get("metrics") is Dictionary and frame._ground_certificate.has("published_bundle") and is_same(frame._ground_certificate["published_bundle"], service._bundle) and is_same(frame._ground_cached_bundle, service._bundle), "certificate names current published root and proven metrics"): return false
	return _need(not space._tree_native._records.has(tree_id) and space.validate_actor_frame_boundary().get("ok", false), "actual native boundary and felled collision remain valid")

func _negative_time_is_rejected(frame: RefCounted, service: RefCounted, server: Node, now: float) -> bool:
	var before: PackedByteArray = var_to_bytes(service.snapshot())
	var authority_before: PackedByteArray = var_to_bytes(server._authority.persistent_state())
	var rejected: Dictionary = frame.submit(-STEP, [])
	if not _need(not rejected.get("ok", false) and rejected.get("code") == "FRAME_BATCH_OR_DELTA_INVALID" and not rejected.get("delta_consumed", true), "negative Frame delta rejected"): return false
	# Read-only original planner, using the actual published Core. This also
	# checks the regressed-clock guard after ground is empty; no state is applied.
	var regressed: Dictionary = Ground.advance(service._core, now - STEP)
	if not _need(not regressed.get("ok", false) and regressed.get("code") == "GROUND_CLOCK_REGRESSED", "negative ground clock rejected even with empty ground"): return false
	return _need(var_to_bytes(service.snapshot()) == before and var_to_bytes(server._authority.persistent_state()) == authority_before and not service._busy and frame._ground_pending.is_empty(), "negative time cannot change authority or inventory")

func _source_files_unchanged(store: String, index: Dictionary) -> bool:
	# Exact original baseline Store set, including its retained auto03. No
	# unknown file/link/lock/tmp can hide behind a loop over only known hashes.
	var expected: Dictionary = {"main.json":true, "auto/auto_01.json":true, "auto/auto_02.json":true, "auto/auto_03.json":true, "world_identity.json":true}
	if not _need(not Disk._is_link(store) and index.get("files") is Dictionary and index["files"].size() == expected.size(), "exact source Store index and root"): return false
	var found: Dictionary = {}
	for relative in ["", "auto", "manual"]:
		var folder: String = store if relative.is_empty() else store.path_join(relative)
		if not relative.is_empty() and not DirAccess.dir_exists_absolute(folder):
			if relative == "manual": continue
			return _need(false, "required source auto directory")
		if not _need(not Disk._is_link(folder), "source directory must not be a link"): return false
		var listing: Dictionary = Disk._directory_entries(folder, 16)
		if not _need(listing.get("ok", false), "bounded complete source directory listing"): return false
		for entry in listing["entries"]:
			var name: String = entry["name"]
			if not _need(not Disk._is_link(folder.path_join(name)), "no linked source entry"): return false
			if entry["directory"]:
				if not _need(relative.is_empty() and name in ["auto", "manual"], "no extra source directory"): return false
			else:
				found[name if relative.is_empty() else relative.path_join(name)] = true
	if not _need(found == expected, "closed five source Store files; no lock/tmp/extras"): return false
	for relative in index["files"]:
		if not _need(expected.has(relative), "only original baseline file identities"): return false
		if not _need(relative is String and not relative.is_absolute_path() and not ".." in relative.split("/") and index["files"][relative] is String, "safe indexed source file"): return false
		if not _need(FileAccess.get_sha256(store.path_join(relative)) == index["files"][relative], "source file unchanged " + relative): return false
	return true

func _item_totals(inventory: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for player in inventory["players"].values():
		for kind in ["bag", "hotbar"]:
			for stack in player[kind]: _add_stack(result, stack)
		_add_stack(result, player["carry"])
	for chest in inventory["chests"].values():
		for stack in chest["slots"]: _add_stack(result, stack)
	for record in inventory["ground"].values(): _add_stack(result, record["stack"])
	return result

func _player_totals(player: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for kind in ["bag", "hotbar"]:
		for stack in player[kind]: _add_stack(result, stack)
	_add_stack(result, player["carry"])
	return result

func _add_stack(totals: Dictionary, stack: Variant) -> void:
	if stack == null: return
	totals[stack["content_id"]] = int(totals.get(stack["content_id"], 0)) + stack["quantity"]

func _need(condition: bool, label: String) -> bool:
	if not condition: print("TREE_GROUND_PUBLISHED_ASSERTION ", label)
	assert_bool(condition).is_true()
	return condition

func _phase(label: String) -> void:
	print("TREE_GROUND_PUBLISHED_PHASE ", label, " wall_msec=", Time.get_ticks_msec())

func _require_test_identity() -> bool:
	var available: bool = not Support.resume_secret().is_empty()
	assert_bool(available).is_true()
	return available
