extends RefCounted
## Original source parameters only. No balance override or fixture progression.
const Design = preload("res://data/final_design/catalog.gd")
const HERO_ID := "yanguizhou"
const TOKENS := {"placement_range":"R1-1", "radius":"R1-2", "duration":"R1-3", "ordinary_reduction":"R1-4", "elite_reduction":"R1-5", "boss_reduction":"R1-6", "cooldown":"R1-7"}

static func values(rank: int) -> Dictionary:
 if rank < 1 or rank > 4: return {}
 var out: Dictionary = {"rank":rank}
 for field: String in TOKENS:
  out[field] = Design.parameter(HERO_ID, str(TOKENS[field]), rank)
  if not is_finite(float(out[field])): return {}
 for field: String in ["ordinary_reduction", "elite_reduction", "boss_reduction"]:
  out[field] = float(out[field]) * 0.01
 return out
