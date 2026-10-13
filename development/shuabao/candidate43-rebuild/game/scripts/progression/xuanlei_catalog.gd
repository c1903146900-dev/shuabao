extends RefCounted
## Compatibility entry point; all six heroes share the source-authoritative catalog.
const FinalDesign = preload("res://data/final_design/catalog.gd")
static func build(hero_id: String = "xuanlei") -> Dictionary:
	return FinalDesign.build_progression(hero_id)
