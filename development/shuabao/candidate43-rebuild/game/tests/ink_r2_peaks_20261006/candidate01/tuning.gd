extends RefCounted
## Source-preserving base R2, plus one explicit UNBALANCED peak authoring table.
const Design = preload("res://data/final_design/catalog.gd")
const TABLE := "res://data/combat/ink_r2_peak_authoring.json"
const TABLE_SHA := "d11c59f5e7b680d61e8aacd7fa90a406820086c1cc74d59c97582cacb0862002"
const DECISION := "res://docs/source_decisions/20261006-ink-five-resolutions.json"
const DECISION_SHA := "861528d850389b2b4be2ce7a9ad4461531bbbfbd33de113870f9955b721f3e39"
const SOURCE_TOKENS := {"cast_range":"R2-1","domain_radius":"R2-2","duration":"R2-3","peak_body_duration":"R2-5","rollup_flat":"R2-10","rollup_ap_percent":"R2-11","cooldown":"R2-12"}

static func sources_match() -> bool:
 return FileAccess.get_sha256(TABLE) == TABLE_SHA and FileAccess.get_sha256(DECISION) == DECISION_SHA

static func values(rank: int) -> Dictionary:
 if rank < 1 or rank > 4 or not sources_match(): return {}
 var table = JSON.parse_string(FileAccess.get_file_as_string(TABLE))
 if not table is Dictionary: return {}
 var out: Dictionary = {"rank":rank,"balance_status":"authored_unbalanced"}
 for field: String in SOURCE_TOKENS:
  var original: float = Design.parameter("yanguizhou",str(SOURCE_TOKENS[field]),rank)
  if not is_finite(original) or original != float(table.retained_original[field][rank-1]): return {}
  out[field] = original
 out.peak_count = int(table.user_peak_counts[rank-1])
 for field: String in ["peak_radius","warning_duration","rise_to_hit_duration","hit_offset","hold_end_offset","disappear_offset"]:
  out[field] = float(table.authored_values[field])
 out.peak_flat = float(table.authored_values.peak_flat[rank-1])
 out.peak_ap_fraction = float(table.authored_values.peak_ap_fraction[rank-1])
 return out

static func warning_offset(values_at_cast: Dictionary, ordinal: int) -> float:
 return float(ordinal)*(float(values_at_cast.duration)-float(values_at_cast.disappear_offset))/float(int(values_at_cast.peak_count)-1)
