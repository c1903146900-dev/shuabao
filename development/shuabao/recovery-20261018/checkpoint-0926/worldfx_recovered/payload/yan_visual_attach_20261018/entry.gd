extends "res://scripts/integration/hero_entry.gd"
## Presentation attachment only. Original entry transaction and ordinary host stay intact.
const SkillVisualController = preload("res://visual_rework_20261009/controller.gd")
signal worldfx_attached(controller: Node3D, receipt: Dictionary)
var _skill_visual_controller: Node3D
var worldfx_attachment_receipt: Dictionary = {}
var worldfx_attachment_error: String = ""

func _ready() -> void:
	super()
	process_priority = 100

func _process(_delta: float) -> void:
	if screen != Screen.RUN or active_hero != "yanguizhou" or not is_instance_valid(active_room): return
	if bool(active_room.get("_mainprep_required")) or bool(active_room.get("_mainprep_pending")): return
	if not str(active_room.get("floor_error")).is_empty() or not str(active_room.get("startup_session_error")).is_empty(): return
	if bool(active_room.get("finished")): return
	var installation: Variant = active_room.get("ordinary_visual_installation")
	if not installation is Dictionary or not installation.get("accepted", false): return
	_ensure_skill_visuals()
	# The reviewed UI presenter may be called here each frame in a later combined candidate.
	# No hero2D is attached: its accepted asset package does not exist yet.

func _ensure_skill_visuals() -> void:
	if is_instance_valid(_skill_visual_controller) and _skill_visual_controller.get_parent() == active_room: return
	var source: Node = active_room.get("sim")
	if not is_instance_valid(source) or not source.has_signal("combat_event"):
		worldfx_attachment_error = "existing_source_signal_unavailable"
		return
	var controller = SkillVisualController.new()
	controller.name = "InkSkillVisuals"
	controller.attach_to_host(active_room)
	active_room.add_child(controller)
	# _ready has built empty views. Bind the existing sink synchronously, without
	# invoking _process, snapshots, previews, present_source, or any Sim operation.
	controller.source = source
	var sink: Callable = Callable(controller, "_event")
	var error: Error = source.connect("combat_event", sink)
	if error != OK:
		worldfx_attachment_error = "source_listener_connect_failed:%s" % error
		controller.free()
		return
	_skill_visual_controller = controller
	worldfx_attachment_error = ""
	worldfx_attachment_receipt = {
		"host_id": active_room.get_instance_id(), "source_id": source.get_instance_id(),
		"controller_id": controller.get_instance_id(), "source_script": source.get_script().resource_path,
		"controller_script": controller.get_script().resource_path,
		"connected_before_yield": source.is_connected("combat_event", sink),
		"observed_events_at_attach": controller.observed_events,
		"phase_at_attach": str(source.get("phase")), "hero_time_at_attach": source.get("hero_time"),
		"event_branch_coverage": "NOT_OBSERVED", "art_acceptance": "NOT_REVIEWED"
	}
	worldfx_attached.emit(controller, worldfx_attachment_receipt.duplicate(true))
