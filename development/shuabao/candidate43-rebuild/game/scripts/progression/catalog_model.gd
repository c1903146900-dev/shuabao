extends "res://scripts/progression/model.gd"
## Additive prototype adapter. Original Model API and fixture behavior remain intact.
const Catalog = preload("res://scripts/progression/catalog_validation.gd")
var supported_hooks: Array = []
var catalog_errors: Array = []
const BattleEvents = preload("res://data/final_design/event_adapter.gd")
const FinalDesign = preload("res://data/final_design/catalog.gd")
var _trusted_fact: Dictionary = {}
var _trusted_act: Dictionary = {}

func _init(definitions: Dictionary = {}, actor_id: String = "local", seed_value: int = 1):
	super(definitions, actor_id, seed_value)
	catalog_errors = Catalog.validate(config)

# Trusted coordinator only. Names are a declaration, never proof that combat implements them.
# Runtime capabilities are deliberately NOT saved: loading a checkpoint cannot enable a hook.
func set_supported_hooks(hooks: Array) -> void:
	supported_hooks = hooks.duplicate()

func support(definition: Dictionary) -> Dictionary:
	var missing: Array = []
	for hook in definition.get("required_hooks", []):
		if not hook in supported_hooks: missing.append(hook)
	var eligible: bool = definition.get("activation_status", "eligible_when_implemented") == "eligible_when_implemented"
	if definition.get("ranged_only", false) and not config.get("hero_ranged", false): eligible = false
	var available: bool = eligible and catalog_errors.is_empty() and definition.get("status") in ["prototype_initial", "source_final"] and missing.is_empty()
	return {"supported": available, "status": "available" if available else "unsupported", "missing_hooks": missing, "activation_status": definition.get("activation_status", "eligible_when_implemented"), "catalog_errors": catalog_errors.duplicate()}

func _item_support(id: String) -> bool:
	if not config.items.has(id): return false
	var item: Dictionary = config.items[id]
	if not support(item).supported: return false
	var passive: String = item.get("passive", "")
	return passive.is_empty() or support(config.passives[passive]).supported

func _dependency_met(hex: Dictionary) -> bool:
	var dependencies: Array = hex.get("skill_dependencies", [])
	if not dependencies.is_empty():
		for dependency in dependencies:
			var found := false
			for learned in state.skills.values():
				if learned.rank > 0 and learned.candidate == dependency: found = true
			if not found: return false
		return true
	var required: String = hex.get("requires", "")
	if required.is_empty(): return true
	for slot in state.skills:
		var skill: Dictionary = state.skills[slot]
		if skill.rank > 0 and (skill.candidate == required or slot == required): return true
	return false

func snapshot() -> Dictionary:
	var out := super.snapshot()
	for id in state.selected_hex:
		out.hex_status[id] = "unsupported" if not support(config.hexes[id]).supported else ("active" if _dependency_met(config.hexes[id]) else "dormant")
	out["body_pending"] = {}
	for purchase in state.body:
		if purchase.get("selected", "").is_empty(): out.body_pending = purchase.duplicate(true)
	out["equipment_task_status"] = equipment_task_status()
	out["g20_stacks"] = state.get("g20_stacks",{}).duplicate(true)
	out["content_profile"] = "playable_prototype"
	out["catalog_errors"] = catalog_errors.duplicate()
	out["content_warnings"] = []
	var passive_counts := {}
	for entry in state.inventory:
		var item: Dictionary = config.items[entry.id]
		if not item.passive.is_empty(): passive_counts[item.passive] = passive_counts.get(item.passive, 0) + 1
		if not _item_support(entry.id): out.content_warnings.append({"reason":"unsupported_effect", "item_id":entry.id})
	for key in passive_counts:
		if passive_counts[key] > 1: out.content_warnings.append({"reason":"duplicate_unique_passive", "effect_key":key, "owned_copies":passive_counts[key], "active_copies":1 if support(config.passives[key]).supported else 0})
	return out

func shop_catalog() -> Dictionary:
	var out := super.shop_catalog()
	for id in out:
		out[id]["availability"] = support(out[id])
		out[id].availability.supported = _item_support(id)
		out[id].availability.status = "available" if _item_support(id) else "unsupported"
	return out

func _apply(action: String, a: Dictionary) -> String:
	if not catalog_errors.is_empty(): return "invalid_catalog"
	if action == "buy_body":
		if state.phase != "safe": return "unsafe_phase"
		if not support(config.body).supported: return "unsupported_effect"
		for purchase in state.body:
			if purchase.selected.is_empty(): return "body_choice_pending"
		if state.gold < config.body.cost: return "insufficient_gold"
		var available := 0
		for outcome in config.body.outcomes.values():
			if support(outcome).supported: available += 1
		if available < 3: return "body_pool_exhausted"
		var candidates: Array = []
		for count in range(3):
			var pool: Array = []
			var total := 0
			for id in config.body.outcomes:
				if id in candidates or not support(config.body.outcomes[id]).supported: continue
				total += int(config.body.outcomes[id].weight)
				pool.append([id, total])
			state.rng = (int(state.rng) * 48271) % 2147483647
			for pair in pool:
				if int(state.rng) % total < pair[1]:
					candidates.append(pair[0])
					break
		state.gold -= config.body.cost
		state.body.append({"purchase_id": state.body.size() + 1, "cost": config.body.cost, "definition_version": config.version, "candidates": candidates, "selected": ""})
		_settle_g21_body_spend(int(config.body.cost),int(state.body.back().purchase_id))
		return ""
	if action == "select_body":
		if state.phase != "safe": return "unsafe_phase"
		if not support(config.body).supported: return "unsupported_effect"
		for purchase in state.body:
			if purchase.purchase_id != a.get("purchase_id", -1): continue
			if not purchase.selected.is_empty(): return "already_selected"
			if not a.get("outcome", "") in purchase.candidates: return "invalid_body_choice"
			if not support(config.body.outcomes[a.outcome]).supported: return "unsupported_effect"
			purchase.selected = a.outcome
			return ""
		return "missing_body_purchase"
	if action in ["hex_open", "hex_refresh", "hex_select"] and state.phase != "safe" and not config.get("auto_hex_in_combat", false): return "unsafe_phase"
	if action == "hex_select":
		var offer: Dictionary = state.offers.get(str(a.get("milestone", 0)), {})
		var index: int = a.get("slot", -1)
		if not offer.is_empty() and index >= 0 and index < 4:
			if not support(config.hexes[offer.slots[index]]).supported: return "unsupported_effect"
	if action == "record_equipment_task": return "verified_battle_event_required"
	if action == "battle_progress":
		if _trusted_fact.is_empty() or a != _trusted_fact: return "verified_battle_event_required"
		return _record_battle_progress(a)
	if action == "register_act":
		if _trusted_act.is_empty() or a != _trusted_act: return "verified_act_context_required"
		return _register_act(a)
	if action == "complete_act": return _complete_act(a)
	var reason: String = super._apply(action, a)
	if reason.is_empty() and action == "hex_select": _settle_g17_bonus()
	return reason

func _buy(id: String) -> String:
	if not config.items.has(id): return "missing_definition"
	if not _item_support(id): return "unsupported_effect"
	return super._buy(id)

func _use(uid: int) -> String:
	for entry in state.inventory:
		if entry.uid != uid: continue
		if not _item_support(entry.id): return "unsupported_effect"
		var recovery: Dictionary = config.items[entry.id].get("recovery", {})
		if not state.phase in recovery.get("allowed_phases", []): return "unsafe_phase"
	return super._use(uid)

func equipment_effects() -> Dictionary:
	var result := {"stats": {}, "passives": []}
	for entry in state.inventory:
		if not _item_support(entry.id): continue
		var item: Dictionary = config.items[entry.id]
		var item_stats: Dictionary = item.stats.duplicate(true)
		var multiplier: float = 1.0 + float(state.get("g21_item_bonuses",{}).get(str(entry.uid),{}).get("base_fraction",0.0))
		if item.get("kind","") == "equipment" and item.get("tier","") != "complete" and _selected_hex_active("common_g27"):
			multiplier *= 1.0 + hex_parameter("common_g27","G27-1")/100.0
		for stat in item_stats: item_stats[stat] *= multiplier
		_add_stats(result.stats, item_stats, entry.count)
		var passive: String = item.passive
		if not passive.is_empty() and not passive in result.passives:
			result.passives.append(passive)
			_add_stats(result.stats, config.passives[passive].stats)
	return result

func body_effects() -> Dictionary:
	var stats := {}
	if not support(config.body).supported: return stats
	for purchase in state.body:
		if not purchase.selected.is_empty() and support(config.body.outcomes[purchase.selected]).supported: _add_stats(stats, config.body.outcomes[purchase.selected].stats)
	return stats

func aggregate_effects() -> Dictionary:
	var result := equipment_effects()
	_add_stats(result.stats, body_effects())
	result["hexes"] = []
	for id in state.selected_hex:
		if support(config.hexes[id]).supported and _dependency_met(config.hexes[id]):
			_add_stats(result.stats, config.hexes[id].stats)
			result.hexes.append(id)
	return result

# Pure numeric projection, no mutation of current HP/CD/charges or combat actor.
func project_stats(base: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	var additions: Dictionary = aggregate_effects().stats
	for stat in additions:
		if config.stat_units[stat] == "base_fraction": out[stat] = base.get(stat, 0) * (1.0 + additions[stat])
		else: out[stat] = base.get(stat, 0) + additions[stat]
	for entry in [["cooldown_reduction", 0.65], ["tenacity", 1.0], ["attack_speed", 2.5]]:
		if out.has(entry[0]): out[entry[0]] = minf(out[entry[0]], entry[1])
	return out

func _add_stats(target: Dictionary, additions: Dictionary, count: int = 1) -> void:
	for stat in additions: target[stat] = target.get(stat, 0) + additions[stat] * count

func _draw(hero_only: bool, excluded: Array) -> String:
	var pool: Array = []
	var total := 0
	var excluded_keys: Array = []
	for id in excluded + state.selected_hex:
		if config.hexes.has(id): excluded_keys.append(config.hexes[id].effect_key)
	for offer in state.offers.values():
		if offer.selected.is_empty():
			for id in offer.slots: excluded_keys.append(config.hexes[id].effect_key)
	for id in config.hexes:
		var hex: Dictionary = config.hexes[id]
		if not support(hex).supported or hex.effect_key in excluded_keys: continue
		if not hex.hero in ["", state.hero_id]: continue
		if hero_only and hex.hero != state.hero_id: continue
		var weight: int = maxi(1, int(hex.weight) / (1 + int(state.seen_hex.get(id, 0))))
		if not _dependency_met(hex): weight = maxi(1, int(weight * config.policies.hex_unlearned_weight_multiplier))
		total += weight
		pool.append([id, total])
	if pool.is_empty(): return ""
	state.rng = (int(state.rng) * 48271) % 2147483647
	for pair in pool:
		if int(state.rng) % total < pair[1]:
			state.seen_hex[pair[0]] = int(state.seen_hex.get(pair[0], 0)) + 1
			return pair[0]
	return ""

func _supports_catalog_profile() -> bool:
	return true

# Only this entrypoint may turn observed combat into progression facts.
func record_battle_event(sim: Node, event: Dictionary, run_id: String) -> Dictionary:
	if not is_instance_valid(sim) or run_id.is_empty(): return {"accepted":false,"reason":"missing_battle_context","events":[]}
	if state.has("battle_run_id") and state.battle_run_id != run_id: return {"accepted":false,"reason":"wrong_run","events":[]}
	if not _event_may_progress(sim,event): return {"accepted":true,"reason":"irrelevant_battle_event","changed":false,"events":[]}
	var verified := BattleEvents.verify(sim,self,event,run_id)
	if verified.has("error"): return {"accepted":false,"reason":verified.error,"events":[]}
	var fact: Dictionary = verified.fact
	var command_id: String = "battle:" + fact.event_key
	if receipts.has(command_id):
		var duplicate: Dictionary = receipts[command_id].result.duplicate(true)
		duplicate["changed"] = false
		return duplicate
	if not _fact_may_progress(fact): return {"accepted":true,"reason":"irrelevant_battle_event","changed":false,"events":[]}
	var cursor: Dictionary = state.get("battle_event_cursor",{})
	if cursor.get("encounter_key","") == fact.encounter_key and int(fact.sequence) <= int(cursor.get("sequence",-1)):
		return {"accepted":true,"reason":"already_processed_battle_event","changed":false,"events":[]}
	var completed_before: int = state.get("completed_equipment_tasks",{}).size()
	_trusted_fact = fact
	var result := command(command_id, "battle_progress", fact)
	_trusted_fact = {}
	# Cursor and bounded metric keys are sufficient for partial progress. Only
	# completed-task and qualifying Boss receipts remain in the durable ledger.
	if not result.accepted or (state.get("completed_equipment_tasks",{}).size() == completed_before and not (fact.kind == "kill" and fact.rank_category == "boss")):
		receipts.erase(command_id)
	result["changed"] = result.accepted
	return result

func _record_battle_progress(fact: Dictionary) -> String:
	if state.get("test_mode",false): return "test_mode_not_progression"
	if state.has("battle_run_id") and state.battle_run_id != fact.run_id: return "wrong_run"
	state.battle_run_id = fact.run_id
	if not "equipment.task_completion.v1" in supported_hooks and config.get("campaign_acts",{}).is_empty(): return "unsupported_effect"
	state["battle_event_cursor"] = {"encounter_key":fact.encounter_key,"sequence":fact.sequence}
	state.erase("battle_event_ids") # Migrate former per-hit storage to one cursor.
	if not state.has("equipment_task_progress"): state.equipment_task_progress = {}
	if not state.has("task_metric_event_ids"): state.task_metric_event_ids = {}
	if not state.has("completed_equipment_tasks"): state.completed_equipment_tasks = {}
	if not state.has("bonus_awards"): state.bonus_awards = {}
	if "equipment.task_completion.v1" in supported_hooks:
		for task_id in config.get("equipment_tasks",{}):
			var task: Dictionary = config.equipment_tasks[task_id]
			if state.completed_equipment_tasks.has(task.equipment_id): continue
			var held := false
			for item in state.inventory:
				if item.id == task.equipment_id: held = true
			if not held: continue
			var amount: float = float(fact.metrics.get(task.metric,0))
			if amount <= 0: continue
			var metric_key: String = task_id + "|" + fact.event_key
			if task.metric == "basic_attack_target_hit": metric_key = "%s|%s|%s|%s" % [task_id,fact.encounter_key,fact.cast_id,fact.target]
			elif task.metric == "ordinary_enemy_kill": metric_key = "%s|%s|%s" % [task_id,fact.encounter_key,fact.target]
			if task.metric != "enemy_damage_absorbed_by_shield":
				if state.task_metric_event_ids.has(metric_key): continue
				state.task_metric_event_ids[metric_key] = true
			var progress: float = minf(float(task.threshold),float(state.equipment_task_progress.get(task_id,0))+amount)
			state.equipment_task_progress[task_id] = _canonical(progress)
			if progress >= float(task.threshold):
				var reward: int = int(task.reward_sp)
				state.completed_equipment_tasks[task.equipment_id] = {"task_id":task_id,"event_id":fact.event_key}
				state.points += reward
				state.bonus_sp = int(state.get("bonus_sp",0)) + reward
				state.bonus_awards[task_id] = {"amount":reward,"source":"authored_equipment_task","definition_version":config.version}
				for metric_id in state.task_metric_event_ids.keys():
					if str(metric_id).begins_with(task_id+"|"): state.task_metric_event_ids.erase(metric_id)
	_settle_g17_bonus()
	if fact.kind == "kill" and fact.rank_category == "boss":
		for act in state.get("act_progress",{}).values():
			if act.boss_actor_id == fact.target and act.run_id == fact.run_id and act.encounter_key == fact.encounter_key:
				act.boss_defeated = true
				act.boss_event_id = fact.event_key
	return ""

func register_act_context(sim: Node, act_id: String, boss_id: String, run_id: String) -> Dictionary:
	var verified := BattleEvents.verify_act_registration(sim,self,act_id,boss_id,run_id)
	if verified.has("error"): return {"accepted":false,"reason":verified.error,"events":[]}
	_trusted_act = verified.fact
	var result := command("act-register:" + run_id + ":" + act_id,"register_act",_trusted_act)
	_trusted_act = {}
	return result

func _register_act(a: Dictionary) -> String:
	if state.has("battle_run_id") and state.battle_run_id != a.run_id: return "wrong_run"
	state.battle_run_id = a.run_id
	if not state.has("act_progress"): state.act_progress = {}
	if state.act_progress.has(a.act_id): return "act_already_registered"
	state.act_progress[a.act_id] = a.duplicate(true)
	state.act_progress[a.act_id]["boss_defeated"] = false
	state.act_progress[a.act_id]["completed"] = false
	return ""

# Called by the authored campaign coordinator only when the whole act is complete.
# Boss death is necessary, never sufficient by itself; normal waves never invoke this.
func complete_act(act_id: String, completion_event_id: String) -> Dictionary:
	var result := command("act-complete:" + completion_event_id,"complete_act",{"act_id":act_id,"event_id":completion_event_id})
	if result.accepted: result["major_floor_event"] = state.major_floor_events[act_id].duplicate(true)
	return result

func _complete_act(a: Dictionary) -> String:
	if state.get("test_mode",false): return "test_mode_not_progression"
	if a.get("event_id","").is_empty(): return "missing_event_id"
	var act: Dictionary = state.get("act_progress",{}).get(a.get("act_id",""),{})
	if act.is_empty(): return "unknown_registered_act"
	if act.completed: return "act_already_completed"
	if not act.boss_defeated: return "act_boss_not_defeated"
	act.completed = true
	if not state.has("major_floor_events"): state.major_floor_events = {}
	state.major_floor_events[a.act_id] = {"kind":"major_floor_completed","act_id":a.act_id,"event_id":a.event_id,"boss_actor_id":act.boss_actor_id,"boss_event_id":act.boss_event_id,"run_id":act.run_id}
	state.major_floor_events[a.act_id]["g20_result"] = _settle_g20(a.act_id)
	return ""

func _settle_g17_bonus() -> void:
	var id := "common_g17"
	if not id in state.selected_hex or not config.hexes.has(id): return
	if not support(config.hexes[id]).supported: return
	if not state.has("bonus_awards"): state.bonus_awards = {}
	if state.bonus_awards.has(id): return
	var parameters: Dictionary = config.hexes[id].get("source_definition", {}).get("parameters", {})
	if not parameters.has("G17-1") or not parameters.has("G17-2"): return
	var threshold: int = int(parameters["G17-1"].values[0])
	if state.get("completed_equipment_tasks", {}).size() < threshold: return
	var bonus: int = int(parameters["G17-2"].values[0])
	state.points += bonus
	state.bonus_sp = int(state.get("bonus_sp", 0)) + bonus
	state.bonus_awards[id] = {"amount":bonus,"source":"通用海克斯!E89","definition_version":config.version}

func equipment_task_status() -> Dictionary:
	var out := {}
	for id in config.get("equipment_tasks",{}):
		var definition: Dictionary = config.equipment_tasks[id]
		out[id] = {"definition":definition.duplicate(true),"progress":state.get("equipment_task_progress",{}).get(id,0),"completed":state.get("completed_equipment_tasks",{}).has(definition.equipment_id)}
	return out

func _settle_g20(act_id: String) -> Dictionary:
	var id := "common_g20"
	if not id in state.selected_hex or not config.hexes.has(id) or not support(config.hexes[id]).supported: return {"applied":false,"reason":"hex_not_active"}
	if not state.has("g20_processed_acts"): state.g20_processed_acts = {}
	if state.g20_processed_acts.has(act_id): return {"applied":false,"reason":"already_processed_act"}
	state.g20_processed_acts[act_id] = true
	if not state.has("g20_stacks"): state.g20_stacks = {}
	var mappings: Dictionary = FinalDesign.enhancement_map().hexes
	var eligible: Array = []
	for selected in state.selected_hex:
		var mapping: Dictionary = mappings.get(selected,{})
		if mapping.get("eligible_when_selected_and_approved",false) and not mapping.get("approved_fields",[]).is_empty() and int(state.g20_stacks.get(selected,0)) < 2:
			eligible.append(selected)
	if eligible.is_empty(): return {"applied":false,"reason":"no_eligible_selected_hex"}
	state.rng = (int(state.rng) * 48271) % 2147483647
	var chosen: String = eligible[int(state.rng) % eligible.size()]
	state.g20_stacks[chosen] = int(state.g20_stacks.get(chosen,0)) + 1
	return {"applied":true,"hex_id":chosen,"stack_count":state.g20_stacks[chosen],"fields":mappings[chosen].approved_fields.duplicate(),"multiplier":1.0+0.2*state.g20_stacks[chosen]}

func hex_parameter(id: String, token: String) -> float:
	var normalized: String = token.trim_prefix("[").trim_suffix("]").to_upper()
	var base: float = FinalDesign.hex_parameter(id,normalized)
	var fields: Array = FinalDesign.enhancement_fields(id)
	if normalized in fields:
		return base*(1.0+0.2*clampi(int(state.get("g20_stacks",{}).get(id,0)),0,2))
	return base

func hex_description(id: String) -> String:
	var definition: Dictionary = config.hexes.get(id,{}).get("source_definition",{})
	# Keep source parameters/G20 arithmetic; render the approved effective wording.
	var result: String = config.hexes.get(id,{}).get("template",definition.get("template",""))
	for token in definition.get("parameters",{}): result=result.replace("["+token+"]",String.num(hex_parameter(id,token),6))
	return result

func _event_may_progress(sim: Node,event: Dictionary) -> bool:
	var kind: String = event.get("kind","")
	if kind == "kill":
		for act in state.get("act_progress",{}).values():
			if not act.get("boss_defeated",false) and not act.get("completed",false) and act.boss_actor_id == event.get("target",""): return true
	if not "equipment.task_completion.v1" in supported_hooks: return false
	for task in config.get("equipment_tasks",{}).values():
		if state.get("completed_equipment_tasks",{}).has(task.equipment_id): continue
		var held := false
		for item in state.inventory:
			if item.id == task.equipment_id: held = true
		if not held: continue
		if task.metric == "ordinary_enemy_kill" and kind == "kill": return true
		if kind != "damage": continue
		if task.metric == "basic_attack_target_hit" and event.get("source","") == "attack" and float(event.get("amount",0)) > 0: return true
		if task.metric == "enemy_damage_absorbed_by_shield" and event.get("target","") == sim.hero.actor_id and event.get("source","") == "enemy" and float(event.get("absorbed",0)) > 0: return true
	return false

func _fact_may_progress(fact: Dictionary) -> bool:
	if fact.kind == "kill" and fact.rank_category == "boss":
		for act in state.get("act_progress",{}).values():
			if not act.get("boss_defeated",false) and not act.get("completed",false) and act.boss_actor_id == fact.target and act.run_id == fact.run_id and act.encounter_key == fact.encounter_key: return true
	for task in config.get("equipment_tasks",{}).values():
		if state.get("completed_equipment_tasks",{}).has(task.equipment_id) or float(fact.metrics.get(task.metric,0)) <= 0: continue
		var metric_key: String = ""
		var task_id: String = ""
		for key in config.equipment_tasks:
			if config.equipment_tasks[key].equipment_id == task.equipment_id: task_id = key
		if task.metric == "basic_attack_target_hit": metric_key = "%s|%s|%s|%s" % [task_id,fact.encounter_key,fact.cast_id,fact.target]
		elif task.metric == "ordinary_enemy_kill": metric_key = "%s|%s|%s" % [task_id,fact.encounter_key,fact.target]
		if not metric_key.is_empty() and state.get("task_metric_event_ids",{}).has(metric_key): continue
		for item in state.inventory:
			if item.id == task.equipment_id: return true
	return false

func _selected_hex_active(id: String) -> bool:
	return id in state.selected_hex and config.hexes.has(id) and support(config.hexes[id]).supported and _dependency_met(config.hexes[id])

func _settle_g21_body_spend(cost: int,purchase_id: int) -> void:
	if not _selected_hex_active("common_g21") or state.inventory.size() != 6: return
	for entry in state.inventory:
		if not config.items.has(entry.id) or config.items[entry.id].get("kind","") != "equipment" or config.items[entry.id].get("tier","") != "complete": return
	if not state.has("g21_body_purchase_ids"): state.g21_body_purchase_ids = {}
	if state.g21_body_purchase_ids.has(str(purchase_id)): return
	state.g21_body_purchase_ids[str(purchase_id)] = true
	state.g21_qualifying_spend = int(state.get("g21_qualifying_spend",0)) + cost
	state.g21_spend_remainder = int(state.get("g21_spend_remainder",0)) + cost
	if not state.has("g21_item_bonuses"): state.g21_item_bonuses = {}
	var threshold: int = int(hex_parameter("common_g21","G21-1"))
	var maximum: int = int(hex_parameter("common_g21","G21-3"))
	while state.g21_spend_remainder >= threshold:
		state.g21_spend_remainder -= threshold
		var eligible: Array = []
		for entry in state.inventory:
			if int(state.g21_item_bonuses.get(str(entry.uid),{}).get("stacks",0)) < maximum: eligible.append(entry)
		if eligible.is_empty(): continue
		state.rng = (int(state.rng) * 48271) % 2147483647
		var selected: Dictionary = eligible[int(state.rng) % eligible.size()]
		var key: String = str(selected.uid)
		var bonus: Dictionary = state.g21_item_bonuses.get(key,{"item_id":selected.id,"uid":selected.uid,"stacks":0,"base_fraction":0.0,"awards":[]})
		var fraction: float = hex_parameter("common_g21","G21-2")/100.0
		bonus.stacks += 1
		bonus.base_fraction += fraction
		bonus.awards.append({"purchase_id":purchase_id,"base_fraction":fraction})
		state.g21_item_bonuses[key] = bonus
