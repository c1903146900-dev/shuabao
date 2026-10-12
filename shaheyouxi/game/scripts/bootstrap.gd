extends Control
## Batch 001 launch harness, not gameplay.

func _ready() -> void:
	print("SHAHEYOUXI_BOOTSTRAP_READY project=shaheyouxi_experiment_20261004 batch=001")
	if "--smoke-test" in OS.get_cmdline_user_args():
		get_tree().quit(0)
