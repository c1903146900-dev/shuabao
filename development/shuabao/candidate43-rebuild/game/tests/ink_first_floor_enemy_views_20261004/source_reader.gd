extends RefCounted
## Only this read boundary sees source dictionaries. Views receive detached data.
## Bind before stepping and call observe_event directly at the original signal.
## Never replay event_log or rebind historical ink receipts by current actor_id.
const MAX_ACTORS := 6 # Current candidate authoring bound, not engine capacity.
var _scope: Dictionary = {}
var _epoch := 0
var _serial := 0
var _token_serial := 0
var _bindings: Dictionary = {}
var _seen_ids: Dictionary = {}
var _contacts: Dictionary = {}
var _deaths: Dictionary = {}
var last_status := "unbound"

func _synchronize(source: Node) -> bool:
	var next := {"source_instance":source.get_instance_id(), "room_id":str(source.room_id), "generation":int(source.encounter_generation)}
	if next != _scope:
		_scope = next; _epoch += 1
		_bindings.clear(); _seen_ids.clear(); _contacts.clear(); _deaths.clear()
	if source.enemies.size() > MAX_ACTORS:
		last_status = "HOLD_candidate_roster_exceeds_six"; return false
	var present: Dictionary = {}
	for actor: Dictionary in source.enemies:
		var id := str(actor.get("actor_id", ""))
		if id.is_empty() or present.has(id) or str(actor.get("room_id", "")) != _scope.room_id or int(actor.get("generation", -1)) != _scope.generation:
			last_status = "HOLD_invalid_source_actor_binding"; return false
		present[id] = true
		if not _bindings.has(id) or not is_same(_bindings[id].actor, actor):
			if _bindings.has(id):
				_contacts.erase(_bindings[id].token); _deaths.erase(_bindings[id].token)
			_token_serial += 1
			_bindings[id] = {"actor":actor, "token":"%d:%d:%d" % [get_instance_id(), _epoch, _token_serial], "born_sequence":int(source.sequence), "reused":_seen_ids.has(id)}
			_seen_ids[id] = true
	for id: String in _bindings.keys():
		if not present.has(id):
			_contacts.erase(_bindings[id].token); _deaths.erase(_bindings[id].token); _bindings.erase(id)
	last_status = "ready"; return true

func observe_event(source: Node, event: Dictionary) -> Dictionary:
	# The original synchronous callback is the provenance boundary. Old/replayed
	# sequences and id-reuse without a source identity field fail closed for cues.
	if not _synchronize(source): return {"accepted":false,"reason":last_status}
	if str(event.get("room_id", "")) != _scope.room_id or int(event.get("generation", -1)) != _scope.generation or int(event.get("sequence", -1)) != int(source.sequence):
		return {"accepted":false,"reason":"stale_or_not_original_callback"}
	var id := str(event.get("target_id", event.get("target", "")))
	if not _bindings.has(id): return {"accepted":false,"reason":"not_targeted_enemy_event"}
	var binding: Dictionary = _bindings[id]
	if binding.reused or int(event.sequence) <= int(binding.born_sequence):
		return {"accepted":false,"reason":"actor_identity_provenance_absent"}
	var token := str(binding.token)
	if event.get("kind", "") == "kill":
		_deaths[token] = float(event.world_time)
		return {"accepted":true,"token":token,"kind":"death_observed"}
	if event.get("kind", "") not in ["damage", "ink_q1_contact", "ink_basic_contact"]:
		return {"accepted":false,"reason":"not_contact"}
	var damage := float(event.get("actual_damage", event.get("amount", 0.0)))
	if damage <= 0.0: return {"accepted":false,"reason":"no_actual_damage"}
	if _contacts.has(token) and int(_contacts[token].sequence) >= int(event.sequence):
		return {"accepted":false,"reason":"duplicate_contact"}
	_contacts[token] = {"token":token,"actor_id":id,"scope":_scope.duplicate(true),"sequence":int(event.sequence),"world_time":float(event.world_time),"actual_damage":damage,"receipt_id":str(event.get("receipt_id", "damage:%d" % int(event.sequence))),"original":event.duplicate(true)}
	return {"accepted":true,"token":token,"receipt_id":_contacts[token].receipt_id}

func capture(source: Node, presentation: Dictionary = {}) -> Dictionary:
	if not _synchronize(source): return {"schema":"enemy-roster-1","status":last_status}
	var full: Dictionary = source.snapshot()
	var actors: Array = []
	for state: Dictionary in full.enemies:
		var binding: Dictionary = _bindings[str(state.actor_id)]
		var token := str(binding.token)
		if bool(state.dead) and not _deaths.has(token): _deaths[token] = float(full.world_time)
		actors.append({"token":token,"actor_id":str(state.actor_id),"state":state.duplicate(true),"contact":_contacts.get(token, {}).duplicate(true),"dead_at":float(_deaths.get(token, -1.0)),"death_time_basis":"original_kill_or_first_observation","cue_identity_available":not binding.reused})
	_serial += 1
	return {"schema":"enemy-roster-1","status":"ready","reader_id":get_instance_id(),"epoch":_epoch,"sample_serial":_serial,"scope":_scope.duplicate(true),"world_time":float(full.world_time),"phase":str(full.phase),"paused":bool(full.paused),"hero_dead":bool(full.hero.dead),"actors":actors,"presentation":presentation.duplicate(true)}
