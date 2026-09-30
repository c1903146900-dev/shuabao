extends Node3D
## 仅用于验证项目启动；战斗、网络和存档留给后续模块。


func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		$UI/Margin/Column/Quit.grab_focus()
	print("SHUABAO_BOOT_OK")


func _on_quit_pressed() -> void:
	get_tree().quit()
