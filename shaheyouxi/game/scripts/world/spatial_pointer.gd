extends RefCounted
## Viewport-local input adapter; never reads or moves the OS desktop pointer.
const Address = preload("res://scripts/world/spatial_address.gd")
var _known: bool = false
var _position := Vector2.ZERO

func consume(event: InputEvent, viewport_size: Vector2) -> bool:
	if not event is InputEventMouseMotion and not event is InputEventMouseButton:
		return false
	var position: Vector2 = event.position
	if not position.is_finite() or not viewport_size.is_finite() or viewport_size.x <= 0 or viewport_size.y <= 0 or position.x < 0 or position.y < 0 or position.x >= viewport_size.x or position.y >= viewport_size.y:
		invalidate()
		return false
	_position = position
	_known = true
	return true

func invalidate() -> void:
	_known = false
	_position = Vector2.ZERO

func cell(origin: Vector2, cell_pixels: float) -> Dictionary:
	if not _known or not origin.is_finite() or not is_finite(cell_pixels) or cell_pixels <= 0:
		return {"ok": false, "code": "NO_VALID_POINTER"}
	return Address.cell_at((_position - origin) / cell_pixels)

func view() -> Dictionary:
	return {"known": _known, "position": _position}
