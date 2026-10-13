extends RefCounted
## Deliberate fresh Yan Guizhou host composition, never patch a live director.
const Candidate = preload("res://tests/ink_enemy_navigation_fix01_20261005/enemy_director.gd")
const SIM_PATH := "res://tests/ink_q3_foundation_20261004/fix02/ink_q3_sim.gd"
const BEFORE_PATH := "res://tests/ink_q3_foundation_20261004/ink_q3_enemy_director.gd"
static func apply_to_fresh_ink_sim(sim: Node) -> Dictionary:
 if not is_instance_valid(sim) or sim.get_script().resource_path != SIM_PATH: return {"accepted":false,"reason":"exact_ink_sim_required"}
 if sim.hero.actor_id != "yanguizhou": return {"accepted":false,"reason":"ink_hero_required"}
 if sim.phase != "preparation" or sim.wave != 0 or sim.transaction_active or not sim.enemies.is_empty(): return {"accepted":false,"reason":"fresh_preparation_only"}
 if sim.enemy_director.get_script().resource_path != BEFORE_PATH: return {"accepted":false,"reason":"expected_original_q3_director_required"}
 if sim.enemy_director.time != 0.0 or sim.enemy_director.commits != 0 or sim.enemy_director.projectile_serial != 0: return {"accepted":false,"reason":"unused_director_required"}
 sim.enemy_director = Candidate.new()
 return {"accepted":true,"reason":"","scope":"ink_host_navigation_candidate_only","production_promoted":false}
