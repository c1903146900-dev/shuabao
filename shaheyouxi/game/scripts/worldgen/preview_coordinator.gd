extends RefCounted
## Explicit server-side technical creation transaction; no public network RPC.
const Seed = preload("res://scripts/worldgen/world_seed.gd")
const Inputs = preload("res://scripts/worldgen/generation_inputs.gd")
const Generator = preload("res://scripts/worldgen/layout_generator.gd")
const Store = preload("res://scripts/worldgen/layout_store.gd")
const Validator = preload("res://scripts/worldgen/layout_validator.gd")
var generator: RefCounted
var store: RefCounted
var _inputs: RefCounted
var _options: Dictionary

func _init(input_document: Dictionary, options: Dictionary, directory: String = "user://generation_previews") -> void:
	_inputs = Inputs.new()
	_inputs.load_document(input_document)
	_options = options.duplicate(true)
	generator = Generator.new()
	store = Store.new(input_document, directory)

func create_preview(world_id: String, requested_seed: Variant, test_entry: bool, random_provider: Callable) -> Dictionary:
	if not _inputs.ready or not store.ready:
		return {"ok": false, "code": "PREVIEW_INPUTS_NOT_READY"}
	if not SandboxServerAuthority._valid_id(world_id, "world_"):
		return {"ok": false, "code": "INVALID_WORLD_ID"}
	if store.exists(world_id):
		return {"ok": false, "code": "PREVIEW_ALREADY_EXISTS"}
	var chosen: Dictionary = Seed.choose_for_server_creation(requested_seed, test_entry, random_provider)
	if not chosen["ok"]:
		return chosen
	var generated: Dictionary = generator.generate(world_id, chosen["value"], _inputs.data, _options)
	if not generated["ok"]:
		return generated # No file and no replacement seed after bounded failure.
	var saved: Dictionary = store.create(generated["plan"])
	if not saved["ok"]:
		return saved
	# Creation is acknowledged only after the selected seed and materialized core
	# have been committed together. No intermediate playable-world exposure.
	return {"ok": true, "plan": generated["plan"], "revision_sha256": saved["revision_sha256"], "formal_world_allowed": false}

func load_preview(world_id: String) -> Dictionary:
	# Intentionally no generator/random provider argument or fallback here.
	return store.load_existing(world_id)

func request_formal_world_publication(plan: Variant, world_id: String) -> Dictionary:
	var validator := Validator.new(_inputs.data)
	return validator.formal_publication_report(plan, world_id)
