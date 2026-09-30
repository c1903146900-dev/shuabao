extends "res://scripts/combat/arena.gd"
## Test-only scene root. Live gameplay uses fengli_arena.tscn without these fixtures.
func run_core_tests() -> Dictionary:
 return preload("res://tests/combat/tests_core.gd").new().run()
func fixture_training() -> Dictionary:
 new_run()
 simulation.ai_enabled = false
 simulation.auto_finish = false
 simulation.hero.stats.regen = 0
 return get_combat_snapshot()
func fixture_warning() -> void:
 new_run()
 manual_step = true
 var enemy: Dictionary = simulation.enemies[-1]
 enemy.position = Vector3(0,0,0)
 enemy.aim = Vector3.BACK
 enemy.state = "warning"
 enemy.attack_shape = "cone"
 enemy.warning_progress = 0.65
 enemy.timer = 0.4
 simulation.hero.position = Vector3(0,0,3)
 _sync_views(0)
func fixture_ultimate() -> void:
 new_run()
 manual_step = true
 simulation.hero.position = Vector3.ZERO
 simulation.request_action("r")
 simulation.step(0.31)
 _sync_views(0)
func fixture_victory() -> void:
 new_run()
 manual_step = true
 simulation.end_encounter("victory")
 _sync_views(0)
