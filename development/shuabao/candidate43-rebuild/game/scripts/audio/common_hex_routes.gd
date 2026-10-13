extends RefCounted
## Read-only event selection shared by arena routers. Never infers a future hit.
## `damage` is HP-committed; common_hex_damage is the earlier nominal effect packet
## re-emitted by the bridge AFTER application, including rejected/dead targets.
const IDS := ["hx_soul_spawn", "hx_soul_pickup", "hx_corpse_launch", "hx_corpse_impact", "hx_bomb_warning", "hx_bomb_impact", "hx_rescue", "hx_shrink", "hx_missile_launch", "hx_missile_contact", "hx_replay", "hx_turret_deploy", "hx_turret_fire", "hx_potion_pulse"]
const MAX_COMMON_VOICES := 3 # Within the existing ordinary pool, never warning voices.
const INTERVALS := {"hx_soul_spawn":0.18, "hx_soul_pickup":0.16, "hx_corpse_launch":0.10, "hx_corpse_impact":0.10, "hx_bomb_warning":0.16, "hx_bomb_impact":0.16, "hx_rescue":0.20, "hx_shrink":0.16, "hx_missile_launch":0.12, "hx_missile_contact":0.10, "hx_replay":0.10, "hx_turret_deploy":0.16, "hx_turret_fire":0.18, "hx_potion_pulse":0.18}
const OWNED_DAMAGE := ["common_g11", "common_g12", "common_g16", "common_g18", "common_g23", "common_g28"]
var seen: Dictionary = {}
var last_time: Dictionary = {}
var groups: Dictionary = {}
var generation := -1
var ended := false

func reset() -> void:
 seen.clear(); last_time.clear(); groups.clear(); generation = -1; ended = false

func end_room() -> void:
 ended = true
 seen.clear(); groups.clear(); last_time.clear()

func route(event: Dictionary) -> Dictionary:
 var kind: String = str(event.get("kind", ""))
 var source: String = str(event.get("source", ""))
 var common_kind: bool = kind.begins_with("common_hex_")
 var handled: bool = common_kind or (kind == "damage" and source in OWNED_DAMAGE) or (kind == "shield" and source == "common_g13")
 if not handled: return {"handled":false, "id":""}
 # A room-ready packet is authoritative for encounter generation. Late packets
 # cannot reset the scope and resurrect a cancelled projectile's contact.
 if kind == "common_hex_room_ready":
  var incoming_generation: int = int(event.get("generation", -1))
  if generation >= 0 and incoming_generation <= generation:
   return {"handled":true, "id":""}
  reset()
  generation = incoming_generation
  return {"handled":true, "id":""}
 if ended: return {"handled":true, "id":""}
 if event.has("generation") and generation >= 0 and int(event.generation) != generation:
  return {"handled":true, "id":""}
 var event_id: String = str(event.get("event_id", ""))
 if not event_id.is_empty():
  if seen.has(event_id): return {"handled":true, "id":""}
  seen[event_id] = true
  if seen.size() > 512: seen.erase(seen.keys()[0])
 var id := ""
 match kind:
  "common_hex_soul_spawn": id = "hx_soul_spawn"
  "common_hex_soul_pickup": id = "hx_soul_pickup"
  "common_hex_execute": id = "hx_corpse_launch"
  "common_hex_bombardment_warning":
   if float(event.get("delay",0)) > 0: id = "hx_bomb_warning"
  "common_hex_area_effect":
   # Actual area detonation, not a target-hit confirmation: an empty explosion
   # still makes its material burst. Damage packets below never double it.
   id = {"common_g11":"hx_corpse_impact", "common_g12":"hx_bomb_impact", "common_g23":"hx_potion_pulse"}.get(source, "")
  "common_hex_heal":
   # Bridge supplies heal_actor's committed return value, including zero for a
   # full-health, dead or missing target. Nominal amount is never sufficient.
   if float(event.get("applied_amount",0)) > 0:
    id = {"common_g13":"hx_rescue", "common_g18":"hx_replay"}.get(source, "")
  "shield":
   if float(event.get("amount",0)) > 0: id = "hx_rescue"
  "common_hex_enemy_modifiers":
   if float(event.get("duration",0)) > 0: id = "hx_shrink"
  "common_hex_missiles_fired":
   if int(event.get("count",0)) > 0: id = "hx_missile_launch"
  "common_hex_turret_spawn":
   if float(event.get("duration",0)) > 0: id = "hx_turret_deploy"
  "damage":
   if float(event.get("amount",0)) > 0:
    id = {"common_g16":"hx_missile_contact", "common_g18":"hx_replay", "common_g28":"hx_turret_fire"}.get(source, "")
 # No cue from common_hex_damage/shield: nominal duplicates cannot certify
 # contact. G18 damage replays use the committed packet; heals need applied_amount.
 if id.is_empty(): return {"handled":true, "id":""}
 var now: float = float(event.get("world_time",0.0))
 var group: String = "%s:%s:%s" % [id, event.get("cast_id",event.get("action_id",0)), now]
 if groups.has(group): return {"handled":true, "id":""}
 groups[group] = true
 if groups.size() > 256: groups.erase(groups.keys()[0])
 # Per-family combat-clock window coalesces crowd/chain/volley events. No queue
 # is kept, so pause, mute, pool saturation and room cancellation cannot replay.
 if now - float(last_time.get(id,-1000.0)) < float(INTERVALS[id]):
  return {"handled":true, "id":""}
 last_time[id] = now
 return {"handled":true, "id":id}
