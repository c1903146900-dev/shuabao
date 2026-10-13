extends RefCounted
## Derived view only. No inventory, currency, recovery receipt or immutable-base writes.
const InkTuning = preload("res://tests/ink_q1_foundation_20261004/revision02/scripts/ink_tuning.gd")
const NAMES = {"AD":"ad", "AP":"ap", "attack_speed":"attack_speed", "max_hp":"max_hp", "defense":"defence", "move_speed":"move_speed", "crit_chance":"crit_chance", "cooldown_reduction":"cdr", "lifesteal":"lifesteal", "tenacity":"tenacity", "penetration":"penetration", "hp_regen":"regen"}
func sync_stats(sim: Node, model: RefCounted) -> void:
 assert(sim.hero.actor_id == "yanguizhou" and model.state.hero_id == "yanguizhou")
 assert(not sim.transaction_active)
 if sim.common.model == null or not is_same(sim.common.model.get_ref(), model): sim.set_common_model(model)
 var source: Dictionary = InkTuning.hero_stats()
 var base: Dictionary = {}
 for key in NAMES: base[key] = source[NAMES[key]]
 # Existing authority order: fresh source + equipment + body + static Hex;
 # then existing common-runtime projection and its caps.
 sim.set_projected_stats(model.project_stats(base))
 var active: Array = model.aggregate_effects().hexes
 if sim.hero.hexes != active: sim.set_hexes(active)
 # Existing shared rule: maxHP increases do not heal; reductions only clamp.
 # Undo restores inventory/stat maximum, never an old HP snapshot.
 sim.hero.hp = minf(sim.hero.hp, sim.hero.stats.max_hp)
