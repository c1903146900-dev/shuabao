extends RefCounted
## Read-only bridge from live simulation events into the progression authority.
## Integration calls model.record_battle_event(sim,event,run_id) synchronously from
## room._on_combat_event. A matching live event log entry is required, never a UI claim.
static func verify(sim: Node, model: RefCounted, event: Dictionary, run_id: String) -> Dictionary:
	if not is_instance_valid(sim) or run_id.is_empty(): return {"error":"missing_battle_context"}
	if model.state.get("test_mode",false): return {"error":"test_mode_not_progression"}
	if model.state.get("actor_dead",false): return {"error":"not_alive"}
	if model.state.phase != "combat" or sim.phase != "combat": return {"error":"not_live_battle"}
	if event.get("combat_level_id","") != sim.combat_level_id or event.get("wave",-1) != sim.wave: return {"error":"stale_battle_event"}
	var observed := false
	for recorded in sim.event_log:
		if int(recorded.get("sequence",-1)) == int(event.get("sequence",-2)) and recorded == event:
			observed = true
			break
	if not observed: return {"error":"unverified_battle_event"}
	var base: Dictionary = {"run_id":run_id,"encounter_id":sim.combat_level_id,"generation":sim.encounter_generation,"sequence":event.sequence,"kind":event.get("kind",""),"metrics":{},"target":event.get("target",""),"cast_id":event.get("cast_id",0),"rank_category":""}
	base.event_key = "%s|%s|%s|%s" % [run_id,sim.combat_level_id,sim.encounter_generation,event.sequence]
	base.encounter_key = "%s|%s|%s" % [run_id,sim.combat_level_id,sim.encounter_generation]
	if base.kind == "damage":
		if event.get("target","") == sim.hero.actor_id and event.get("source","") == "enemy":
			base.metrics.enemy_damage_absorbed_by_shield = maxf(0.0,float(event.get("absorbed",0)))
		elif event.get("source","") == "attack" and float(event.get("amount",0)) > 0 and int(event.get("cast_id",0)) > 0:
			var target: Dictionary = sim.enemy_by_id(event.get("target",""))
			if not target.is_empty(): base.metrics.basic_attack_target_hit = 1
	elif base.kind == "kill":
		var target: Dictionary = sim.enemy_by_id(event.get("target",""))
		if target.is_empty() or not target.get("dead",false): return {"error":"unverified_kill"}
		if event.get("credit","") != "solo_lethal": return {"error":"unverified_kill_credit"}
		base.rank_category = target.get("rank_category", "boss" if target.kind == "boss" else "elite" if target.kind == "elite" else "ordinary")
		if base.rank_category == "ordinary": base.metrics.ordinary_enemy_kill = 1
	return {"fact":base}

static func verify_act_registration(sim: Node, model: RefCounted, act_id: String, boss_id: String, run_id: String) -> Dictionary:
	if model.state.get("test_mode",false): return {"error":"test_mode_not_progression"}
	var definition: Dictionary = model.config.get("campaign_acts",{}).get(act_id,{})
	if definition.is_empty() or definition.get("completion_rule","") != "boss_defeated_and_coordinator_completed": return {"error":"unknown_authored_act"}
	if run_id.is_empty() or sim.phase != "combat" or model.state.phase != "combat": return {"error":"not_live_battle"}
	var boss: Dictionary = sim.enemy_by_id(boss_id)
	if boss.is_empty() or boss.get("rank_category", "") != "boss" or boss.get("dead",false): return {"error":"invalid_act_boss"}
	return {"fact":{"act_id":act_id,"boss_actor_id":boss_id,"run_id":run_id,"encounter_key":"%s|%s|%s" % [run_id,sim.combat_level_id,sim.encounter_generation],"definition":definition.duplicate(true)}}
