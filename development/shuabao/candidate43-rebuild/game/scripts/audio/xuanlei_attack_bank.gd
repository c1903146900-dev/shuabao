extends RefCounted
## Three independently authored variants per action, not runtime pitch copies.
const IDS := ["xa_swing_1", "xa_swing_2", "xa_swing_3", "xa_dash_move", "xa_contact_1", "xa_contact_2", "xa_contact_3", "xa_dash_contact", "xa_guard_contact"]
const VARIANTS := ["a", "b", "c"]
const MAX_ATTACK_VOICES := 4 # Inside the ordinary pool; telegraph pool untouched.

static func load_streams() -> Dictionary:
	var streams: Dictionary = {}
	for id in IDS:
		var bank: Array[AudioStream] = []
		for variant in VARIANTS:
			var stream := load("res://assets/audio/%s_%s.wav" % [id, variant]) as AudioStream
			if stream != null: bank.append(stream)
		streams[id] = bank
	return streams
