extends RefCounted
## Viewport-local event coordinates, not a target or a cached world position.
var position:=Vector2.INF
var viewport_size:=Vector2.ZERO
var valid:=false
var focused:=true
var provenance:="not_seeded"
var event_count:=0
var invalid_reason:=""
func seed_initial(point: Vector2, size: Vector2) -> void:
	viewport_size=size
	if accepts(point):position=point;valid=true;provenance="initial_viewport_seed_once";invalid_reason=""
	else:invalidate("invalid_initial_pointer")
func accepts(point: Vector2) -> bool:
	return focused and point.is_finite() and viewport_size.x>0 and viewport_size.y>0 and Rect2(Vector2.ZERO,viewport_size).has_point(point)
func observe(event: InputEvent, size: Vector2) -> bool:
	if not event is InputEventMouse:return false
	viewport_size=size
	event_count+=1
	if not accepts(event.position):invalidate("mouse_event_outside_or_unfocused");return false
	position=event.position;valid=true;provenance="InputEventMouse.position";invalid_reason=""
	return true
func invalidate(reason: String) -> void:
	valid=false;invalid_reason=reason
func lose_focus() -> void:
	focused=false;invalidate("focus_lost")
func gain_focus() -> void:
	focused=true;invalidate("fresh_mouse_event_required_after_focus")
func resize(size: Vector2) -> void:
	viewport_size=size;invalidate("fresh_mouse_event_required_after_resize")
func report() -> Dictionary:
	return {"position":position,"viewport_size":viewport_size,"valid":valid,"focused":focused,"provenance":provenance,"event_count":event_count,"invalid_reason":invalid_reason,"space":"viewport-local logical coordinates, exactly as InputEventMouse.position"}
