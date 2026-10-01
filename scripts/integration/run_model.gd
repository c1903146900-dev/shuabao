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
 if action in ["buy_body","select_body"]:
  return "stage_not_available"
 if action.begins_with("hex_") and state.phase != "safe": return "unsafe_phase"
 if action == "use_item":
  for entry in state.inventory:
   if entry.uid == args.get("uid",-1) and state.recovery_mode not in ["",config.items[entry.id].kind]: return "recovery_mutex"
 if state.get("actor_dead",false) and action in ["learn","undo_skill","respec","buy","sell","undo_shop","use_item","hex_open","hex_refresh","hex_select"]:
  return "not_alive"
 var reason: String = super._apply(action,args)
 if reason.is_empty() and action == "reward_minion":
  if not state.has("credited_rewards"): state["credited_rewards"] = {}
  state.credited_rewards[args.event_id] = {"room":args.get("room",""),"gold":args.gold,"xp":args.xp}
 return reason

func support(entry: Dictionary) -> Dictionary:
 var result: Dictionary = super.support(entry)
 # Dependency/dormancy policy remains experimental; only unconditional numeric hexes here.
 if not str(entry.get("requires","")).is_empty():
  result.supported = false
  result.status = "unsupported"
  result.missing_hooks.append("skill_dependency_not_enabled")
 return result

func _draw(hero_only: bool, excluded: Array) -> String:
 if not hero_only and excluded.size() < 3:
  var available_heroes: Array = []
  for id in config.hexes:
   var entry: Dictionary = config.hexes[id]
   if entry.hero == state.hero_id and support(entry).supported and id not in excluded and id not in state.selected_hex:
    available_heroes.append(id)
  # Reserve the final eligible hero for the required fourth hero slot.
  if available_heroes.size() == 1: return super._draw(false,excluded+[available_heroes[0]])
 return super._draw(hero_only,excluded)
