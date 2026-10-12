extends SceneTree
## Actual ENet client probe: acknowledged carry mutation, then transport close.
const Observer = preload("res://tests/inventory/inventory_enet_observer012.gd")
const Live = preload("res://scripts/inventory/inventory_live012.gd")
const Paths = preload("res://scripts/network/runtime_paths.gd")
var owner: Node
var live := Live.new()
var bound := false
var phase := 0
var report := ""
var failed := false
var finished := false
var identity: Dictionary = {}
var transport: Dictionary = {}
var history: Array = []
var _success_result: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args: Dictionary = {}
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--") or not arg.contains("="):
			_fail("BAD_ARGUMENT")
			return
		var pair := arg.trim_prefix("--").split("=", true, 1)
		if args.has(pair[0]):
			_fail("DUPLICATE_ARGUMENT")
			return
		args[pair[0]] = pair[1]
	report = Paths.scoped_path(ProjectSettings.globalize_path("res://"), OS.get_cmdline_user_args(), args.get("probe_report", ""))
	if report.is_empty() or FileAccess.file_exists(report) or args.get("mode") != "client" or args.get("exercise") != "false" or args.get("save_profile") != "5":
		_fail("BAD_SCOPE")
		return
	owner = Observer.new()
	owner.name = "NetworkMain"
	owner.private_reply_seen.connect(_reply)
	root.add_child(owner)
	process_frame.connect(_observe)
	create_timer(65.0).timeout.connect(func():
		if not finished: _fail("TIMEOUT"))

func _observe() -> void:
	if failed or finished or not is_instance_valid(owner): return
	if owner._fatal_shutdown:
		_fail("OWNER_FATAL")
		return
	var context: Dictionary = owner._client_actor_input_context()
	if not context.get("ok", false): return
	context["identity"]["input_generation"] = context["input_generation"]
	if bound:
		if not live.client_matches(context["identity"], context["transport"]): _fail("CONTEXT_CHANGED")
		return
	identity = context["identity"].duplicate(true)
	transport = context["transport"].duplicate(true)
	if not live.configure_client(identity, transport).get("ok", false):
		_fail("BIND_FAILED")
		return
	bound = true
	_send(live.issue_client("view", 0))

func _send(issued: Dictionary) -> void:
	if not issued.get("ok", false):
		_fail("ISSUE_FAILED")
		return
	if owner.rpc_id(1, &"inventory_request012", issued["request"]) != OK: _fail("SEND_FAILED")

func _reply(value: Variant) -> void:
	if failed or finished or not bound: return
	var context: Dictionary = owner._client_actor_input_context()
	if not context.get("ok", false):
		_fail("REPLY_CONTEXT_UNAVAILABLE")
		return
	context["identity"]["input_generation"] = context["input_generation"]
	if not live.client_matches(context["identity"], context["transport"]):
		_fail("REPLY_CONTEXT_CHANGED")
		return
	var accepted := live.accept_client(value)
	if not accepted.get("ok", false) or not accepted.get("action_ok", false):
		_fail("REPLY_REJECTED")
		return
	var view: Dictionary = accepted["view"]
	var inventory: Dictionary = view["inventory"]
	history.append({"kind": accepted["kind"], "sequence": accepted["sequence"], "checkpoint": live.client_checkpoint()})
	if phase == 0:
		if inventory["last_sequence"] != 19 or inventory["carry"].get("item_instance_id") != "item_fixture_gun" or inventory["bag"][0].get("quantity") != 731:
			_fail("FIXTURE_MISMATCH")
			return
		phase = 1
		_send(live.issue_client("left", 0, {"container":"bag", "owner":identity["player_profile_id"], "slot":2}, view["revision"], 20))
	elif phase == 1:
		if inventory["carry"] != null or inventory["bag"][2].get("item_instance_id") != "item_fixture_gun":
			_fail("PLACE_MISMATCH")
			return
		phase = 2
		_send(live.issue_client("left", 0, {"container":"bag", "owner":identity["player_profile_id"], "slot":0}, view["revision"], 21))
	elif phase == 2:
		if inventory["carry"].get("quantity") != 731 or inventory["bag"][0] != null or inventory["last_sequence"] != 21 or live.client_pending_count() != 0:
			_fail("CARRY_MISMATCH")
			return
		if not owner.arm_probe_expected_close(identity, transport, live.client_checkpoint()):
			_fail("EXPECTED_CLOSE_BINDING_FAILED")
			return
		finished = true
		_success_result = {"ok":true, "status":"acknowledged_carry_transport_close", "history":history, "inventory":inventory, "inventory_bytes_hex":var_to_bytes(inventory).hex_encode(), "checkpoint":live.client_checkpoint()}
		# The real transport emits server peer_disconnected. No stop-file, direct
		# server callback, fabricated receipt, or logical authority mutation.
		owner._peer.close()
		call_deferred("_finish_close")

func _finish_close() -> void:
	await process_frame
	await process_frame
	if failed or not is_instance_valid(owner) or owner._fatal_shutdown or not owner.probe_expected_disconnect_seen:
		_fail("UNEXPECTED_CLOSE_RESULT")
		return
	_success_result["expected_disconnect_seen"] = true
	_write(_success_result)
	quit(0)

func _write(value: Dictionary) -> void:
	if is_instance_valid(owner): value["startup_events"] = owner.probe_startup_events.duplicate(true)
	if report.is_empty(): return
	var file := FileAccess.open(report, FileAccess.WRITE)
	if file == null: return
	file.store_string(JSON.stringify(value, "", true, true))
	file.close()

func _fail(code: String) -> void:
	if failed: return
	failed = true
	_write({"ok":false, "code":code, "phase":phase})
	push_error(code)
	quit(1)
