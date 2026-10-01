extends "res://scripts/progression/catalog_model.gd"
## Trusted two-room authority. Reward/penalty changes share Model.command rollback/dedupe.
func _apply(action: String, args: Dictionary) -> String:
 if action == "life_state":
  state["actor_dead"] = args.get("dead",false)
  return ""
 if action == "death_penalty":
  var id: String = args.get("event_id","")
  if id.is_empty(): return "missing_event_id"
  if id in state.get("death_ids",[]): return "duplicate_death"
  if not state.has("death_ids"): state.death_ids = []
  state.death_ids.append(id)
  state.xp = int(floor(float(state.xp)*0.7))
  return ""
 if action in ["hex_open","hex_refresh","hex_select","buy_body","select_body","use_item"]:
  return "stage_not_available"
 if state.get("actor_dead",false) and action in ["learn","undo_skill","respec","buy","sell","undo_shop"]:
  return "not_alive"
 var reason: String = super._apply(action,args)
 if reason.is_empty() and action == "reward_minion":
  if not state.has("credited_rewards"): state["credited_rewards"] = {}
  state.credited_rewards[args.event_id] = {"room":args.get("room",""),"gold":args.gold,"xp":args.xp}
 return reason
