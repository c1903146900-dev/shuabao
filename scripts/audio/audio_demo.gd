extends Control
const AudioComponent = preload("res://scripts/audio/combat_audio.gd")
const KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_Q, KEY_E, KEY_R, KEY_C, KEY_X, KEY_L, KEY_V]
var sfx: CombatAudio
var status: Label

func _ready() -> void:
	sfx = AudioComponent.new()
	sfx.name = "CombatAudio"
	add_child(sfx)
	var background := ColorRect.new()
	background.color = Color("101b2c")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var panel := VBoxContainer.new()
	panel.position = Vector2(70, 35)
	panel.add_theme_constant_override("separation", 7)
	add_child(panel)
	var title := Label.new()
	title.text = "SHUABAO / COMBAT AUDIO LAB"
	title.add_theme_font_size_override("font_size", 30)
	panel.add_child(title)
	var info := Label.new()
	info.text = "Original synthesized SFX | 8 voices / 2 per event | M mute | - / = volume\nCloud checks use Dummy audio: runtime verified, not listening-tested."
	panel.add_child(info)
	for i in AudioComponent.IDS.size():
		var id: String = AudioComponent.IDS[i]
		var button := Button.new()
		button.text = "%s     %s" % [OS.get_keycode_string(KEYS[i]), id]
		button.custom_minimum_size = Vector2(610, 30)
		button.pressed.connect(func(): sfx.play_event(id))
		panel.add_child(button)
	status = Label.new()
	panel.add_child(status)

func _process(_delta: float) -> void:
	status.text = "Voices: %d / 8   Volume: %.1f dB   Muted: %s" % [sfx.snapshot().active, sfx.volume_db, sfx.muted]

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var index := KEYS.find(event.keycode)
	if index >= 0:
		sfx.play_event(AudioComponent.IDS[index])
	elif event.keycode == KEY_M:
		sfx.set_muted(not sfx.muted)
	elif event.keycode == KEY_MINUS:
		sfx.set_volume_db(sfx.volume_db - 3)
	elif event.keycode == KEY_EQUAL:
		sfx.set_volume_db(sfx.volume_db + 3)
