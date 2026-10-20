extends "res://scripts/integration/hero_entry.gd"
const FrameCPU = preload("res://performance_probe_20261020/frame_cpu.gd")
## Presentation attachment only. Original entry transaction and ordinary host stay intact.
const TrialUI = preload("res://yan_trial_ui_20261018/presenter.gd")
var _trial_ui = TrialUI.new()
const FrontHero = preload("res://yan_front_hero_20261018/controller.gd")
var _front_hero: Node3D
var front_hero_attachment: Dictionary = {}
# Explicit test-only presentation selection. No flag preserves the original path.
var _original_skin_baseline: bool = OS.get_cmdline_user_args().has("--test-original-skin-baseline")
var original_skin_baseline_receipt: Dictionary = {}
const SkillVisualController = preload("res://visual_rework_20261009/controller.gd")
signal worldfx_attached(controller: Node3D, receipt: Dictionary)
var _skill_visual_controller: Node3D
var worldfx_attachment_receipt: Dictionary = {}
var worldfx_attachment_error: String = ""
const CourtyardAttachment = preload("res://yan_cartoon_courtyard_20261018/attach.gd")
var _courtyard_attachment = CourtyardAttachment.new()
var courtyard_attachment_receipt: Dictionary = {}
var courtyard_detach_receipt: Dictionary = {}

func _ready() -> void:
	super()
	process_priority = 100

func _frame_cpu_body_process(_delta: float) -> void:
	_sync_courtyard_owner()
	if screen != Screen.RUN or active_hero != "yanguizhou" or not is_instance_valid(active_room): return
	if bool(active_room.get("_mainprep_required")) or bool(active_room.get("_mainprep_pending")): return
	# Original modal commits queue a deferred Host refresh after _process.
	# Queue display-only projection behind it, before this frame is drawn.
	_trial_ui.present.call_deferred(active_room, self)
	if not str(active_room.get("floor_error")).is_empty() or not str(active_room.get("startup_session_error")).is_empty(): return
	if bool(active_room.get("finished")): return
	var installation: Variant = active_room.get("ordinary_visual_installation")
	if not installation is Dictionary or not installation.get("accepted", false): return
	_ensure_skill_visuals()
	_ensure_front_hero()
	courtyard_attachment_receipt = _courtyard_attachment.ensure_for_host(active_room)

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

func _ensure_front_hero() -> void:
	_ensure_front_hero_2d()
	if not _original_skin_baseline: return
	if not is_instance_valid(_front_hero) or _front_hero.get_parent() != active_room:
		original_skin_baseline_receipt={"ready":false,"reason":"original_display_not_bound","art_acceptance":"NOT_REVIEWED"}
		return
	var display = _front_hero
	if bool(display.get("attached")):
		# Use the adapter's ownership-checked restoration, not raw skin writes.
		display.shutdown()
		display.set_process(false)
		front_hero_attachment={"accepted":false,"reason":"explicit_original_skin_baseline_test","native_combat_verified":false}
	var restored: Dictionary = display.get("receipt")
	var bindings: Array = display.get("skins")
	var errors: Array[String] = []
	if str(restored.get("reason", "")) != "shutdown" or not bool(restored.get("restoration_complete", false)):
		errors.append("adapter_shutdown_not_verified")
	if bool(display.get("attached")) or display.is_processing(): errors.append("adapter_still_active")
	var original_actor: Node = active_room.get("hero_view")
	if not is_instance_valid(original_actor) or display.get("actor") != original_actor:
		errors.append("original_actor_identity_changed")
	if bindings.size() != 9: errors.append("original_nine_skins_missing")
	for binding: Dictionary in bindings:
		var skin: Object = binding.get("node")
		if not is_instance_valid(skin):
			errors.append("original_skin_missing")
			continue
		if skin.get_parent() != binding.parent or skin.mesh != binding.mesh or skin.skin != binding.skin:
			errors.append("original_skin_identity_changed")
		if bool(binding.owned) or skin.layers != binding.layers: errors.append("original_skin_layers_not_restored")
	var source: Node = active_room.get("sim")
	var session: Object = active_room.get("shop_session")
	var actor_proof: Variant = original_actor.get("proof") if is_instance_valid(original_actor) else null
	var sample_report: Variant = original_actor.get("sample_report") if is_instance_valid(original_actor) else null
	var flow_ready: bool = bool(original_actor.get("flow_ready")) if is_instance_valid(original_actor) else false
	var original_player: Variant = original_actor.get("player") if is_instance_valid(original_actor) else null
	var original_skeleton: Variant = original_actor.get("skeleton") if is_instance_valid(original_actor) else null
	var proof_status: String = str(actor_proof.get("status", "HOLD")) if actor_proof is Dictionary else "HOLD"
	if proof_status == "HOLD": errors.append("original_actor_proof_HOLD_or_missing")
	if not flow_ready: errors.append("original_actor_flow_not_ready")
	if not is_instance_valid(original_player) or not original_player is AnimationPlayer:
		errors.append("original_animation_player_invalid")
	if not is_instance_valid(original_skeleton) or not original_skeleton is Skeleton3D:
		errors.append("original_skeleton_invalid")
	var reported_time: Variant = sample_report.get("source_time") if sample_report is Dictionary else null
	var source_time: Variant = source.get("hero_time") if is_instance_valid(source) else null
	var report_time_numeric: bool = typeof(reported_time) in [TYPE_INT, TYPE_FLOAT]
	var source_time_numeric: bool = typeof(source_time) in [TYPE_INT, TYPE_FLOAT]
	var source_clock_matches: bool = false
	if report_time_numeric and source_time_numeric:
		source_clock_matches = is_finite(float(reported_time)) and is_finite(float(source_time)) and float(reported_time) == float(source_time)
	if not source_clock_matches: errors.append("original_sample_source_clock_mismatch_or_missing")
	original_skin_baseline_receipt={
		"schema":"original-skin-baseline-test-1","ready":errors.is_empty(),"errors":errors,
		"selection":"original_3d_original_materials","test_flag":"--test-original-skin-baseline",
		"host_id":active_room.get_instance_id(),
		"actor_id":original_actor.get_instance_id() if is_instance_valid(original_actor) else -1,
		"source_id":source.get_instance_id() if is_instance_valid(source) else -1,
		"session_id":session.get_instance_id() if is_instance_valid(session) else -1,
		"readiness_only":true,"authority_equivalence_claim":false,
		"actor_proof_status":proof_status,"actor_flow_ready":flow_ready,
		"player_valid":is_instance_valid(original_player) and original_player is AnimationPlayer,
		"skeleton_valid":is_instance_valid(original_skeleton) and original_skeleton is Skeleton3D,
		"sample_source_time":reported_time,"sim_hero_time":source_time,"source_clock_matches":source_clock_matches,
		"room_id":source.get("room_id") if is_instance_valid(source) else null,
		"encounter_generation":source.get("encounter_generation") if is_instance_valid(source) else null,
		"adapter_shutdown":restored.duplicate(true),"skin_count":bindings.size(),
		"original_animation_consumer_retained":true,"material_overrides_written":false,
		"scope":"eight_direction_walk_stop_turn_basic_Q1_baseline_only",
		"status_and_form_visual_coverage":"NOT_TESTED_NOT_EQUIVALENCE_CLAIM",
		"native_combat_verified":false,"art_acceptance":"NOT_REVIEWED"
	}

func _ensure_front_hero_2d() -> void:
	var session: Object = active_room.get("shop_session")
	if not is_instance_valid(session) or str(session.get("status")) != "combat": return
	if is_instance_valid(_front_hero) and _front_hero.get_parent() == active_room: return
	var display = FrontHero.new()
	display.name = "FrontHero2DSample"
	active_room.add_child(display)
	var paths: Dictionary = {"left_identity":"res://yan_front_hero_20261018/left/identity_original.png","left_parts":"res://yan_front_hero_20261018/left/parts_original.png","back_identity":"res://yan_front_hero_20261018/back/identity_original.png","identity":"res://yan_front_hero_20261018/right/identity_original.png","right_parts":"res://yan_front_hero_20261018/right/parts_original.png","upper":"res://yan_front_hero_20261018/front/upper_q1_eight_original.png","lower":"res://yan_front_hero_20261018/front/lower_idle_walk_nine_original.png","parts":"res://yan_front_hero_20261018/front/neutral_parts_original.png"}
	var accepted: bool = display.attach_explicit(active_room,paths)
	front_hero_attachment={"accepted":accepted,"scope":"four_direction_idle_walk_basic_Q1_only","native_combat_verified":false}
	_front_hero=display
	if not accepted: display.set_process(false)

func _sync_courtyard_owner() -> void:
	var skin: Node3D = _courtyard_attachment.current_skin()
	if not is_instance_valid(skin): return
	if screen != Screen.RUN or active_hero != "yanguizhou" or not is_instance_valid(active_room) or skin.get_parent() != active_room.get("stage"):
		_detach_courtyard()

func _detach_courtyard() -> void:
	var skin: Node3D = _courtyard_attachment.current_skin()
	_courtyard_attachment.detach()
	if is_instance_valid(skin):
		courtyard_detach_receipt = (skin.get("receipt") as Dictionary).duplicate(true)
	courtyard_attachment_receipt = _courtyard_attachment.last_receipt.duplicate(true)

func _finish_open_chooser() -> void:
	# Restore before the original chooser takes its disabled-node snapshot.
	if screen == Screen.TRANSITION and is_instance_valid(active_room):
		_detach_courtyard()
	super()

func _launch_fresh(hero_id: String) -> void:
	# Drawing-only restoration; original admission/destruction stays in super.
	_detach_courtyard()
	await super(hero_id)

func _exit_tree() -> void:
	_detach_courtyard()

func _process(_delta: float) -> void:
 if not FrameCPU.active:
  _frame_cpu_body_process(_delta)
  return
 var profile_started: int = FrameCPU.begin("entry_process")
 _frame_cpu_body_process(_delta)
 FrameCPU.end("entry_process", profile_started)
