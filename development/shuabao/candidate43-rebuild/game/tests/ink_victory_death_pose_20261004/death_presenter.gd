extends RefCounted
## A post-present overlay for the one original minion already selected by host.
## No model replacement, actor spawn, source step, collision, reward or AI writes.
const DeathClock = preload("res://tests/ink_victory_death_pose_20261004/death_clock.gd")
var clock: RefCounted = DeathClock.new()
var report: Dictionary = {}
var bar_view_id: int = -1
var bars: Array[MeshInstance3D] = []

func clear() -> void:
	clock.clear(); report.clear(); bars.clear(); bar_view_id = -1

func _bind_bars(view: Node3D) -> void:
	if bar_view_id == view.get_instance_id(): return
	bars.clear(); bar_view_id = view.get_instance_id()
	# The original presenter owns exactly these two direct QuadMesh children.
	# Imported body meshes are descendants of its separate body scene and untouched.
	for child: Node in view.get_children():
		if not child is MeshInstance3D or not child.mesh is QuadMesh: continue
		var size: Vector2 = child.mesh.size
		if child.position.is_equal_approx(Vector3(0, 1.42, 0)) and is_equal_approx(size.x, 0.95) and (is_equal_approx(size.y, 0.075) or is_equal_approx(size.y, 0.115)):
			bars.append(child)

func apply(view: Node3D, state: Dictionary, source_time: float,
		context: Dictionary, blocked: bool) -> Dictionary:
	if not is_instance_valid(view) or state.is_empty():
		clear(); return report
	_bind_bars(view)
	if not bool(state.get("dead", false)):
		clock.clear()
		for bar: MeshInstance3D in bars:
			if is_instance_valid(bar): bar.visible = true
		report = {"status": "living_delegated_unchanged", "source_state_modified": false}
		return report
	for bar: MeshInstance3D in bars:
		if is_instance_valid(bar): bar.visible = false
	if view.player == null or view.skeleton == null or not view.clips.has("death"):
		report = {"status": "HOLD_missing_original_death", "health_bars_hidden": bars.size() == 2}
		return report
	var animation: Animation = view.player.get_animation(view.clips["death"])
	var native_age: float = maxf(0.0, source_time - float(view.dead_at)) if float(view.dead_at) >= 0.0 else 0.0
	var identity: Dictionary = {"instance_id": context.get("instance_id", -1),
		"scope": context.get("scope", {}).duplicate(true), "reset_serial": context.get("reset_serial", -1),
		"view_id": view.get_instance_id(), "target_id": str(state.get("actor_id", "")),
		"target_generation": state.get("generation", -1)}
	report = clock.sample(identity, source_time, native_age, context, blocked, float(view.last_contact), animation.length)
	if report.get("status", "").begins_with("HOLD"): return report
	if bool(report.pose_override):
		# Same imported player/skeleton/clip; only finish the already-dead pose.
		view.skeleton.reset_bone_poses()
		view.player.play(view.clips["death"])
		view.player.seek(float(report.death_pose_time), true)
	var brightness: float = 1.0 + float(report.hit_flash)
	for index in range(view.materials.size()):
		view.materials[index].albedo_color = view.base_colors[index] * Color(brightness, brightness, brightness, 1.0)
	report["health_bar_count"] = bars.size()
	report["health_bars_hidden"] = bars.size() == 2 and bars.all(func(bar: MeshInstance3D) -> bool: return is_instance_valid(bar) and not bar.visible)
	report["actual_animation_position"] = view.player.current_animation_position
	report["body_bone"] = _body_sample(view.skeleton)
	report["base_palette_restored"] = float(report.hit_flash) == 0.0
	return report

func _body_sample(skeleton: Skeleton3D) -> Dictionary:
	var index: int = skeleton.find_bone("body")
	if index < 0: return {}
	var pose: Transform3D = skeleton.get_bone_pose(index)
	var rotation: Quaternion = pose.basis.get_rotation_quaternion()
	return {"local_origin": [pose.origin.x, pose.origin.y, pose.origin.z], "local_quaternion": [rotation.x, rotation.y, rotation.z, rotation.w]}

func present_host(host: Node) -> void:
	if host.sim == null or not is_instance_valid(host.enemy_view):
		clear(); return
	var state: Dictionary = {}
	for candidate: Dictionary in host.last_presented_full.get("enemies", []):
		if str(candidate.get("actor_id", "")) == str(host.shown_enemy_id):
			state = candidate; break
	var context: Dictionary = host._safe_presentation_context()
	var raw: Dictionary = host._safe_clock_state7()
	var matching: bool = context.get("scope", {}) == host.last_presented_ink.get("scope", {})
	var blocked: bool = not matching or bool(raw.get("paused", true)) or bool(raw.get("dead", true)) or bool(raw.get("loading", true)) or bool(raw.get("finished", true)) or bool(raw.get("shop_open", true))
	apply(host.enemy_view, state, float(host.last_presented_ink.get("source_time", 0.0)), context, blocked)
	# Diagnostic-only nested field is copied by the existing F8 capture path.
	# It does not edit full/ink source snapshots or pretend to be hero motion.
	if is_instance_valid(host.hero_view):
		host.hero_view.sample_report["enemy_death_pose"] = report.duplicate(true)
