extends RefCounted
## Original Ink-only files. This resource never preloads other hero banks.
const ROOT := "res://tests/ink_benchmark_audio_20261004/wav/"
const MAX_VOICES := 4
const GAIN_DB := -6.0
const VARIANTS := 2
const IDS := ["ink_basic_release", "ink_basic_contact", "ink_basic_critical", "ink_shift_scatter", "ink_q1_release", "ink_q1_body", "ink_q1_contact"]
const DURATIONS := {"ink_basic_release":0.135, "ink_basic_contact":0.070, "ink_basic_critical":0.085, "ink_shift_scatter":0.180, "ink_q1_release":0.195, "ink_q1_body":0.275, "ink_q1_contact":0.125}
static func path_for(id: String, variant: int) -> String:
	if id not in IDS or variant < 0 or variant >= VARIANTS: return ""
	return ROOT + id + ("_a.wav" if variant == 0 else "_b.wav")
static func paths() -> Array:
	var result: Array = []
	for id in IDS:
		for index in VARIANTS: result.append(path_for(id, index))
	return result
