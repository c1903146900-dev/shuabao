extends RefCounted
## Explicit opt-in layout adapter. No source/clock/damage/stat/progression writes.
const PATH := "res://tests/ink_first_floor_room_art_20261004/room_layout.json"
static func definition() -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return value if value is Dictionary else {}
static func obstacle_array() -> Array:
	var result: Array = []
	var data: Dictionary = definition()
	for row: Dictionary in data.get("obstacles",[]):
		var p: Array = row.position
		var h: Array = row.half
		result.append({"position":Vector3(float(p[0]),0.0,float(p[2])),"half":Vector3(float(h[0]),0.0,float(h[2]))})
	return result
static func bind_to_sim(sim: Node) -> Dictionary:
	var data: Dictionary = definition()
	assert(not data.is_empty(),"Forecourt layout unavailable; refuse implicit old-room fallback")
	sim.arena_half_extent = float(data.arena_half_extent)
	sim.obstacles = obstacle_array()
	return {"layout_revision":data.revision,"layout_sha256":FileAccess.get_sha256(PATH),"arena_half_extent":sim.arena_half_extent,"obstacle_count":sim.obstacles.size(),"only_sim_writes":["arena_half_extent","obstacles"],"engine_collision_gate_passed":false}
