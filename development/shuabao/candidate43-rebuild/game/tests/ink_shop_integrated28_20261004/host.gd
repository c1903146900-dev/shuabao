extends "res://tests/ink_shop_audio_fix_20261004/host.gd"
const DeathPresenter = preload("res://tests/ink_victory_death_pose_20261004/death_presenter.gd")
var death_presenter: RefCounted = DeathPresenter.new()

func _refresh(delta: float) -> void:
	super._refresh(delta)
	death_presenter.present_host(self)

func _write_json(filename: String, contents: Dictionary) -> void:
	var output: Dictionary = contents.duplicate(true)
	output["enemy_death_pose"] = death_presenter.report.duplicate(true)
	super._write_json(filename, output)
