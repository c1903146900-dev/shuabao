extends RefCounted
## NEW Q3 authored candidate. Existing approved BASIC/Q1/dash bank is untouched.
const ROOT := "res://tests/ink_composed_audio_fix01_20261005/wav/"
const IDS := ["ink_q3_raise","ink_q3_collapse","ink_q3_contact"]
const VARIANTS := 2
const DURATIONS := {"ink_q3_raise":.210,"ink_q3_collapse":.240,"ink_q3_contact":.095}
static func path_for(id: String,variant: int) -> String:
 if id not in IDS or variant<0 or variant>=VARIANTS: return ""
 return ROOT+id+("_a.wav" if variant==0 else "_b.wav")
static func paths() -> Array:
 var result: Array = []
 for id: String in IDS:
  for variant in VARIANTS: result.append(path_for(id,variant))
 return result
