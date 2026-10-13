extends Node
## Actual isolated bus PCM measurement. Bus PCM is not OS-loopback or human hearing proof.
const ROUTER_PATH:="res://tests/ink_benchmark_audio_20261004/router.gd"
const BANK_PATH:="res://tests/ink_benchmark_audio_20261004/bank.gd"
var router: RefCounted
var players: Array[AudioStreamPlayer]=[]
var slots: Array=[]
var bus_name:=""
var capture: AudioEffectCapture
var commands: Array=[]
var dropped: Array=[]
var pcm_frames:=0
var pcm_nonzero_frames:=0
var pcm_peak:=0.0
var pcm_square_sum:=0.0
var initialized:=false
var stream_cache: Dictionary={}
func _ready() -> void:
	if not ResourceLoader.exists(ROUTER_PATH):return
	var source: Script=load(ROUTER_PATH)
	router=source.new()
	bus_name="InkSpecimen_"+str(get_instance_id())
	AudioServer.add_bus()
	var index:=AudioServer.bus_count-1
	AudioServer.set_bus_name(index,bus_name)
	AudioServer.set_bus_send(index,"Master")
	capture=AudioEffectCapture.new();capture.buffer_length=2.0
	AudioServer.add_bus_effect(index,capture)
	for i in range(4):
		var player:=AudioStreamPlayer.new()
		player.bus=bus_name;add_child(player);players.append(player)
		slots.append({"priority":-1,"started_usec":0})
	initialized=true
func consume(event: Dictionary, snapshot: Dictionary) -> void:
	if router!=null:_apply(router.consume(event.duplicate(true),snapshot.duplicate(true)))
func set_paused(paused: bool) -> void:
	if router!=null:_apply(router.set_paused(paused))
func restart_scope() -> void:
	if router!=null:
		_apply(router.reset())
		_apply(router.set_paused(false))
func clear() -> void:
	if router!=null:_apply(router.clear("host_lifecycle"))
func _apply(items: Array) -> void:
	for command: Dictionary in items:
		commands.append(command.duplicate(true))
		if command.get("action","")=="stop_all":
			for player in players:player.stop()
			continue
		if command.get("action","")!="play":continue
		var path:=str(command.get("path",""))
		if not ResourceLoader.exists(path):dropped.append({"reason":"missing_stream","command":command});continue
		if not stream_cache.has(path):
			var stream: AudioStream=load(path)
			if stream is AudioStreamWAV:
				stream=stream.duplicate(true)
				stream.loop_mode=AudioStreamWAV.LOOP_DISABLED
			stream_cache[path]=stream
		var slot:=-1
		for i in range(players.size()):
			if not players[i].playing:slot=i;break
		if slot<0:
			for i in range(players.size()):
				if int(slots[i].priority)<=int(command.get("priority",0)) and (slot<0 or int(slots[i].started_usec)<int(slots[slot].started_usec)):slot=i
		if slot<0:dropped.append({"reason":"voice_budget","command":command});continue
		players[slot].stop()
		players[slot].stream=stream_cache[path]
		players[slot].volume_db=float(command.get("gain_db",-6.0))
		players[slot].pitch_scale=1.0
		players[slot].play()
		slots[slot]={"priority":command.get("priority",0),"started_usec":Time.get_ticks_usec()}
func _process(_delta: float) -> void:
	if capture==null:return
	var count:=capture.get_frames_available()
	if count<=0:return
	var frames:=capture.get_buffer(count)
	for frame: Vector2 in frames:
		pcm_frames+=1
		var amplitude:=maxf(absf(frame.x),absf(frame.y))
		pcm_peak=maxf(pcm_peak,amplitude)
		pcm_square_sum+=float(frame.x*frame.x+frame.y*frame.y)*.5
		if amplitude>.000001:pcm_nonzero_frames+=1
func status_text() -> String:
	if not initialized:return "待接线"
	if pcm_nonzero_frames==0:return "已接线，PCM未证实"
	return "总线PCM有信号，听感待验"
func report() -> Dictionary:
	return {"initialized":initialized,"status":status_text(),"capture_scope":"actual isolated audio-bus PCM only; not OS loopback, speaker audibility or hearing approval","commands":commands,"dropped":dropped,"pcm_frames":pcm_frames,"pcm_nonzero_frames":pcm_nonzero_frames,"pcm_peak":pcm_peak,"pcm_rms":sqrt(pcm_square_sum/maxi(1,pcm_frames)),"mix_rate":AudioServer.get_mix_rate(),"max_voices":4,"all_zero_is_success":false,"heard_or_accepted":false}
func _exit_tree() -> void:
	if not bus_name.is_empty():
		var index:=AudioServer.get_bus_index(bus_name)
		if index>=0:AudioServer.remove_bus(index)
