extends "res://tests/ink_style_specimen_20261004/revision05_motion/fix02/hero_view.gd"
## Detached release schema uses front_direction. Never fabricate a default aim.
var proven_direction:=Vector3.INF
var direction_diagnostics: Array=[]
var valid_release_direction_count:=0
func _valid_direction(value: Variant) -> bool:
	return value is Vector3 and value.is_finite() and Vector3(value.x,0,value.z).length_squared()>.000001
func receive(event: Dictionary, source_time: float) -> void:
	var release: bool=str(event.get("kind","")) in ["ink_basic_released","ink_q1_released"]
	var prior: Vector3=proven_direction
	super.receive(event,source_time)
	if not release:return
	var candidate: Variant=event.get("front_direction",null)
	if _valid_direction(candidate):
		proven_direction=Vector3(candidate.x,0,candidate.z).normalized()
		event_direction=proven_direction
		valid_release_direction_count+=1
	else:
		var retained:=_valid_direction(prior)
		direction_diagnostics.append({"kind":event.get("kind",""),"wave_id":event.get("wave_id",""),"source_time":source_time,"reason":"missing_or_invalid_public_front_direction","legacy_direction_field_ignored":event.has("direction"),"retained_previous_proven_direction":retained,"action":"keep_previous_proven_direction" if retained else "suppress_unoriented_upper_action"})
		if retained:event_direction=prior
		else:event_action="";event_at=-1.0
	proof["direction_schema_diagnostics"]=direction_diagnostics.duplicate(true)
func present(ink: Dictionary) -> void:
	if not _valid_direction(proven_direction):
		var hero: Dictionary=ink.get("hero",{})
		var initial: Variant=hero.get("facing",null)
		if _valid_direction(initial):
			proven_direction=Vector3(initial.x,0,initial.z).normalized()
			event_direction=proven_direction
	super.present(ink)
	# A valid detached preview also becomes a proven last aim for malformed input.
	if str(sample_report.get("upper","")).begins_with("q1_") and str(ink.get("input",{}).get("phase","")) in ["drawing","frozen"]:
		var preview: Variant=sample_report.get("direction_plan",{}).get("aim_direction",null)
		if _valid_direction(preview):proven_direction=preview
	sample_report["motion_revision"]="revision05_motion_fix03_glb03"
	sample_report["public_release_direction_field"]="front_direction"
	sample_report["valid_release_direction_count"]=valid_release_direction_count
	sample_report["direction_diagnostic_count"]=direction_diagnostics.size()
	sample_report["last_direction_diagnostic"]=direction_diagnostics.back() if not direction_diagnostics.is_empty() else {}
