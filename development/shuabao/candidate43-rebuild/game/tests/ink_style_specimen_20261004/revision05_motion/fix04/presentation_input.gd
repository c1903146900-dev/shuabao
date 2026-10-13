extends RefCounted
## Read-only projection of existing adapter latches. No event submission, input
## rebinding, simulation reference retention or gameplay-state write.
static func capture(router: RefCounted, hero_position: Vector3, q_phase: String, ground: Vector3, active: bool) -> Dictionary:
	var physical:=bool(router.get("_left_physical"))
	var consumed:=bool(router.get("_gesture_consumed"))
	var suppressed:=bool(router.get("_suppress_held"))
	var direction:=Vector3.INF
	if ground.is_finite():
		var offset:=Vector3(ground.x-hero_position.x,0,ground.z-hero_position.z)
		if offset.length_squared()>.000001:direction=offset.normalized()
	return {"schema":"ink-view-received-input-1","held_basic":active and physical and not consumed and not suppressed and q_phase=="idle","physical_lmb":physical,"q_consumed":consumed,"suppressed":suppressed,"q_phase":q_phase,"manual_direction":direction,"source":"read-only received adapter latches plus event-coordinate camera projection"}
