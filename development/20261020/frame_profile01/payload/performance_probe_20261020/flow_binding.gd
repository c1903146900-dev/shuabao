extends RefCounted
const Gate = preload("res://yan_p3_reimplementation_20261018b/gate.gd")
const PATH = "res://tests/ink_first_floor_user_route_20261005/native_host01/flow_bridge.gd"
const BEFORE = "fccc171979663a6f556bf531c6ce8ba29de06ac24e35464eef45bd3bdec8842f"
const AFTER = "f4116bf367e312ffc6eac9cb9e75fff271611756c47cfdbb95378c1581a2d4fb"
const PREIMAGE = "res://yan_p3_reimplementation_20261018b/presentation_preimages/tests/ink_first_floor_user_route_20261005/native_host01/flow_bridge.gd"
static func accepts(path: String, expected: String, contract: Dictionary) -> bool:
 if path != PATH or expected != BEFORE or contract.get("files",{}).get(PATH,"") != BEFORE: return false
 var result: Dictionary = Gate.verify()
 if not bool(result.get("accepted",false)): return false
 var m: Variant = Gate.read(Gate.MANIFEST)
 if not m is Dictionary: return false
 var row: Dictionary = m.get("presentation_changes",{}).get(PATH,{})
 if row != {"map_scope":"source","before":BEFORE,"after":AFTER,"preimage":PREIMAGE}: return false
 return FileAccess.get_sha256(PREIMAGE) == BEFORE and FileAccess.get_sha256(PATH) == AFTER
