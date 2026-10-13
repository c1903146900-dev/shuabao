extends SceneTree
const Sim = preload("res://tests/ink_river_hexes_20261006/ownership01/sim.gd")
const T = preload("res://tests/ink_q1_foundation_20261004/revision02/scripts/ink_tuning.gd")
const REQUIRED_GROUPS = ["p1_complete_river_and_sunset", "p1_terminal_pause_and_victory", "p2_new_use_sunset_entitlement", "original_packet_scope_and_retirement"]
var checks: int = 0
var failures: Array[String] = []
var completed: Array[String] = []
var observations: Dictionary = {}
var output_path: String = ""
var serial: int = 0

func _initialize() -> void:
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--river-ownership-result="): output_path=arg.trim_prefix("--river-ownership-result=")
 run.call_deferred()

func check(ok: bool, label: String) -> void:
 checks+=1
 if not ok: failures.append(label); push_error(label)

func near(a: float, b: float, label: String) -> void:
 check(is_finite(a) and absf(a-b)<0.0001,label+" actual="+str(a)+" expected="+str(b))

func fresh(passive: String = "p1", rank: int = 1, hexes: Array = ["yanguizhou_h03","yanguizhou_h04"]):
 serial+=1
 var sim=Sim.new(); root.add_child(sim)
 sim.auto_finish=false; sim.ai_enabled=false; sim.obstacles=[]; sim.arena_half_extent=30.0
 sim.hero.loadout.q="q2"; sim.hero.ranks.q=rank
 sim.hero.loadout.e="e3"; sim.hero.ranks.e=1
 sim.hero.loadout.r="r2"; sim.hero.ranks.r=1
 sim.hero.loadout.passive=passive; sim.hero.ranks.passive=1
 sim.set_projected_stats({"AP":100.0,"move_speed":10.0,"defence":0.0,"crit_chance":0.0,"regen":0.0,"lifesteal":0.2,"cdr":0.0})
 check(sim.begin_encounter("river-ownership-fixture-%d"%serial,[]).accepted,"exact current parent encounter")
 sim.hero.position=Vector3.ZERO; sim.set_hexes(hexes)
 return sim

func target(sim, at: Vector3, hp: float = 100000.0) -> Dictionary:
 var enemy: Dictionary=sim.spawn_enemy("minion",at,hp)
 enemy.state="chase"; enemy.defence=0; enemy.radius=0.1
 return enemy

func river(sim, x: float = 0.0, bends: bool = false) -> Dictionary:
 sim.hero.loadout.q="q2"; sim.hero.cooldowns.q=0.0
 check(sim.request_q2("first",Vector3(x,0,-4)).accepted,"real Q2 A")
 if bends:
  check(sim.request_q2("corner",Vector3(x+2,0,-3)).accepted,"real first H03 bend")
  check(sim.request_q2("corner",Vector3(x+2,0,-1)).accepted,"real second H03 bend")
 check(sim.request_q2("second",Vector3(x,0,0)).accepted,"real Q2 B")
 return sim.ink_rivers.back()

func q1(sim) -> int:
 sim.hero.loadout.q="q1"; sim.hero.cooldowns.q=0.0
 check(sim.request_ink_input("q_down").accepted,"real fill Q1 arm")
 check(sim.request_ink_input("left_down",Vector3.ZERO).accepted,"real fill Q1 down")
 check(sim.request_ink_input("motion",Vector3(0.26,0,0)).accepted,"real fill Q1 draw")
 var result: Dictionary=sim.request_ink_input("left_up",Vector3(0.26,0,0))
 check(result.accepted,"real fill Q1 completes")
 return int(result.cast_id)

func fill(sim, keep_rivers: bool = false) -> Array:
 var ids: Array=[]
 for index in range(4):
  var id: int
  if index%2==0:
   id=q1(sim); sim.cancel_cast(id)
  else:
   var state: Dictionary=river(sim,-5.0 if index==1 else 5.0)
   id=int(state.cast_id)
   if not keep_rivers: sim.cancel_cast(id)
  ids.append(id)
 check(sim.p2.stacks==3 and sim.p2.ready_epoch>0,"real four alternating uses create three stacks")
 return ids

func packets(sim, source: String) -> Array:
 return sim.event_log.filter(func(event): return event.kind=="damage" and str(event.get("source",""))==source)

func sunset(sim, id: int = -1) -> Array:
 return sim.ink_q2_receipts.filter(func(hit): return hit.kind=="sunset" and (id<0 or int(hit.cast_id)==id))

func receipt(sim, id: int) -> Dictionary:
 for found: Dictionary in sim.ink_p1_receipts:
  if int(found.cast_id)==id: return found
 return {}

func done_group(name: String) -> void:
 completed.append(name); print("INK_RIVER_OWNERSHIP_GROUP ",name)

func p1_complete_river_and_sunset() -> void:
 var sim=fresh(); var enemy: Dictionary=target(sim,Vector3.ZERO)
 sim.hero.hp=100.0
 var state: Dictionary=river(sim,0.0,true); var id: int=int(state.cast_id)
 check(sim.p1.roots.has(id) and sim._p1_q2_owned_river(state),"H03/H04 no longer cancels the real P1 root")
 check(state.path.size()==4 and sim.p1.roots[id].targets.size()==1,"all H03 legs retain one root and immediate river contact")
 sim.step(3.98)
 check(receipt(sim,id).is_empty() and sunset(sim,id).size()==7,"P1 waits beyond seven H04 ticks")
 sim.step(0.02)
 var paid: Dictionary=receipt(sim,id)
 check(not paid.is_empty() and paid.qualified and paid.distinct_targets==1,"whole river plus eight ticks settles one qualified P1")
 near(paid.final_basis,454.0,"P1 collects base 150 and all H04 304 actual damage")
 check(paid.ordinary_packet_count==9,"one river packet plus eight sunset packets, no duplicate legs")
 near(paid.requested_supplement,454.0*T.fraction("P1-1",1),"whole-Q2 final supplement uses source P1 fraction")
 near(paid.cooldown_before,6.5,"P1 refunds current cooldown only at whole expiry")
 near(paid.cooldown_refund,6.5*T.fraction("P1-2",1),"current cooldown refund occurs once")
 near(100000.0-float(enemy.hp),454.0+float(paid.actual_supplement),"real health includes one final correction")
 check(sim.ink_p1_lifesteal_receipts.size()==1,"one existing B09 supplement lifesteal receipt")
 var heal: Dictionary=sim.ink_p1_lifesteal_receipts[0]
 near(heal.source_factor,0.4,"existing area supplement lifesteal factor")
 near(heal.actual_heal,float(paid.actual_supplement)*0.2*0.4,"supplement lifesteal uses actual damage and existing health authority")
 check(sim.ink_p2_claims.is_empty() and packets(sim,"yanguizhou_p1").size()==1,"P1 supplement neither consumes P2 nor repeats itself")
 for event: Dictionary in packets(sim,"hex_yanguizhou_h04"):
  check(event.hex_generated and not event.critical and int(event.cast_id)==id,"original H04 source/provenance/critical state retained")
 observations.p1_complete=paid.duplicate(true); sim.free()
 sim=fresh(); enemy=target(sim,Vector3(1,0,0)); state=river(sim); id=int(state.cast_id)
 check(sim.ink_q2_receipts.is_empty(),"outside river enemy is H04-only")
 sim.step(4.0); paid=receipt(sim,id)
 check(not paid.is_empty() and paid.qualified and paid.ordinary_packet_count==8,"H04-only single target belongs to the Q2 root")
 near(paid.final_basis,304.0,"H04-only full damage basis")
 sim.free()
 sim=fresh(); target(sim,Vector3.ZERO); target(sim,Vector3(1.5,0,0)); state=river(sim); id=int(state.cast_id)
 check(sim.p1.roots[id].targets.size()==1,"base river initially sees only one enemy")
 sim.step(4.0); paid=receipt(sim,id)
 check(not paid.is_empty() and not paid.qualified and paid.distinct_targets==2,"H04 second enemy disqualifies whole Q2 single-target reward")
 check(packets(sim,"yanguizhou_p1").is_empty(),"no early supplement from base river alone")
 sim.free(); done_group(REQUIRED_GROUPS[0])

func p1_terminal_pause_and_victory() -> void:
 var sim=fresh(); target(sim,Vector3.ZERO); target(sim,Vector3(0.2,0,0))
 var state: Dictionary=river(sim); var id: int=int(state.cast_id)
 var paused_once: Dictionary={"done":false}
 sim.combat_event.connect(func(event: Dictionary):
  if event.kind=="ink_h04_contact" and int(event.tick)==8 and not paused_once.done:
   paused_once.done=true
   sim._q2_finish(state,"expired",float(state.expires_at))
   sim.paused=true)
 sim.step(4.0)
 check(sim.paused and paused_once.done and sunset(sim,id).size()==15,"last tick first target pauses with a real remaining packet")
 check(not bool(state.retired) and receipt(sim,id).is_empty() and not sim.p1.roots[id].complete,"callback terminal attempt cannot complete a partial last tick")
 check(not sim.river_hex_terminal_deferrals.is_empty(),"same-source-time early terminal is explicitly deferred")
 sim.paused=false; sim.step(0.02)
 check(sunset(sim,id).size()==16 and sim.ink_q2_finished.size()==1,"resume delivers last original once before terminal")
 check(receipt(sim,id).distinct_targets==2 and not receipt(sim,id).qualified,"full paused batch participates in one P1 decision")
 check(sim._river_hex_packet_frames.is_empty() and sim.p1.roots[id].depth==0,"original packet and collector barriers unwind")
 sim.free()
 # Rank six: last H04 kills at four seconds, while the original river must
 # remain until six seconds. Capture completion before normal victory cleanup.
 sim=fresh("p1",6); var enemy: Dictionary=target(sim,Vector3.ZERO,830.0)
 state=river(sim); id=int(state.cast_id); sim.auto_finish=true
 var done: Dictionary={"paid":{},"terminals":0,"kills":0}
 sim.combat_event.connect(func(event: Dictionary):
  if event.kind=="ink_p1_settled" and int(event.cast_id)==id: done.paid=event.duplicate(true)
  elif event.kind=="ink_q2_finished" and int(event.cast_id)==id: done.terminals+=1
  elif event.kind=="kill" and int(event.get("cast_id",0))==id: done.kills+=1)
 sim.step(4.0)
 check(enemy.dead and done.kills==1,"eighth H04 performs actual capped lethal original")
 check(sim.phase=="combat" and sim._hero_victory_pending(),"last H04 kill cannot end the longer live river")
 check(done.paid.is_empty() and done.terminals==0,"four-second sunset expiry is not six-second Q2 completion")
 sim.step(1.98); check(sim.phase=="combat" and done.paid.is_empty(),"whole source lifetime still pending before six seconds")
 sim.step(0.02)
 check(sim.phase=="victory" and done.terminals==1 and not done.paid.is_empty(),"real whole-root terminal settles then releases victory")
 near(done.paid.final_basis,830.0,"P1 basis uses actual capped original damage")
 check(done.paid.target_status=="already_dead" and done.paid.actual_supplement==0.0 and done.kills==1,"final correction cannot revive or kill the original twice")
 sim.free(); done_group(REQUIRED_GROUPS[1])

func p2_new_use_sunset_entitlement() -> void:
 var sim=fresh("p2"); var roots: Array=fill(sim,true)
 target(sim,Vector3(-4,0,0)); target(sim,Vector3(6,0,0))
 sim.step(0.5)
 check(sunset(sim,int(roots[1])).size()==1 and sunset(sim,int(roots[3])).size()==1,"old and ready-forming rivers both deliver real H04")
 check(sim.ink_p2_claims.is_empty() and sim.p2.stacks==3,"old H04 and filling-cast H04 cannot steal the ready epoch")
 var next: Dictionary=river(sim); var id: int=int(next.cast_id)
 var enemy: Dictionary=target(sim,Vector3(1,0,0))
 check(sim.p2.packet_entitled(id,"q2") and sim.ink_p2_claims.is_empty(),"new complete Q2 has current entitlement but no base river contact")
 var callback: Dictionary={"seen":false,"claimed_before_signal":false}
 sim.combat_event.connect(func(event: Dictionary):
  if event.kind=="damage" and event.get("source","")=="hex_yanguizhou_h04" and int(event.cast_id)==id and not callback.seen:
   callback.seen=true
   callback.claimed_before_signal=sim.p2.stacks==0 and sim.ink_p2_claims.size()==1)
 sim.step(0.5)
 check(callback.seen and callback.claimed_before_signal,"first positive original H04 claims once before external damage callback")
 check(sim.ink_p2_claims.size()==1 and sim.ink_p2_splashes.size()==1,"exactly one existing P2 splash transaction")
 var claim: Dictionary=sim.ink_p2_claims[0]
 check(int(claim.cast_id)==id and claim.family=="q2" and claim.original_packet_source=="hex_yanguizhou_h04","use family canonicalized without changing original packet source")
 check(claim.use_serial>claim.ready_use and sim.p2.stacks==0,"original later-use cutoff survives H04 adaptation")
 check(sim.p2.use_serial==5 and sim.ink_p2_uses.size()==5,"periodic H04 adds no new use")
 check(not packets(sim,"yanguizhou_p2").is_empty() and enemy.hp<100000.0,"actual splash travels through existing ordinary pipeline")
 sim.step(0.5); check(sim.ink_p2_claims.size()==1,"later sunset ticks cannot reconsume")
 observations.p2_sunset=claim.duplicate(true); sim.free()
 # Explicit source-value fault fixture: a real first H04 packet with nominal
 # zero is not eligible consumption; restore the original snapshot for tick2.
 sim=fresh("p2"); fill(sim); next=river(sim); id=int(next.cast_id)
 target(sim,Vector3(1,0,0)); var nominal: float=float(next.sunset_damage); next.sunset_damage=0.0
 sim.step(0.5)
 check(sunset(sim,id).size()==1 and sunset(sim,id)[0].actual_damage==0.0,"labelled zero-damage source fixture commits an actual zero packet")
 check(sim.ink_p2_claims.is_empty() and sim.p2.stacks==3,"zero packet does not spend the ready epoch")
 next.sunset_damage=nominal; sim.step(0.5)
 check(sim.ink_p2_claims.size()==1 and sunset(sim,id)[1].actual_damage>0.0,"next positive original H04 consumes once")
 sim.free(); done_group(REQUIRED_GROUPS[2])

func original_packet_scope_and_retirement() -> void:
 var sim=fresh(); var enemy: Dictionary=target(sim,Vector3(1,0,0)); var state: Dictionary=river(sim); var id: int=int(state.cast_id)
 var fabricated: Dictionary={"active_skill":true,"hex_generated":true,"area":true,"q2_receipt":{"cast_id":id,"river_id":state.river_id,"kind":"sunset","tick":1,"generation":sim.encounter_generation,"room_id":sim.room_id,"target_id":enemy.actor_id,"source_time":0.5}}
 check(not sim._p1_packet_allowed("hex_yanguizhou_h04",id,fabricated),"matching labels outside real original call frame cannot become P1 damage")
 check(not sim._p2_packet_allowed("hex_yanguizhou_h04",id,fabricated),"matching labels outside original frame cannot consume P2")
 check(not sim._p2_packet_allowed("yanguizhou_p1",id,{"p1_supplement":true}),"P1 final correction is never P2 consumption input")
 sim.step(0.5); check(sunset(sim,id).size()==1 and sim.p1.roots[id].targets.size()==1,"real packet still enters sole P1 collector")
 sim.cancel_cast(id); sim.step(4.0)
 check(receipt(sim,id).is_empty() and not sim.p1.roots.has(id) and sunset(sim,id).size()==1,"cancelled Q2 root cannot later complete or emit H04")
 sim.free()
 sim=fresh("p2"); fill(sim); state=river(sim); id=int(state.cast_id); target(sim,Vector3(1,0,0))
 var paused_once: Dictionary={"done":false}
 sim.combat_event.connect(func(event: Dictionary):
  if event.kind=="damage" and event.get("source","")=="hex_yanguizhou_h04" and int(event.cast_id)==id and not paused_once.done:
   paused_once.done=true; sim.paused=true)
 sim.step(0.5)
 check(sim.paused and sim.ink_p2_claims.size()==1 and sim.p2.stacks==0,"original callback pause preserves already-atomic P2 claim")
 check(sim._p2_pending.size()==1 and packets(sim,"yanguizhou_p2").is_empty(),"splash waits in existing queue while paused")
 sim.paused=false; sim.step(0.02)
 check(sim.ink_p2_claims.size()==1 and sim.ink_p2_splashes.size()==1,"resume drains same claimed splash once")
 check(sim._river_hex_packet_frames.is_empty() and sim._p2_frames.is_empty(),"nested source barriers unwind")
 check(sim.clock.advances==sim.ink_core_steps and sim.presentation_errors.is_empty(),"one inherited presentation/core authority")
 sim.begin_encounter("river-ownership-next-room",[])
 check(sim.p1.roots.is_empty() and sim.p2.uses.is_empty() and sim._p2_pending.is_empty() and sim._river_hex_packet_frames.is_empty(),"room generation retires collector and old use entitlements")
 check(not sim.river_hex_fixture_status().ordinary_admission,"ownership mechanism still does not open ordinary pool")
 sim.free(); done_group(REQUIRED_GROUPS[3])

func run() -> void:
 p1_complete_river_and_sunset(); p1_terminal_pause_and_victory(); p2_new_use_sunset_entitlement(); original_packet_scope_and_retirement()
 var report: Dictionary={"schema":"ink-river-ownership-finite-1","passed":failures.is_empty() and completed==REQUIRED_GROUPS,"checks":checks,"completed":completed,"failures":failures,"observations":observations,"source_binding_sha256":FileAccess.get_sha256("res://tests/ink_river_hexes_20261006/ownership01/source_binding.json"),"ordinary_admission":false,"native_input":"NOT_RUN","art_audio_accepted":false,"real_multiplayer":false}
 if not output_path.is_empty():
  var file:=FileAccess.open(output_path,FileAccess.WRITE)
  if file==null: push_error("cannot_write_river_ownership_result"); quit(2); return
  file.store_string(JSON.stringify(report,"  ")); file.close()
 print("INK_RIVER_OWNERSHIP_RESULT ",JSON.stringify(report))
 quit(0 if report.passed else 1)
