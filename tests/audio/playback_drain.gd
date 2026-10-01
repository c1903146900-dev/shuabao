extends RefCounted
## Tests hold WeakRefs only. stop() queues an audio-thread fade/removal, so two
## fast headless process frames are not proof that the mix thread has reclaimed it.
var watched: Dictionary = {}

func watch(component: Node) -> void:
	for player in component.get_children():
		if player is AudioStreamPlayer:
			if player.stream != null:
				watched[player.stream.get_instance_id()] = weakref(player.stream)
			if player.has_stream_playback():
				var playback: AudioStreamPlayback = player.get_stream_playback()
				watched[playback.get_instance_id()] = weakref(playback)

func remaining() -> int:
	var count := 0
	for ref: WeakRef in watched.values():
		if ref.get_ref() != null:
			count += 1
	return count

func wait_for_release(tree: SceneTree) -> Dictionary:
	var start := Time.get_ticks_msec()
	var before := remaining()
	while remaining() > 0 and Time.get_ticks_msec() - start < 2000:
		await tree.create_timer(.02).timeout
	# Deferred thread-safe reclamation gets another main-thread update as well.
	await tree.process_frame
	return {"tracked": watched.size(), "pending_at_start": before, "remaining": remaining(),
		"elapsed_ms": Time.get_ticks_msec() - start, "passed": remaining() == 0}
