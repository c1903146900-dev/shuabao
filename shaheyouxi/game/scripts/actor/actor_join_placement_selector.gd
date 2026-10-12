extends RefCounted
## Read-only selection over an already validated authoritative component.
## This preserves the original Controller's five-anchor order and actual native
## full-body/known-region/peer checks; it never creates a profile, actor or cell.
const Address = preload("res://scripts/world/spatial_address.gd")
const State = preload("res://scripts/actor/actor_state.gd")

static func choose_new(component: Dictionary, actor_id: String, space: RefCounted) -> Dictionary:
	for index in range(5):
		for instance in component["prefab_instances"]:
			for anchor in instance["anchors"]:
				if anchor["local_id"] != "actor_spawn_%d" % index or anchor["kind"] != "spawn":
					continue
				var cell: Array = anchor["cell"]
				var position := Address.cell_center(Vector2i(int(cell[0]), int(cell[1])))
				var checked: Dictionary = space.check_actor_placement(actor_id, anchor["layer"], position)
				if checked.get("ok", false):
					return {"ok": true, "layer": anchor["layer"].duplicate(true), "position": position}
	return State.error("ACTOR_TECHNICAL_SPAWN_UNAVAILABLE", "request")
