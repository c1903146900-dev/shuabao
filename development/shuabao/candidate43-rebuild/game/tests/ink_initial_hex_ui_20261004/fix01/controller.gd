extends "res://tests/ink_initial_hex_runtime_20261004/ink_initial_controller.gd"
## Narrow read-only Hex projection for the actual commerce-envelope model.
## The inherited request/command/receipt/selection/readiness paths stay unchanged.
## ShopPanel already owns the commerce UI through Session's public shop contract.
func refresh() -> void:
 if not is_instance_valid(hud) or model == null: return
 var state: Dictionary = model.snapshot()
 if state.get("actor_dead", false): hud.set_hex_required(false)
 # Real adapter request identity/revision comes only from the public snapshot.
 hud.adapter.present({"actor_id":state.actor_id, "hero_id":state.hero_id, "revision":state.revision, "level":state.level, "points":state.points, "xp":state.xp, "gold":state.gold, "skills":state.skills.duplicate(true), "hp":combat.get("hp", 0), "hp_max":combat.get("hp_max", 1), "stats":combat.get("stats", {}).duplicate(true)})
 if _projection_revision == int(state.revision) and _projection_phase == str(combat.get("phase", "")): return
 _projection_revision = int(state.revision)
 _projection_phase = str(combat.get("phase", ""))
 var milestones: Array = state.pending_milestones.duplicate()
 for key in state.offers:
  if not int(key) in milestones: milestones.append(int(key))
 if not display.get("hex_enabled", true): milestones.clear()
 milestones.sort()
 if active_milestone == 0 and not milestones.is_empty(): active_milestone = milestones[0]
 var offer: Dictionary = state.offers.get(str(active_milestone), {})
 var choices: Array = []
 for index in range(offer.get("slots", []).size()):
  var id: String = offer.slots[index]
  var definition: Dictionary = definitions.hexes[id]
  var dependencies: Array = ContentText.hex_dependencies(definition)
  choices.append({"id":id, "name":display.get("hexes", {}).get(id, definition.get("name", id)), "hero_only":index == 3, "description":ContentText.display_numbers(model.hex_description(id)), "requires":definition.get("requires", ""), "skill_dependencies":dependencies, "dependency_label":ContentText.dependency_label(dependencies, definitions), "refreshed":offer.refresh_used[index], "selected":offer.get("selected", "") == id})
 var selected_text: Array[String] = []
 for id in state.selected_hex:
  var label: String = str(definitions.hexes[id].get("name", id))
  selected_text.append(label + (" · 生效" if state.hex_status[id] == "active" else " · 休眠"))
 hud.present_progression({"actor_dead":state.get("actor_dead", false), "phase":state.phase, "combat_phase":combat.get("phase", ""), "learned_skills":state.skills, "test_definitions":definitions, "milestones":milestones, "active_milestone":active_milestone, "choices":choices, "offer_selected":not offer.get("selected", "").is_empty(), "selected_text":"  /  ".join(selected_text)})
