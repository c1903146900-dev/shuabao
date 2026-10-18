extends RefCounted
## REIMPLEMENTATION: detached input bridge, no source setters or presentation calls.
## Call bind_explicit only at initial attach or a confirmed normal room lifecycle.
var _source: WeakRef
var _hero: WeakRef
var _clock: WeakRef
var _domain: WeakRef
var _scope: Array = []
var _events: Array = []
var _overflow := false

func bind_explicit(source: Node) -> bool:
    close()
    if not is_instance_valid(source) or source.is_queued_for_deletion():
        return false
    if not source.has_method("ink_presenter_snapshot") or not source.has_signal("combat_event"):
        return false
    var hero: Object = source.get("hero")
    if not is_instance_valid(hero):
        return false
    var clock: Object = source.get("clock")
    if not is_instance_valid(clock):
        return false
    var domain: Object = clock.get("domain")
    _clock = weakref(clock)
    _domain = weakref(domain) if is_instance_valid(domain) else null
    _source = weakref(source)
    _hero = weakref(hero)
    _scope = [source.get_instance_id(), hero.get_instance_id(), source.get("room_id"), source.get("encounter_generation")]
    source.connect("combat_event", Callable(self, "_receive"))
    return true

func close() -> void:
    var source: Object = _source.get_ref() if _source != null else null
    if is_instance_valid(source) and source.is_connected("combat_event", Callable(self, "_receive")):
        source.disconnect("combat_event", Callable(self, "_receive"))
    _source = null
    _hero = null
    _clock = null
    _domain = null
    _scope.clear()
    _events.clear()
    _overflow = false

func _receive(event: Dictionary) -> void:
    var source: Object = _source.get_ref() if _source != null else null
    if not is_instance_valid(source):
        return
    if _events.size() >= 128:
        _overflow = true
        return
    var copy: Dictionary = event.duplicate(true)
    copy["observed_source_time"] = source.get("hero_time")
    _events.append(copy)

func read_frame() -> Dictionary:
    var source: Node = _source.get_ref() if _source != null else null
    var hero: Object = _hero.get_ref() if _hero != null else null
    if not is_instance_valid(source) or source.is_queued_for_deletion() or not is_instance_valid(hero):
        return {"fault":"source_lifetime_ended"}
    if not is_same(source.get("hero"), hero) or _scope != [source.get_instance_id(), hero.get_instance_id(), source.get("room_id"), source.get("encounter_generation")]:
        return {"fault":"scope_changed_explicit_rebind_required"}
    if _overflow:
        return {"fault":"event_buffer_overflow"}
    var clock: Object = source.get("clock")
    if not is_instance_valid(clock) or _clock == null or not is_same(clock, _clock.get_ref()):
        return {"fault":"clock_changed_explicit_rebind_required"}
    var bound_domain: Object = _domain.get_ref() if _domain != null else null
    if not is_same(clock.get("domain"), bound_domain):
        return {"fault":"domain_changed_explicit_rebind_required"}
    var raw_snapshot: Variant = source.ink_presenter_snapshot()
    if not raw_snapshot is Dictionary:
        return {"fault":"invalid_source_snapshot"}
    var snapshot: Dictionary = raw_snapshot
    var shown: Dictionary = snapshot.get("ultimate_presentation", {})
    var ultimate: Dictionary = {"active":false}
    if bool(shown.get("active", false)):
        var domain: Object = clock.get("domain")
        if not is_instance_valid(domain) or not domain.has_method("snapshot") or not domain.has_method("is_invulnerable"):
            return {"fault":"ultimate_domain_unavailable"}
        var domain_state: Dictionary = domain.snapshot()
        var token: Dictionary = shown.get("token", {})
        var current: Dictionary = source.get("_current_show")
        var record: Dictionary = domain_state.get("presentations", {}).get(hero.get("actor_id"), {})
        var start: float = float(current.get("start", -1.0))
        var duration: float = float(current.get("end", -1.0)) - start
        var live: bool = current.get("token", {}) == token and record.get("token", {}) == token and not bool(current.get("cancelled", false)) and float(record.get("expires_at", -2.0)) == float(current.get("end", -1.0)) and domain.is_invulnerable(token)
        ultimate = {"active":true, "token":token.duplicate(true), "actor_time":shown.get("actor_motion_time"), "elapsed":float(domain_state.get("active_real_time", -1.0))-start, "duration":duration, "live":live}
    var frame: Dictionary = {
        "scope":_scope.duplicate(), "source_time":source.get("hero_time"),
        "world_time":clock.get("world_time"), "paused":source.get("paused"),
        "hero":{"actor_id":hero.get("actor_id"), "position":_xyz(hero.get("position")),
            "facing":_xyz(hero.get("facing")), "move_intent":_xyz(hero.get("move_intent")),
            "dash_left":hero.get("dash_left"), "stun_left":hero.get("stun_left"), "knockback":_xyz(hero.get("knockback")), "dead":hero.get("dead")},
        "snapshot":snapshot.duplicate(true), "ultimate":ultimate, "events":_events.duplicate(true)
    }
    _events.clear()
    return frame

func _xyz(value: Vector3) -> Array:
    return [value.x, value.y, value.z]
