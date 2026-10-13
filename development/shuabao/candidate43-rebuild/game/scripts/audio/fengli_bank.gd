extends RefCounted
## Original independently excited Wave assets. Runtime never random-pitches cues.
const MOVEMENT_IDS := ["fw_cut_move", "fw_dash_move", "fw_dash", "fw_q1_release", "fw_q2_move", "fw_q3_release", "fw_e1_throw", "fw_e1_pierce", "fw_e2_spin", "fw_e2_spin_fast", "fw_e2_blink", "fw_r1_release", "fw_r2_throw"]
const CONTACT_IDS := ["fw_cut_contact", "fw_dash_contact", "fw_q1_contact", "fw_q2_contact", "fw_q3_contact", "fw_e1_contact", "fw_e1_pierce_contact", "fw_e2_contact", "fw_r1_contact", "fw_r2_contact", "fw_guard_contact"]
const STATUS_IDS := ["fw_e3_start", "fw_e3_end", "fw_r1_gather", "fw_passive_rescue", "fw_edge_growth"]
const IDS := MOVEMENT_IDS + CONTACT_IDS + STATUS_IDS
const MAX_HERO_VOICES := 4
const VARIANTS := ["a", "b", "c"]
static func load_streams() -> Dictionary:
	var out: Dictionary = {}
	for id in IDS:
		var bank: Array[AudioStream] = []
		for variant in VARIANTS:
			if id in STATUS_IDS and variant != "a": continue
			var stream := load("res://assets/audio/%s_%s.wav" % [id, variant]) as AudioStream
			if stream != null: bank.append(stream)
		out[id] = bank
	return out
