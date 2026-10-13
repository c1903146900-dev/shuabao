extends "res://scripts/audio/combat_audio.gd"
## Eight ordinary voices plus three reserved enemy-telegraph voices.
## Telegraphs cannot disappear because a large target-hit group filled the ordinary pool.
const XUANLEI_IDS := ["xl_heft", "xl_door", "xl_guard", "xl_chain", "xl_charge", "xl_stone", "xl_fortress", "xl_warning_melee", "xl_warning_ranged", "xl_warning_pouncer", "xl_warning_elite", "xl_warning_armored", "xl_warning_boss", "xl_warning_pitcher", "xl_warning_support", "xl_shot"]
const CommonHex = preload("res://scripts/audio/common_hex_routes.gd")
const AttackBank = preload("res://scripts/audio/xuanlei_attack_bank.gd")
const WARNING_VOICES := 3
const ATTACK_CANCEL_FADE_SECONDS := 0.018
var _attack_next: Dictionary = {}
var _attack_fades: Dictionary = {}
var _warning_players: Array[AudioStreamPlayer] = []
var _warning_clock := 0.0
var _warning_last: Dictionary = {}
func _ready() -> void:
 super._ready()
 for id in XUANLEI_IDS + CommonHex.IDS:
  var resource := load("res://assets/audio/%s.wav" % id) as AudioStream
  _streams[id] = [resource] if resource != null else []
 _streams.merge(AttackBank.load_streams())
 for i in range(WARNING_VOICES):
  var player:=AudioStreamPlayer.new()
  player.name="TelegraphVoice%d"%i
  player.bus=_bus_name
  player.volume_db=HEADROOM_DB+1.0
  player.max_polyphony=1
  add_child(player)
  _warning_players.append(player)
func _process(delta:float)->void:
 _warning_clock+=maxf(0,delta)
 _advance_attack_fades(maxf(0,delta))
func _event_clock_usec()->int:
 return int(_warning_clock*1000000.0) if OS.has_feature("movie") else Time.get_ticks_usec()
func play_event(id:String)->bool:
 _prune_attack_fades()
 if id in AttackBank.IDS: return _play_attack(id)
 if id.begins_with("hx_"):
  var active_common := 0
  for player in _players:
   if player.playing and str(player.get_meta("sound_id", "")).begins_with("hx_"): active_common += 1
  if active_common >= CommonHex.MAX_COMMON_VOICES: return false
  # Retain the ordinary pool's headroom, throttle and no-steal policy.
  return super.play_event(id)
 if not id.begins_with("xl_warning_"): return super.play_event(id)
 if muted or not _streams.has(id) or _streams[id].is_empty():return false
 # World presentation delta also works in the engine's offline movie/audio writer.
 if _warning_clock-float(_warning_last.get(id,-10.0))<0.04:return false
 for player in _warning_players:
  if player.playing:continue
  player.stream=_streams[id][0]
  player.pitch_scale=1.0
  player.set_meta("sound_id",id)
  player.play()
  _warning_last[id]=_warning_clock
  return true
 return false
func play_attack_event(id: String, cast_key: String) -> bool:
 _prune_attack_fades()
 return _play_attack(id, cast_key) if id in AttackBank.IDS else false
func _play_attack(id: String, cast_key: String = "") -> bool:
 if muted or not _streams.has(id) or _streams[id].is_empty(): return false
 var now := _event_clock_usec()
 if _last_usec.has(id) and now - int(_last_usec[id]) < MIN_INTERVAL_USEC: return false
 var active_for_id := 0
 var active_attacks := 0
 var available: AudioStreamPlayer = null
 for player in _players:
  if player.playing:
   var playing_id: String = str(player.get_meta("sound_id", ""))
   if playing_id == id: active_for_id += 1
   if playing_id.begins_with("xa_"): active_attacks += 1
  elif available == null: available = player
 if available == null or active_for_id >= PER_EVENT_LIMIT or active_attacks >= AttackBank.MAX_ATTACK_VOICES: return false
 var bank: Array = _streams[id]
 var variant: int = int(_attack_next.get(id, 0)) % bank.size()
 available.stream = bank[variant]
 available.volume_db = HEADROOM_DB
 available.pitch_scale = 1.0 # Timing/timbre are authored, never a random pitch copy.
 available.set_meta("sound_id", id)
 available.set_meta("attack_cast", cast_key)
 available.play()
 _attack_next[id] = (variant + 1) % bank.size()
 _last_usec[id] = now
 return true
func cancel_attack_movement(room: String, cast_ids: Array) -> void:
 # Fade only a still-playing release belonging to this cancelled basic cast.
 # Contacts, unrelated casts and the separate telegraph players are untouched.
 var keys: Dictionary = {}
 for cast_id in cast_ids: keys["%s:%s" % [room, cast_id]] = true
 for player in _players:
  if not player.playing or not str(player.get_meta("sound_id", "")).begins_with("xa_swing_"): continue
  var cast_key: String = str(player.get_meta("attack_cast", ""))
  if not keys.has(cast_key) or _attack_fades.has(player): continue
  _attack_fades[player] = {"cast_key":cast_key,"left":ATTACK_CANCEL_FADE_SECONDS,"start_db":player.volume_db}
func _prune_attack_fades() -> void:
 # A naturally finished voice can be reused by the ordinary bank. Restore its
 # volume before allocation so an interrupted swing cannot quiet a later cue.
 for player in _attack_fades.keys():
  if not player.playing or str(player.get_meta("attack_cast", "")) != str(_attack_fades[player].cast_key):
   player.volume_db = HEADROOM_DB
   _attack_fades.erase(player)
func _advance_attack_fades(delta: float) -> void:
 _prune_attack_fades()
 for player in _attack_fades.keys():
  var state: Dictionary = _attack_fades[player]
  state.left = maxf(0.0, float(state.left) - delta)
  if float(state.left) <= 0.0:
   player.stop()
   player.volume_db = HEADROOM_DB
   _attack_fades.erase(player)
  else:
   var fraction: float = float(state.left) / ATTACK_CANCEL_FADE_SECONDS
   var amplitude: float = pow(sin(fraction * PI * 0.5), 2.0)
   player.volume_db = float(state.start_db) + linear_to_db(maxf(amplitude, 0.00001))
func stop_all()->void:
 super.stop_all()
 for player in _attack_fades.keys(): player.volume_db = HEADROOM_DB
 _attack_fades.clear()
 for player in _warning_players:player.stop()
 _warning_last.clear()
func snapshot()->Dictionary:
 var out:Dictionary=super.snapshot()
 var active:=0
 for player in _warning_players:
  if player.playing:
   active+=1
   out.voices.append({"id":player.get_meta("sound_id"),"stream":player.stream.resource_path,"playing":true,"position":player.get_playback_position(),"pitch":player.pitch_scale,"volume_db":player.volume_db,"bus":player.bus,"priority":"telegraph"})
 out.warning_active=active
 out.ordinary_active=out.active
 out.active+=active
 out.limit=MAX_VOICES+WARNING_VOICES
 return out
func _exit_tree()->void:
 for player in _warning_players:
  player.stop();player.stream=null
 _warning_players.clear()
 super._exit_tree()
