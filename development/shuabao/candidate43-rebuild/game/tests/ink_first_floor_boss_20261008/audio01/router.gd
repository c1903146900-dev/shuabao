extends "res://tests/ink_skill_audio_20261008/composed03/router.gd"
## One additional detached family in the existing router, not another output.
const BossAudio=preload("res://tests/ink_first_floor_boss_20261008/audio01/consumer.gd")
func _init() -> void:
 family_consumers["boss"]=BossAudio.new()
func snapshot() -> Dictionary:
 var out: Dictionary=super.snapshot()
 out["composition"]="composed03_plus_first_floor_boss_same_four_voice_output"
 return out
