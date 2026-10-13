extends RefCounted
## World-foot TARGET planner only. No Node, simulation, pose, heading or IK writes.
## Neutral targets must already be in the caller's captured lower world frame.
## Caller must validate BOTH legs at each sample with a shared feasible pelvis
## drop and unstretched two-link solves before applying anything. If infeasible,
## hold the last APPLIED pose/targets and diagnose; planner completion is not pose
## acceptance. In particular, elapsed time must not override a failed reach gate.

const SIDES := ["L", "R"]
const LAND_SECONDS := 0.14
const RECOVER_SECONDS := 0.18
const BODY_IDLE_SECONDS := 0.16
const GROUNDED_TOLERANCE_M := 0.015
const RECOVER_CLEARANCE_M := 0.05
const MAX_DURATION_SECONDS := 0.80

var _active: bool = false
var _start_time: float = 0.0
var _last_time: float = 0.0
var _duration: float = 0.0
var _initial: Dictionary = {}
var _neutral: Dictionary = {}
var _stages: Array = []
var _landing_count: int = 0
var _last_good: Dictionary = {}


func begin(now: float, feet: Dictionary, neutral: Dictionary, preferred_side: String) -> Dictionary:
	if not is_finite(now):
		return _hold("invalid_clock")
	if _active and now < _last_time:
		return _hold("clock_regression")
	if preferred_side != "L" and preferred_side != "R":
		return _hold("preferred_side_must_be_L_or_R")
	if not _valid_feet(feet) or not _valid_feet(neutral):
		return _hold("two_finite_world_Vector3_targets_required")
	# Reject clocks whose numeric precision cannot represent the shortest stage.
	if not is_finite(now + MAX_DURATION_SECONDS) or now + LAND_SECONDS <= now:
		return _hold("clock_cannot_represent_stage_duration")

	cancel()
	_start_time = now
	_last_time = now
	_initial = {"L": feet["L"], "R": feet["R"]}
	_neutral = {"L": neutral["L"], "R": neutral["R"]}
	var working: Dictionary = _initial.duplicate(true)
	var airborne: Array = []
	for side: String in SIDES:
		var foot: Vector3 = _initial[side]
		var rest: Vector3 = _neutral[side]
		if foot.y > rest.y + GROUNDED_TOLERANCE_M:
			airborne.append(side)
	# Actual height above that foot's ground wins; the preference breaks ties.
	if airborne.size() == 2:
		var left: Vector3 = _initial["L"]
		var right: Vector3 = _initial["R"]
		var left_rest: Vector3 = _neutral["L"]
		var right_rest: Vector3 = _neutral["R"]
		var left_height: float = left.y - left_rest.y
		var right_height: float = right.y - right_rest.y
		if right_height < left_height or (right_height == left_height and preferred_side == "R"):
			airborne = ["R", "L"]
	_landing_count = airborne.size()
	for side: String in airborne:
		var foot: Vector3 = working[side]
		var rest: Vector3 = _neutral[side]
		# Preserve captured x/z literally, even at the end of descent.
		_append_stage("landing", side, working, Vector3(foot.x, rest.y, foot.z), LAND_SECONDS)

	# Keep existing support anchored while recovering the other foot first.
	# With two airborne feet, keep the first landed foot anchored first.
	var recover_first: String = preferred_side
	if not airborne.is_empty():
		recover_first = airborne.back()
	var recover_second: String = "R" if recover_first == "L" else "L"
	for side: String in [recover_first, recover_second]:
		if working[side] != _neutral[side]:
			_append_stage("recovery", side, working, _neutral[side], RECOVER_SECONDS)
	_append_stage("body_idle", "", working, Vector3.ZERO, BODY_IDLE_SECONDS)
	if not is_finite(_duration) or _duration <= 0.0 or _duration > MAX_DURATION_SECONDS + 0.000001:
		cancel()
		return _hold("invalid_plan_duration")
	_active = true
	_last_good = _evaluate(now)
	var admission: Dictionary = _last_good.duplicate(true)
	admission["admitted"] = true
	return admission


func sample(now: float) -> Dictionary:
	if not _active:
		return _hold("no_active_plan")
	if not is_finite(now):
		return _hold("invalid_clock")
	if now < _last_time:
		return _hold("clock_regression")
	if not is_finite(now - _start_time):
		return _hold("invalid_elapsed_time")
	# Sampling a repeated source timestamp has no render-count side effect.
	if now == _last_time:
		return _last_good.duplicate(true)
	var candidate: Dictionary = _evaluate(now)
	if not _valid_feet(candidate["feet"]):
		return _hold("nonfinite_interpolated_target")
	_last_good = candidate
	_last_time = now
	return _last_good.duplicate(true)


func cancel() -> void:
	_active = false
	_start_time = 0.0
	_last_time = 0.0
	_duration = 0.0
	_initial.clear()
	_neutral.clear()
	_stages.clear()
	_landing_count = 0
	_last_good.clear()


func _valid_feet(feet: Dictionary) -> bool:
	for side: String in SIDES:
		if not feet.has(side) or typeof(feet[side]) != TYPE_VECTOR3:
			return false
		var foot: Vector3 = feet[side]
		if not foot.is_finite():
			return false
	return true


func _append_stage(phase: String, side: String, working: Dictionary, target: Vector3, seconds: float) -> void:
	var before: Dictionary = working.duplicate(true)
	if side != "":
		working[side] = target
	_stages.append({"phase": phase, "side": side, "start": _duration,
		"duration": seconds, "before": before, "after": working.duplicate(true)})
	_duration += seconds


func _evaluate(now: float) -> Dictionary:
	var elapsed: float = now - _start_time
	var result: Dictionary = {
		"accepted": true, "status": "targets_only", "hold": false,
		"feet": _neutral.duplicate(true), "phase": "finished", "phase_fraction": 1.0,
		"body_idle_weight": 1.0, "finished": true, "moving_side": "",
		"current_moving_foot": "", "landing_count": _landing_count,
		"elapsed_seconds": elapsed, "duration_seconds": _duration,
		"requires_reach_and_two_link_solve": true,
		"scope": "planned_world_targets_only",
		"meaningful_stepped_turn_pending": true
	}
	for stage: Dictionary in _stages:
		var start: float = stage["start"]
		var seconds: float = stage["duration"]
		if elapsed >= start + seconds:
			continue
		var fraction: float = clampf((elapsed - start) / seconds, 0.0, 1.0)
		var smooth: float = fraction * fraction * (3.0 - 2.0 * fraction)
		var side: String = stage["side"]
		var phase: String = stage["phase"]
		var targets: Dictionary = stage["before"].duplicate(true)
		if side != "" and fraction > 0.0:
			var first: Vector3 = stage["before"][side]
			var last: Vector3 = stage["after"][side]
			if phase == "landing":
				targets[side] = Vector3(first.x, lerpf(first.y, last.y, smooth), first.z)
			else:
				var target: Vector3 = first.lerp(last, smooth)
				# Zero endpoint velocity; maximum target height stays <= neutral+.05,
				# including an already-grounded capture up to .015 above neutral.
				var clearance: float = maxf(0.0, RECOVER_CLEARANCE_M - maxf(0.0, first.y - last.y))
				var bump: float = 16.0 * fraction * fraction * (1.0 - fraction) * (1.0 - fraction)
				target.y += clearance * bump
				targets[side] = target
		result["feet"] = targets
		result["phase"] = phase
		result["phase_fraction"] = fraction
		result["body_idle_weight"] = smooth if phase == "body_idle" else 0.0
		result["finished"] = false
		result["moving_side"] = side
		result["current_moving_foot"] = side
		break
	# No lerp, snapping, grounding or normalization is allowed at admission time.
	if now == _start_time:
		result["feet"] = _initial.duplicate(true)
	return result


func _hold(reason: String) -> Dictionary:
	# These are the last valid PLANNED targets, never a claim about applied pose.
	# With no admitted plan, an empty dictionary prevents invented fallback feet.
	var result: Dictionary = _last_good.duplicate(true)
	if result.is_empty():
		result = {"feet": {}, "phase": "hold", "phase_fraction": 0.0,
			"body_idle_weight": 0.0, "finished": false, "moving_side": "",
			"current_moving_foot": "", "scope": "planned_world_targets_only"}
	result["accepted"] = false
	result["admitted"] = false
	result["hold"] = true
	result["status"] = "hold"
	result["reason"] = reason
	result["active_plan_retained"] = _active
	result["requires_reach_and_two_link_solve"] = true
	return result
