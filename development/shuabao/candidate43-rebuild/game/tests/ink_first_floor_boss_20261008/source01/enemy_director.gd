extends "res://tests/ink_ultimate_presentation_20261006/r1_consumer01/timed_director.gd"
## Opt-in composition at the existing Director seam. Ordinary actors and all
## existing hero/source/control/reward ownership retain exact parent delegation.
const BossController = preload("res://tests/ink_first_floor_boss_20261008/source01/boss_controller.gd")
var boss_controller = BossController.new()

func begin_step(sim, dt: float) -> void:
 boss_controller.prune(self,sim)
 super.begin_step(sim,dt)

func step_enemy(sim, enemy: Dictionary, dt: float) -> void:
 if enemy.kind != "boss":
  super.step_enemy(sim,enemy,dt)
  return
 boss_controller.step(self,sim,enemy,dt)

func snapshot(sim, enemy: Dictionary) -> Dictionary:
 return boss_controller.snapshot(sim,enemy)

func cancel_boss_casts(sim, reason: String) -> void:
 for enemy: Dictionary in sim.enemies:
  if enemy.kind == "boss": boss_controller.cancel(sim,enemy,reason)
