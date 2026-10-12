extends SceneTree
## Exact original Owner and real ENet. Only automatic physics dispatch is
## replaced by a counted, once-per-real-frame call for bounded fault injection.
const Owner = preload("res://scripts/actor/actor_terrain_network_main.gd")
const Ledger = preload("res://scripts/harvest/tree_ledger012.gd")
const Paths = preload("res://scripts/network/runtime_paths.gd")
var server: Node
var root_path := ""
var nonce := ""
var probe_mode := ""
var fixture: Dictionary = {}
var history: Array = []
var failed := false
var request_ticket: RefCounted
var peer_id := 0
var bound: Dictionary = {}
var transport: Dictionary = {}
var last_frame := -1
var call_count := 0
var probe_process_count: int = 0
var probe_last_process_usec: int = 0
var probe_paused := false
var pause_usec := 0
var disconnected := false
var published := false
var trigger_written := false
var admitted_queue := PackedByteArray()
var admitted_consumed := -1
var admitted_clock := -1.0
var published_tree: Dictionary = {}
var published_inventory: Dictionary = {}

func _initialize() -> void:
	call_deferred("_start")

func _start() -> void:
	root_path = OS.get_environment("TREE_ENET_ROOT")
	nonce = OS.get_environment("TREE_ENET_NONCE")
	probe_mode = OS.get_environment("TREE_ENET_MODE")
	if root_path != Paths.scoped_path(ProjectSettings.globalize_path("res://"),OS.get_cmdline_user_args(),root_path) or nonce.length()!=32 or probe_mode not in ["baseline","detached_disconnect"]:
		_fail("DRIVER_SCOPE")
		return
	fixture = _read("fixture_index.json")
	if fixture.get("kind") != "isolated_tree_completion_fixture_v1" or fixture.get("sequence") != 1 or FileAccess.file_exists(root_path.path_join("server_probe.json")) or FileAccess.file_exists(root_path.path_join("close_trigger.json")):
		_fail("DRIVER_FIXTURE")
		return
	server = Owner.new()
	server.name = "NetworkMain"
	root.add_child(server)
	server.set_physics_process(false)
	physics_frame.connect(_tick)
	process_frame.connect(_watch)
	create_timer(100.0).timeout.connect(func():
		if not failed and not server._closing: _fail("DRIVER_DEADLINE"))

func _watch() -> void:
	probe_process_count += 1
	probe_last_process_usec = Time.get_ticks_usec()
	if failed or not is_instance_valid(server): return
	if server._fatal_shutdown or not server._live_failure_code.is_empty():
		_fail("ORIGINAL_OWNER_FATAL")
		return
	if probe_paused and Time.get_ticks_usec()-pause_usec > 10000000:
		_fail("REAL_DISCONNECT_NOT_OBSERVED")

func _tick() -> void:
	if failed or not is_instance_valid(server) or server._closing or server._fatal_shutdown: return
	var frame: int = Engine.get_physics_frames()
	if frame <= last_frame or server.is_physics_processing():
		_fail("DOUBLE_PHYSICS_DISPATCH")
		return
	last_frame = frame
	if not server._live_input_enabled: return
	if peer_id == 0:
		if server._live_input_roster.size()!=1:
			_fail("FIXED_ROSTER_SIZE")
			return
		peer_id = server._live_input_roster.keys()[0]
		bound = server._live_input_roster[peer_id].duplicate(true)
		transport = bound["transport"].duplicate(true)
		if peer_id<=1 or bound["profile_id"]!=fixture["profile"] or bound["actor_id"]!=fixture["actor_id"] or not server._tree_live_certificate_matches():
			_fail("REAL_REMOTE_BINDING")
			return
		_note("authenticated",{"peer_id":peer_id,"transport":transport,"context":server._live_input_context.duplicate(true)})
	if probe_paused:
		if not server._tree_disconnect_transports.has(peer_id): return
		if server._tree_disconnect_transports[peer_id] != transport or server._live_input_cutoff<0 or not server._tree_live_certificate_matches() or server._bootstrap_transport_incarnations.has(peer_id) or server._bootstrap_frame._tree_pending.get("phase")!="detached" or var_to_bytes(server._live_input_queue)!=admitted_queue or server._live_input_consumed_serial!=admitted_consumed or server._authority.world_seconds!=admitted_clock:
			_fail("DISCONNECT_CACHE_OR_FROZEN_STATE")
			return
		probe_paused=false
		disconnected=true
		_note("real_disconnect_cache",{"cutoff":server._live_input_cutoff,"transport":server._tree_disconnect_transports[peer_id].duplicate(true)})
	if request_ticket == null and not server._live_input_queue.is_empty():
		var input_event: Dictionary = server._live_input_queue[0]
		if input_event["envelope"]["peer_id"]!=peer_id or input_event["envelope"]["input_generation"]!=bound["input_generation"] or input_event["transport"]!=transport:
			_fail("REAL_ACTOR_ENVELOPE_BINDING")
			return
		var requested: Dictionary=server._queue_owner_fixture_tree_completion(peer_id,fixture["tree_id"],Ledger.completion_identity(fixture["tree_id"]))
		if not requested.get("queued",false) or requested.get("admitted")!=false or requested.has("accepted") or requested.has("ticket"):
			_fail("QUEUE_REQUEST")
			return
		request_ticket=requested["request_ticket"]
		_note("queued_real_actor_input",{"serial":input_event["serial"],"envelope":input_event["envelope"].duplicate(true),"transport":input_event["transport"].duplicate(true)})
	var delta: float = server.get_physics_process_delta_time()
	call_count+=1
	_note("physics_call",{"frame":frame,"delta":delta,"count":call_count,"process_count":probe_process_count,"last_process_usec":probe_last_process_usec})
	if failed: return
	var call_started_usec: int=Time.get_ticks_usec()
	server._physics_process(delta)
	print("TREE_ENET_SERVER_TRACE ",JSON.stringify({"event":"physics_return","usec":Time.get_ticks_usec(),"data":{"frame":frame,"call_usec":Time.get_ticks_usec()-call_started_usec,"process_count":probe_process_count,"last_process_usec":probe_last_process_usec,"world_seconds":server._authority.world_seconds if server._authority!=null else -1.0,"wire":server._terrain_wire_statistics.duplicate(true),"closing":server._closing,"fatal":server._fatal_shutdown}},"",true,true))
	if server._fatal_shutdown or not server._live_failure_code.is_empty():
		_fail("ORIGINAL_PHYSICS_FATAL")
		return
	if server._closing:
		var owner_report := _read("server_owner.json")
		if not published or not owner_report.get("saved",false) or owner_report.get("status")!="normal_shutdown" or not owner_report.get("disconnect_saved",false):
			_fail("ORIGINAL_NORMAL_SAVE_MISSING")
			return
		if not _write("server_probe.json",{"ok":true,"mode":probe_mode,"fault_injection":probe_mode=="detached_disconnect","history":history,"normal_shutdown":owner_report,"save_receipt":server._bootstrap_last_save_receipt.duplicate(true),"main_sha256":FileAccess.get_sha256(root_path.path_join("store/main.json")),"published_tree":published_tree,"published_inventory":published_inventory,"published_tree_exact":var_to_bytes(published_tree).hex_encode(),"published_inventory_exact":var_to_bytes(published_inventory).hex_encode(),"call_count":call_count,"remote_disconnect":true}):
			_fail("PROBE_REPORT_WRITE_FAILED")
		return # Original Owner already requested its exit code; do not replace it.
	if request_ticket == null: return
	var status: Dictionary=server._owner_fixture_tree_request_status(request_ticket)
	if status.get("phase")=="admitted" and not trigger_written and probe_mode=="detached_disconnect":
		if server._bootstrap_frame._tree_pending.get("phase")!="detached" or not server._live_input_ticket.is_empty():
			_fail("NOT_ACTUAL_DETACHED")
			return
		admitted_queue=var_to_bytes(server._live_input_queue)
		admitted_consumed=server._live_input_consumed_serial
		admitted_clock=server._authority.world_seconds
		if server._live_input_queue.is_empty():
			_fail("ADMITTED_QUEUE_WAS_CONSUMED")
			return
		probe_paused=true
		pause_usec=Time.get_ticks_usec()
		_trigger("detached")
	elif status.get("phase")=="published" and not published:
		published_tree=server._inventory_owner.tree_snapshot()
		published_inventory=server._inventory_owner.snapshot()
		var completion: String=Ledger.completion_identity(fixture["tree_id"])
		if published_tree.get("trees",{}).get(fixture["tree_id"],{}).get("status")!="felled" or not published_tree.get("completions",{}).has(completion) or not server._bootstrap_frame._tree_pending.is_empty():
			_fail("PUBLICATION_NOT_CONFIRMED")
			return
		if probe_mode=="detached_disconnect" and not disconnected:
			_fail("FAULT_NOT_OBSERVED")
			return
		published=true
		_note("published",{"tree_token":Ledger.exact_token(published_tree),"inventory_token":Ledger.exact_token(published_inventory),"completion":published_tree["completions"][completion]})
		if probe_mode=="baseline": _trigger("published")
	elif status.get("phase") in ["rejected","rollback_confirmed","replayed"]:
		_fail("UNEXPECTED_COMPLETION_PHASE")

func _trigger(phase: String) -> void:
	if trigger_written:
		_fail("DUPLICATE_TRIGGER")
		return
	var value: Dictionary={"nonce":nonce,"phase":phase,"peer_id":peer_id,"world_id":server._authority.world_id,"server_epoch":server._authority.server_epoch,"player_profile_id":bound["profile_id"],"player_instance_id":bound["actor_id"],"input_generation":bound["input_generation"],"tree_id":fixture["tree_id"],"completion_id":Ledger.completion_identity(fixture["tree_id"])}
	_note("close_trigger",value.duplicate(true))
	if failed: return
	if _write("close_trigger.json",value): trigger_written=true
	else: _fail("TRIGGER_WRITE_FAILED")

func _note(event: String, value: Dictionary) -> void:
	if history.size()>=512:
		_fail("DRIVER_HISTORY_BOUND")
		return
	var row: Dictionary={"event":event,"usec":Time.get_ticks_usec(),"data":value}
	history.append(row)
	print("TREE_ENET_SERVER_TRACE ",JSON.stringify(row,"",true,true))

func _read(name: String) -> Dictionary:
	var path:=root_path.path_join(name)
	if not FileAccess.file_exists(path) or FileAccess.get_file_as_bytes(path).size()>262144: return {}
	var value: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}

func _write(name: String, value: Dictionary) -> bool:
	var path:=root_path.path_join(name)
	if FileAccess.file_exists(path) or FileAccess.file_exists(path+".tmp"): return false
	var file:=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null: return false
	file.store_string(JSON.stringify(value,"  ",true,true)+"\n")
	file.close()
	return DirAccess.rename_absolute(path+".tmp",path)==OK

func _fail(code: String) -> void:
	if failed: return
	failed=true
	if not root_path.is_empty(): _write("server_probe.json",{"ok":false,"code":code,"history":history})
	if is_instance_valid(server) and not server._fatal_shutdown: server._fail(code,"Isolated ENet tree validation failed")
	else: quit(1)
