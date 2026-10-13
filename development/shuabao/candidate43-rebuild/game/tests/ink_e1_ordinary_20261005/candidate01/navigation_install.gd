extends RefCounted
## Same retained director algorithm; only exact Q2 source admission differs.
const Candidate = preload("res://tests/ink_enemy_navigation_fix01_20261005/enemy_director.gd")
const Binding = preload("res://tests/ink_e1_ordinary_20261005/candidate01/live_binding.gd")
const BEFORE_PATH := "res://tests/ink_q3_foundation_20261004/ink_q3_enemy_director.gd"
static func apply_to_fresh_ink_sim(sim: Node) -> Dictionary:
 var admitted: Dictionary = Binding.read_capabilities(sim,true)
 if not admitted.accepted: return admitted
 if sim.hero.actor_id != "yanguizhou": return {"accepted":false,"reason":"ink_hero_required"}
 if sim.phase != "preparation" or sim.wave != 0 or sim.transaction_active or not sim.enemies.is_empty(): return {"accepted":false,"reason":"fresh_preparation_only"}
 if sim.enemy_director.get_script().resource_path != BEFORE_PATH: return {"accepted":false,"reason":"expected_original_q3_director_required"}
 if sim.enemy_director.time != 0.0 or sim.enemy_director.commits != 0 or sim.enemy_director.projectile_serial != 0: return {"accepted":false,"reason":"unused_director_required"}
 sim.enemy_director = Candidate.new()
 return {"accepted":true,"reason":"","scope":"exact_q2_with_retained_ink_host_navigation","production_promoted":false}
