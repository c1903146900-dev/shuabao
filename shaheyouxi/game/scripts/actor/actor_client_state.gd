extends RefCounted
## Read-only public snapshot cache. No RPC, prediction, simulation, native bodies,
## scene writes, save writes or access to a live server authority are provided.
const World = preload("res://scripts/world_session/world_component.gd")
const Inputs = preload("res://scripts/actor/actor_inputs.gd")
const State = preload("res://scripts/actor/actor_state.gd")
const Session = preload("res://scripts/actor/actor_session_state.gd")
const Address = preload("res://scripts/world/spatial_address.gd")
const Geometry = preload("res://scripts/actor/actor_geometry.gd")
const Command = preload("res://scripts/actor/actor_command.gd")
const SNAPSHOT_FIELDS := ["server_epoch", "world_id", "revision", "world_seconds", "players", "max_players", "world_component", "actor_public"]
const PLAYER_FIELDS := ["player_profile_id", "player_instance_id", "display_name", "role", "peer_id"]
const MOTION_FIELDS := ["world_id", "clock", "revision", "actors", "input_cursors"]
const INPUT_CURSOR_FIELDS := ["input_generation", "accepted_sequence"]
const INPUT_CHECKPOINT_FIELDS := ["world_id", "server_epoch", "player_profile_id", "player_instance_id", "peer_id", "input_generation", "accepted_sequence", "actor_revision", "authority_revision", "world_seconds"]
const ACTOR_FIELDS := ["actor_id", "layer", "position", "health", "food", "energy", "alive", "dodging", "invulnerable", "dodge_cooldown_until", "dodge_start_position", "dodge_last_position", "aim_position", "last_valid_move"]
const PRIVATE_FIELDS := ["profiles", "secret_hash", "resume_secret", "resume_profile_id", "_profiles", "_peer_profiles", "_welcome_cache", "_command_cache", "actor_component", "fallback", "updated_at", "food_anchor_at", "food_anchor_value", "health_anchor_value", "energy_anchor_at", "energy_anchor_value", "last_consumption_at", "dodge_started_at", "dodge_until", "invulnerable_until", "dodge_direction", "rooted_until", "hit_feedback_until"]
const MAX_TREE_DEPTH := 64 # Public serialized-data safety bound, not gameplay.
const MAX_TREE_NODES := 100000 # Same bounded-data scale as the exact save codec.
var ready: bool = false
var last_error: String = ""
var _world: RefCounted
var _inputs: RefCounted
var _capacity: int = 0
var _half: float = 0.0
var _cache: Dictionary = {}

func configure(world011: RefCounted, inputs: RefCounted, network_settings: Dictionary) -> Dictionary:
	if ready:
		return _reject("ACTOR_CLIENT_ALREADY_CONFIGURED")
	if world011 == null or inputs == null or world011.get_script() != World or inputs.get_script() != Inputs or not world011.ready or not inputs.ready:
		return _reject("ACTOR_CLIENT_CONFIGURATION_INVALID")
	var documents: Array = []
	for name in ["generation_settings", "prefab_settings", "actor_world_bundle011", "network_settings"]:
		var document: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/" + name + ".json"))
		if not document is Dictionary:
			return _reject("ACTOR_CLIENT_APPROVED_INPUT_MISSING")
		documents.append(document)
	if network_settings != documents[3] or not Inputs.integer(network_settings.get("max_players")) or network_settings["max_players"] <= 0:
		return _reject("ACTOR_CLIENT_NETWORK_SETTINGS_MISMATCH")
	var own_inputs := Inputs.new()
	if not own_inputs.load_document(inputs.document()):
		return _reject("ACTOR_CLIENT_ACTOR_SOURCE_MISMATCH")
	var source_identity: Dictionary = own_inputs.source_identity()
	if network_settings.get("source_sha256") != source_identity["sources"]["shuzhi.xlsx"]:
		return _reject("ACTOR_CLIENT_NETWORK_SOURCE_MISMATCH")
	# A new approved validator does not create/restore a world. Retaining the
	# caller's live World or Inputs would expose mutable configuration aliases.
	var own_world := World.new(documents[0], documents[1], documents[2], "011")
	if not own_world.ready or world011.bundle_sha256 != own_world.bundle_sha256 or documents[2].get("actor_projection_sha256") != source_identity["projection_sha256"] or documents[2].get("sources") != source_identity["sources"]:
		return _reject("ACTOR_CLIENT_WORLD_SOURCE_MISMATCH")
	var half: float = own_inputs.parameter("actor_diameter_cells") / 2.0
	if not is_finite(half) or half <= 0.0:
		return _reject("ACTOR_CLIENT_BODY_SIZE_INVALID")
	_world = own_world
	_inputs = own_inputs
	_capacity = int(network_settings["max_players"])
	_half = half
	ready = true
	last_error = ""
	return {"ok": true, "code": "ACTOR_CLIENT_CONFIGURED"}

func consume(value: Variant, expected_epoch: String = "") -> Dictionary:
	if not ready:
		return _reject("ACTOR_CLIENT_NOT_CONFIGURED")
	var tree_error := _tree_error(value, 0, {"nodes": 0})
	if not tree_error.is_empty():
		return _reject(tree_error)
	if not State.exact_fields(value, SNAPSHOT_FIELDS):
		return _reject("ACTOR_CLIENT_SNAPSHOT_FIELDS_INVALID")
	if not SandboxServerAuthority._valid_id(value["server_epoch"], "session_") or not SandboxServerAuthority._valid_id(value["world_id"], "world_"):
		return _reject("ACTOR_CLIENT_WORLD_OR_EPOCH_INVALID")
	if not expected_epoch.is_empty() and (not SandboxServerAuthority._valid_id(expected_epoch, "session_") or value["server_epoch"] != expected_epoch):
		return _reject("ACTOR_CLIENT_EXPECTED_EPOCH_MISMATCH")
	if not _cache.is_empty() and (value["server_epoch"] != _cache["server_epoch"] or value["world_id"] != _cache["world_id"]):
		return _reject("ACTOR_CLIENT_SESSION_CHANGED")
	if not _revision(value["revision"]) or not State.valid_clock(value["world_seconds"]) or not Inputs.integer(value["max_players"]) or value["max_players"] != _capacity:
		return _reject("ACTOR_CLIENT_AUTHORITY_METADATA_INVALID")
	var players: Variant = value["players"]
	var motion: Variant = value["actor_public"]
	if not players is Dictionary or players.size() > _capacity or not State.exact_fields(motion, MOTION_FIELDS):
		return _reject("ACTOR_CLIENT_PUBLIC_COLLECTION_INVALID")
	if motion["world_id"] != value["world_id"] or not State.valid_clock(motion["clock"]) or motion["clock"] != value["world_seconds"] or not _revision(motion["revision"]) or not motion["actors"] is Dictionary:
		return _reject("ACTOR_CLIENT_MOTION_METADATA_INVALID")
	var expected_actors: Dictionary = {}
	var seen_peers: Dictionary = {}
	for profile_id in players:
		var player: Variant = players[profile_id]
		if not SandboxServerAuthority._valid_id(profile_id, "player_") or not State.exact_fields(player, PLAYER_FIELDS):
			return _reject("ACTOR_CLIENT_PLAYER_FIELDS_INVALID")
		if player["player_profile_id"] != profile_id or not SandboxServerAuthority._valid_id(player["player_instance_id"], "entity_player_") or expected_actors.has(player["player_instance_id"]):
			return _reject("ACTOR_CLIENT_PLAYER_IDENTITY_INVALID")
		if not Inputs.integer(player["peer_id"]) or player["peer_id"] <= 0 or seen_peers.has(int(player["peer_id"])):
			return _reject("ACTOR_CLIENT_PEER_IDENTITY_INVALID")
		if not player["display_name"] is String or player["display_name"].strip_edges().is_empty() or player["display_name"].length() > 64 or player["role"] not in ["HOST", "ADMIN", "MEMBER"]:
			return _reject("ACTOR_CLIENT_PLAYER_PRESENTATION_INVALID")
		expected_actors[player["player_instance_id"]] = true
		seen_peers[int(player["peer_id"])] = true
	var actors: Dictionary = motion["actors"]
	if actors.size() != expected_actors.size():
		return _reject("ACTOR_CLIENT_PLAYER_ACTOR_SET_MISMATCH")
	var cursors: Variant = motion["input_cursors"]
	if not cursors is Dictionary or cursors.size() != actors.size():
		return _reject("ACTOR_CLIENT_INPUT_CURSOR_SET_INVALID")
	for actor_id in actors:
		if not cursors.has(actor_id) or not State.exact_fields(cursors[actor_id], INPUT_CURSOR_FIELDS):
			return _reject("ACTOR_CLIENT_INPUT_CURSOR_FIELDS_INVALID")
		var cursor: Dictionary = cursors[actor_id]
		if typeof(cursor["input_generation"]) != TYPE_INT or cursor["input_generation"] < 1 or cursor["input_generation"] > motion["revision"]:
			return _reject("ACTOR_CLIENT_INPUT_GENERATION_INVALID")
		if typeof(cursor["accepted_sequence"]) != TYPE_INT or cursor["accepted_sequence"] < 0 or cursor["accepted_sequence"] > Command.MAX_SEQUENCE:
			return _reject("ACTOR_CLIENT_INPUT_SEQUENCE_INVALID")
	# Use the existing approved World validator, preceded by explicit versioned
	# field checks so future/private data cannot be normalized away into the cache.
	if Session._unknown_world_contract(value["world_component"]):
		return _reject("ACTOR_CLIENT_WORLD_FIELDS_INVALID")
	var world_check: Dictionary = _world.validate_component(value["world_component"], value["world_id"])
	if not world_check.get("ok", false):
		return _reject("ACTOR_CLIENT_WORLD_INVALID:" + str(world_check.get("code", "UNKNOWN")))
	var component: Dictionary = world_check["component"]
	if not State.exact_fields(component["layout"]["retry_configuration"], ["max_region_attempts"]):
		return _reject("ACTOR_CLIENT_WORLD_FIELDS_INVALID")
	var layers: Dictionary = Session._loaded_layers(component)
	var radius: float = component["layout"]["body"]["radius_cells"]
	for actor_id in actors:
		if not expected_actors.has(actor_id):
			return _reject("ACTOR_CLIENT_PLAYER_ACTOR_SET_MISMATCH")
		var actor: Variant = actors[actor_id]
		if not State.exact_fields(actor, ACTOR_FIELDS) or actor["actor_id"] != actor_id:
			return _reject("ACTOR_CLIENT_ACTOR_FIELDS_OR_ID_INVALID")
		if not Address.valid_layer(actor["layer"]) or actor["layer"]["world_id"] != value["world_id"] or not layers.has(Address.key(actor["layer"])):
			return _reject("ACTOR_CLIENT_ACTOR_LAYER_INVALID")
		for field in ["position", "dodge_start_position", "dodge_last_position"]:
			if not State.valid_pair(actor[field]):
				return _reject("ACTOR_CLIENT_ACTOR_POSITION_INVALID")
		if not _valid_aim(actor["aim_position"]) or not State.valid_direction(actor["last_valid_move"]):
			return _reject("ACTOR_CLIENT_ACTOR_AIM_OR_DIRECTION_INVALID")
		for field in ["health", "food", "energy"]:
			if not Inputs.number(actor[field]) or actor[field] < 0.0 or actor[field] > _inputs.parameter(field + "_max"):
				return _reject("ACTOR_CLIENT_ACTOR_RESOURCE_INVALID")
		for field in ["alive", "dodging", "invulnerable"]:
			if typeof(actor[field]) != TYPE_BOOL:
				return _reject("ACTOR_CLIENT_ACTOR_FLAG_INVALID")
		if actor["alive"] != (actor["health"] > 0.0) or (not actor["alive"] and (actor["dodging"] or actor["invulnerable"])):
			return _reject("ACTOR_CLIENT_ACTOR_LIFE_FLAGS_INVALID")
		if not State.valid_clock(actor["dodge_cooldown_until"]):
			return _reject("ACTOR_CLIENT_ACTOR_COOLDOWN_INVALID")
		# The existing environment body is a circle. This is the COMPLETE circle,
		# not center-in-disc, an enclosing map square, or a new peer-square boundary.
		if State.vector(actor["position"]).length() + _half > radius:
			return _reject("ACTOR_CLIENT_COMPLETE_BODY_OUTSIDE_MAP")
	var ids: Array = actors.keys()
	for first in range(ids.size()):
		for second in range(first + 1, ids.size()):
			var a: Dictionary = actors[ids[first]]
			var b: Dictionary = actors[ids[second]]
			# Mandated nonrotating peer AABB: formal diameter on each axis. A
			# diagonal center-distance/circle test would incorrectly admit overlap.
			if Address.key(a["layer"]) == Address.key(b["layer"]) and Geometry.overlaps(State.vector(a["position"]), State.vector(b["position"]), _half, _half):
				return _reject("ACTOR_CLIENT_PEER_AABB_OVERLAP")
	var ordering := _check_order(value)
	if not ordering["ok"]:
		return ordering
	if ordering.get("duplicate", false):
		last_error = ""
		return {"ok": true, "code": "ACTOR_CLIENT_SNAPSHOT_DUPLICATE", "duplicate": true}
	# Every preceding check is read-only. Keep the original public data, not a
	# synthesized simulation or the World validator's normalized replacement.
	_cache = value.duplicate(true)
	last_error = ""
	return {"ok": true, "code": "ACTOR_CLIENT_SNAPSHOT_ACCEPTED", "duplicate": false}

func snapshot() -> Dictionary:
	return _cache.duplicate(true)

func input_checkpoint(profile_id: Variant, peer_id: Variant) -> Dictionary:
	# Copy ten scalar fields from one already accepted cache. No large world copy,
	# independent cursor read, resource simulation or authority object is involved.
	if not ready or _cache.is_empty() or not SandboxServerAuthority._valid_id(profile_id, "player_") or typeof(peer_id) != TYPE_INT or peer_id <= 0 or not _cache["players"].has(profile_id):
		return {}
	var player: Dictionary = _cache["players"][profile_id]
	if player["peer_id"] != peer_id:
		return {}
	var actor_id: String = player["player_instance_id"]
	var motion: Dictionary = _cache["actor_public"]
	var cursor: Dictionary = motion["input_cursors"][actor_id]
	return {
		"world_id": _cache["world_id"], "server_epoch": _cache["server_epoch"],
		"player_profile_id": profile_id, "player_instance_id": actor_id, "peer_id": peer_id,
		"input_generation": cursor["input_generation"], "accepted_sequence": cursor["accepted_sequence"],
		"actor_revision": int(motion["revision"]), "authority_revision": int(_cache["revision"]), "world_seconds": _cache["world_seconds"],
	}

func _check_order(value: Dictionary) -> Dictionary:
	if _cache.is_empty():
		return {"ok": true}
	var motion: Dictionary = value["actor_public"]
	var previous: Dictionary = _cache["actor_public"]
	if value["revision"] < _cache["revision"] or motion["revision"] < previous["revision"] or value["world_seconds"] < _cache["world_seconds"]:
		return _reject("ACTOR_CLIENT_STALE_SNAPSHOT")
	# Authority.advance does not increment authority.revision. Motion commits do
	# increment actor.revision, including idle resource/clock ticks. Never freeze
	# the display by deduplicating solely on the authority revision.
	if value["revision"] == _cache["revision"] and value["players"] != _cache["players"]:
		return _reject("ACTOR_CLIENT_AUTHORITY_REVISION_CONFLICT")
	if motion["revision"] == previous["revision"] and motion != previous:
		return _reject("ACTOR_CLIENT_ACTOR_REVISION_CONFLICT")
	var bindings: Dictionary = _input_bindings(value["players"])
	var previous_bindings: Dictionary = _input_bindings(_cache["players"])
	for actor_id in motion["input_cursors"]:
		var cursor: Dictionary = motion["input_cursors"][actor_id]
		var older: Dictionary = previous["input_cursors"].get(actor_id, {})
		if not older.is_empty() and bindings[actor_id]["player_profile_id"] != previous_bindings[actor_id]["player_profile_id"]:
			return _reject("ACTOR_CLIENT_ACTOR_PROFILE_CHANGED")
		if not older.is_empty() and cursor["input_generation"] == older["input_generation"]:
			if bindings[actor_id] != previous_bindings[actor_id]:
				return _reject("ACTOR_CLIENT_INPUT_BINDING_CHANGED_WITHOUT_GENERATION")
			if cursor["accepted_sequence"] < older["accepted_sequence"]:
				return _reject("ACTOR_CLIENT_INPUT_CURSOR_ROLLBACK")
		elif cursor["input_generation"] <= previous["revision"]:
			# Every newly visible activation happened AFTER the previous snapshot.
			# A disconnect/rejoin may be entirely between reports; seeing an offline
			# snapshot is unnecessary. Reusing an old activation revision is invalid.
			return _reject("ACTOR_CLIENT_INPUT_GENERATION_REUSED")
	if value["revision"] == _cache["revision"] and motion["revision"] == previous["revision"]:
		if value != _cache:
			return _reject("ACTOR_CLIENT_DUPLICATE_VERSION_CONFLICT")
		return {"ok": true, "duplicate": true}
	return {"ok": true}

static func _input_bindings(players: Dictionary) -> Dictionary:
	var bindings: Dictionary = {}
	for profile_id in players:
		var player: Dictionary = players[profile_id]
		bindings[player["player_instance_id"]] = {"player_profile_id": profile_id, "peer_id": player["peer_id"]}
	return bindings

static func _revision(value: Variant) -> bool:
	return Inputs.integer(value) and value >= 0

static func _valid_aim(value: Variant) -> bool:
	if not value is Array or value.size() != 2:
		return false
	# Command accepts a double target, InputState stores a float32 Vector2, and
	# public_snapshot expands that vector back into numbers. Preserve this actual
	# representation limit rather than applying State's stricter position bound.
	var limit: float = absf(Vector2(Command.MAX_AIM, 0.0).x)
	return Inputs.number(value[0]) and Inputs.number(value[1]) and absf(float(value[0])) <= limit and absf(float(value[1])) <= limit

static func _tree_error(value: Variant, depth: int, budget: Dictionary) -> String:
	budget["nodes"] += 1
	if budget["nodes"] > MAX_TREE_NODES:
		return "ACTOR_CLIENT_PUBLIC_TREE_LIMIT"
	if depth > MAX_TREE_DEPTH:
		return "ACTOR_CLIENT_PUBLIC_TREE_INVALID"
	if value is Dictionary:
		for key in value:
			if not key is String:
				return "ACTOR_CLIENT_PUBLIC_TREE_INVALID"
			if key in PRIVATE_FIELDS:
				return "ACTOR_CLIENT_PRIVATE_FIELD_FORBIDDEN"
			var nested := _tree_error(value[key], depth + 1, budget)
			if not nested.is_empty():
				return nested
	elif value is Array:
		for child in value:
			var nested := _tree_error(child, depth + 1, budget)
			if not nested.is_empty():
				return nested
	elif typeof(value) not in [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING]:
		return "ACTOR_CLIENT_PUBLIC_TREE_INVALID"
	elif typeof(value) in [TYPE_INT, TYPE_FLOAT] and not Inputs.number(value):
		return "ACTOR_CLIENT_PUBLIC_NUMBER_INVALID"
	return ""

func _reject(code: String) -> Dictionary:
	last_error = code
	return {"ok": false, "code": code}
