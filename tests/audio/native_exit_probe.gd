extends SceneTree
# Control: no CombatAudio, signal handlers, test snapshots or custom bus.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var player := AudioStreamPlayer.new()
	root.add_child(player)
	player.stream = load("res://assets/audio/settlement.wav")
	player.play()
	var playback_ref: WeakRef = weakref(player.get_stream_playback())
	var stream_ref: WeakRef = weakref(player.stream)
	player.stop()
	player.stream = null
	player.free()
	await process_frame
	await process_frame
	print("NATIVE_TWO_FRAMES ", JSON.stringify({"playback_alive": playback_ref.get_ref() != null, "stream_alive": stream_ref.get_ref() != null}))
	if "--drain" in OS.get_cmdline_user_args():
		var deadline := Time.get_ticks_msec() + 2000
		while playback_ref.get_ref() != null and Time.get_ticks_msec() < deadline:
			await create_timer(.02).timeout
		print("NATIVE_DRAINED ", JSON.stringify({"playback_alive": playback_ref.get_ref() != null, "stream_alive": stream_ref.get_ref() != null}))
	quit.call_deferred()
