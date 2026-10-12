extends RefCounted
## Renderer cache only. Never contributes occupancy, physics, RPC or save fields.
const Address = preload("res://scripts/world/spatial_address.gd")
var _capacity: int
var _cells: Dictionary = {}

func _init(max_per_cell: int) -> void:
	_capacity = max_per_cell

func add(layer: Dictionary, cell: Vector2i, visual_reference: String) -> bool:
	if _capacity < 1 or not Address.valid_layer(layer) or visual_reference.is_empty():
		return false
	var cache_key := Address.key(layer) + "|" + Address.cell_key(cell)
	var current: Array = _cells.get(cache_key, [])
	if current.size() >= _capacity:
		return false
	current.append(visual_reference)
	_cells[cache_key] = current
	return true

func at(layer: Dictionary, cell: Vector2i) -> Array:
	return _cells.get(Address.key(layer) + "|" + Address.cell_key(cell), []).duplicate()

func clear() -> void:
	_cells.clear()
