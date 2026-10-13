extends RefCounted
## The tested core constructor already installed this exact navigation subclass.
## Admit it once at fresh construction; never replace a live director or its state.
const Binding = preload("res://tests/ink_rest_service_20261006/candidate01/ordinary01/live_binding.gd")
static func apply_to_fresh_ink_sim(sim: Node) -> Dictionary:
 var admitted: Dictionary = Binding.read_capabilities(sim,true)
 if not admitted.accepted: return admitted
 if sim.phase != "preparation" or sim.wave != 0 or sim.transaction_active or not sim.enemies.is_empty(): return {"accepted":false,"reason":"fresh_preparation_only"}
 if sim.enemy_director.time != 0.0 or sim.enemy_director.commits != 0 or sim.enemy_director.projectile_serial != 0: return {"accepted":false,"reason":"unused_director_required"}
 if sim.has_meta("p1_navigation_admitted"): return {"accepted":false,"reason":"navigation_already_admitted"}
 sim.set_meta("p1_navigation_admitted",true)
 return {"accepted":true,"reason":"","constructor_installed":true,"director_replaced":false,"ordinary_validation_passed":false}
