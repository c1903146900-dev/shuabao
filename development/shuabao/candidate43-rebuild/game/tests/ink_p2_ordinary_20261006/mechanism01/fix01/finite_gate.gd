extends SceneTree
## Explicit mechanism fixtures only. Fixture loadout/CD changes are not ordinary
## progression, and private packet probes below are labelled separately.
const Sim = preload("res://tests/ink_p2_ordinary_20261006/mechanism01/sim.gd")
const Geometry = preload("res://tests/ink_q1_foundation_20261004/revision02/scripts/ink_geometry.gd")
const T = preload("res://tests/ink_q1_foundation_20261004/revision02/scripts/ink_tuning.gd")
const Actor = preload("res://tests/ink_e1_rain_foundation_20261005/rain_actor.gd")
const Rest = preload("res://tests/ink_rest_service_20261006/candidate01/rest_service.gd")
const Catalog = preload("res://tests/ink_e3_ordinary_20261006/ordinary01/catalog.gd")
const REQUIRED_GROUPS: Array = ["six_real_use_milestones", "ready_order_and_old_effects", "same_pool_values_and_lifetime", "committed_damage_splash_and_pause", "scope_retirement_and_reentrancy", "p1_and_current_chain_floor"]
const BINDING_PATH := "res://tests/ink_p2_ordinary_20261006/mechanism01/fix01/source_binding.json"
var checks: int = 0
var failures: Array[String] = []
var groups: Array[String] = []
var group_checks: Dictionary = {}
var active_group: String = ""
var observations: Dictionary = {}
var serial: int = 0
var output_path: String = ""

func _initialize() -> void:
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--p2-mechanism-result="): output_path = arg.trim_prefix("--p2-mechanism-result=")
 run.call_deferred()

func check(ok: bool, label: String) -> bool:
 checks += 1
 group_checks[active_group] = int(group_checks.get(active_group,0))+1
 if not ok: failures.append(active_group+": "+label); push_error(active_group+": "+label)
 return ok

func near(a: float, b: float, label: String) -> void:
 check(is_finite(a) and absf(a-b)<0.0001,label+" actual="+str(a)+" expected="+str(b))

func done_group(name: String) -> void:
 check(name not in groups and int(group_checks.get(name,0))>0,"nonempty group completes exactly once")
 groups.append(name)
 print("INK_P2_MECHANISM_GROUP ",name)

func fresh(rank: int = 1, passive: String = "p2"):
 serial += 1
 var sim = Sim.new(); root.add_child(sim)
 sim.auto_finish = false; sim.ai_enabled = false; sim.arena_half_extent = 30.0; sim.obstacles = []
 sim.hero.position = Vector3.ZERO
 sim.hero.loadout.q = "q1"; sim.hero.ranks.q = 1
 sim.hero.loadout.e = "e3"; sim.hero.ranks.e = 1
 sim.hero.loadout.r = "r1"; sim.hero.ranks.r = 1
 sim.hero.loadout.passive = passive; sim.hero.ranks.passive = rank
 # Explicit mechanism fixture inputs use the existing equipment/base projection
 # API. Writing only derived stats before begin was lost at transient reset.
 sim.set_projected_stats({"AP":100.0,"move_speed":10.0,"crit_chance":0.0,"regen":0.0,"lifesteal":0.2,"cdr":0.0})
 check(sim.begin_encounter("p2-mechanism-explicit-fixture-%d"%serial,[]).accepted,"fixture encounter starts")
 near(sim.hero.projected_base_stats.ap,100.0,"fixture enters with supported AP projection")
 near(sim.hero.stats.ap,100.0,"fixture effective AP starts without P2")
 near(sim.hero.projected_base_stats.move_speed,10.0,"fixture enters with supported speed projection")
 near(sim.hero.lifesteal(),0.2,"fixture enters with supported lifesteal projection")
 return sim

func target(sim, at: Vector3, hp: float = 10000.0) -> Dictionary:
 var enemy: Dictionary = sim.spawn_enemy("minion",at,hp)
 enemy.state = "chase"; enemy.defence = 0.0; enemy.radius = 0.25; enemy.position = at
 return enemy

func q1(sim, start: Vector3 = Vector3.ZERO, finish: Vector3 = Vector3(0.26,0,0)) -> Dictionary:
 sim.hero.loadout.q = "q1"; sim.hero.cooldowns.q = 0.0
 check(sim.request_ink_input("q_down").accepted,"real Q1 arms")
 check(sim.request_ink_input("left_down",start).accepted,"real Q1 down")
 check(sim.request_ink_input("motion",finish).accepted,"real Q1 drawing")
 var result: Dictionary = sim.request_ink_input("left_up",finish)
 check(result.accepted,"real Q1 successful release: "+str(result))
 return result

func q2(sim, x: float = 0.0) -> Dictionary:
 sim.hero.loadout.q = "q2"; sim.hero.cooldowns.q = 0.0
 check(sim.request_q2("first",Vector3(x,0,-3)).accepted,"real Q2 first")
 var result: Dictionary = sim.request_q2("second",Vector3(x,0,3))
 check(result.accepted,"real Q2 second: "+str(result))
 return result

func q3(sim) -> Dictionary:
 sim.hero.loadout.q = "q3"; sim.hero.cooldowns.q = 0.0
 var result: Dictionary = sim.request_action("q",Vector3(6,0,0))
 check(result.accepted,"real Q3 raise: "+str(result)); return result

func e1(sim) -> Dictionary:
 sim.hero.loadout.e = "e1"; sim.hero.cooldowns.e = 0.0
 var result: Dictionary = sim.request_action("ink_e_down")
 check(result.accepted,"real E1 entry: "+str(result)); return result

func e2(sim) -> Dictionary:
 sim.hero.loadout.e = "e2"; sim.hero.cooldowns.e = 0.0
 var result: Dictionary = sim.request_action("e",Vector3(20,0,0))
 check(result.accepted,"real E2 launch: "+str(result)); return result

func e3(sim, a: Vector3 = Vector3(-3,0,0), b: Vector3 = Vector3(3,0,0)) -> Dictionary:
 sim.hero.loadout.e = "e3"; sim.hero.cooldowns.e = 0.0
 check(sim.request_e3("first",a).accepted,"real E3 A")
 var result: Dictionary = sim.request_e3("second",b)
 check(result.accepted,"real E3 B: "+str(result)); return result

func fill(sim, cancel: bool = true) -> Array:
 var ids: Array = []
 for index: int in range(4):
  var result: Dictionary = q1(sim) if index%2 == 0 else q2(sim)
  var id: int = int(result.get("cast_id",0)); ids.append(id)
  if cancel and id>0: sim.cancel_cast(id)
 check(sim.p2.stacks == 3 and sim.p2.ready_epoch > 0,"four real alternating uses fill exactly three")
 return ids

func packets(sim, source: String) -> Array:
 return sim.event_log.filter(func(event): return event.kind == "damage" and str(event.get("source","")) == source)

func probe_packet(sim, enemy: Dictionary, id: int, family: String, amount: float, label: String, extra: Dictionary = {}) -> void:
 # An explicit private packet probe of the REAL HP pipeline, not evidence of a
 # naturally emitted skill contact. Complete-use roots are always real above.
 var meta: Dictionary = {"generation":sim.encounter_generation,"room_id":sim.room_id,"active_skill":true,"basic_attack":false,"direct":true,"area":true,"position":enemy.position,"effect_id":"p2-probe:"+label}
 meta.merge(extra,true)
 sim.damage_enemy(enemy,amount,family,id,false,false,meta)

func six_real_use_milestones() -> void:
 active_group = REQUIRED_GROUPS[0]
 var sim = fresh()
 check(sim.request_ink_input("q_down").accepted,"preview Q1 armed")
 check(sim.p2.use_serial == 0,"Q1 preview is not use")
 check(sim.request_ink_input("left_down",Vector3.ZERO).accepted,"zero line starts")
 var zero: Dictionary = sim.request_ink_input("left_up",Vector3.ZERO)
 check(str(zero.get("reason","")) == "zero_length" and sim.p2.use_serial == 0,"zero line cancels without use")
 sim.cancel_ink_preview("fixture_reset")
 var first: Dictionary = q1(sim)
 check(sim.p2.use_serial == 1 and sim.p2.stacks == 0 and sim.p2.last_family == "q1","first release records history only")
 sim.cancel_cast(int(first.cast_id))
 q2(sim)
 check(sim.p2.use_serial == 2 and sim.p2.stacks == 1,"Q2 only completed B counts")
 var mountain: Dictionary = q3(sim)
 check(sim.p2.use_serial == 3 and sim.p2.stacks == 2,"Q3 raise counts")
 near(sim.ink_mountain.raise_damage,T.parameter("Q3-2",1)+106.0*T.fraction("Q3-3",1),"Q3 snapshots AFTER added AP")
 check(sim.request_action("q",Vector3(6,0,0)).accepted and sim.p2.use_serial == 3,"Q3 collapse not a second use")
 e1(sim)
 check(sim.p2.use_serial == 4 and sim.p2.stacks == 3,"E1 entry forms ready")
 near(sim.ink_rain.base_damage,T.parameter("E1-6",1)+109.0*T.fraction("E1-7",1),"E1 snapshots post-use AP")
 check(sim.request_action("ink_e_up").accepted and sim.p2.use_serial == 4,"E1 reform no second use")
 e2(sim)
 check(sim.p2.use_serial == 5 and sim.p2.stacks == 3,"E2 launch once")
 check(sim.request_action("e").accepted and sim.p2.use_serial == 5,"E2 boarding no second use")
 sim.hero.loadout.e = "e3"; sim.hero.cooldowns.e = 0.0
 check(sim.request_e3("first",Vector3(-3,0,0)).accepted,"E3 A real marker")
 var state: Dictionary = sim.ink_frames
 var saved: float = float(state.near_damage)
 check(sim.p2.use_serial == 5,"E3 A not a use")
 check(not sim.request_e3("second",Vector3(100,0,0)).accepted and sim.p2.use_serial == 5,"illegal E3 B not a use")
 check(sim.request_e3("second",Vector3(3,0,0)).accepted and sim.p2.use_serial == 6,"legal E3 B is sixth family")
 near(state.near_damage,saved,"E3 original A damage preserved at B")
 check(sim.ink_p2_uses.map(func(item): return item.family) == ["q1","q2","q3","e1","e2","e3"],"six exact successful milestones")
 check(sim.ink_p2_claims.is_empty(),"empty new skills never spend ready")
 var uses: int = sim.p2.use_serial
 sim.hero.cooldowns.r = 0.0; sim.request_action("r",Vector3.ZERO)
 sim.hero.lock_time = 0.0; sim.request_action("attack",Vector3(0,0,-5))
 sim.hero.lock_time = 0.0; sim.request_action("shift",Vector3(0,0,-5))
 check(sim.p2.use_serial == uses,"R1/basic/shift do not count")
 sim.free()
 sim = fresh(); sim.hero.loadout.q = "q2"
 check(sim.request_q2("first",Vector3.ZERO).accepted and sim.p2.use_serial == 0,"Q2 first stays history-free")
 check(not sim.request_q2("second",Vector3(100,0,0)).accepted and sim.p2.use_serial == 0,"illegal Q2 B no use")
 sim.step(5.02)
 check(sim.ink_q2_pending.is_empty() and sim.p2.use_serial == 0,"Q2 unfinished timeout no use")
 sim.free(); done_group(REQUIRED_GROUPS[0])

func ready_order_and_old_effects() -> void:
 active_group = REQUIRED_GROUPS[1]
 var sim = fresh(); var roots: Array = fill(sim,false)
 var ready: int = sim.p2.ready_epoch
 var enemy: Dictionary = target(sim,Vector3(0,0,1))
 sim.step(0.02)
 check(not packets(sim,"q2").is_empty() and sim.ink_p2_claims.is_empty() and sim.p2.stacks == 3,"older river and ready-forming river hit but cannot spend")
 var deadline: float = sim.p2.expires_at
 q2(sim,4.0)
 check(sim.p2.ready_epoch == ready and sim.p2.stacks == 3,"new same-family empty use entitled without claim")
 near(sim.p2.expires_at,deadline,"same-family use does not refresh")
 var entitled: int = sim.cast_serial
 var destination: Dictionary = target(sim,Vector3(4,0,0))
 sim.step(0.02)
 check(sim.ink_p2_claims.size() == 1 and int(sim.ink_p2_claims[0].cast_id) == entitled,"first real newly completed river damage claims once")
 check(sim.p2.stacks == 0 and sim.p2.ready_epoch == 0 and sim.p2.last_family == "q2","consumption clears buff but retains history")
 check(sim.ink_p2_splashes.size() == 1 and not packets(sim,"yanguizhou_p2").is_empty(),"one actual splash follows claim")
 check(not sim.p2.packet_entitled(int(roots[1]),"q2"),"old root cannot inherit future epoch")
 sim.free()
 sim = fresh(); sim.hero.loadout.q = "q2"
 var a: Dictionary = sim.request_q2("first",Vector3(-4,0,-3)); check(a.accepted,"late-completion Q2 A starts early")
 var early_root: int = int(a.cast_id)
 var result: Dictionary = q1(sim); sim.cancel_cast(int(result.cast_id))
 result = q3(sim); sim.cancel_cast(int(result.cast_id))
 result = e1(sim); check(sim.request_action("ink_e_up").accepted,"fixture E1 completes empty")
 result = q1(sim); sim.cancel_cast(int(result.cast_id))
 check(sim.p2.stacks == 3 and sim.p2.ready_root > early_root,"ready formed after Q2 root birth")
 enemy = target(sim,Vector3(-4,0,0)); sim.hero.loadout.q = "q2"
 result = sim.request_q2("second",Vector3(-4,0,3))
 check(result.accepted and int(result.cast_id) == early_root,"early Q2 root completes B after ready")
 check(sim.ink_p2_claims.size() == 1 and int(sim.ink_p2_claims[0].cast_id) == early_root,"use order authorizes early-born late-completed root")
 sim.free()
 sim = fresh(); fill(sim)
 var boat: Dictionary = e2(sim); var old_boat: int = int(boat.cast_id)
 check(sim.p2.packet_entitled(old_boat,"e2"),"empty after-ready boat owns first epoch")
 sim.hero_time = sim.p2.expires_at; sim.common.refresh_stats()
 check(sim.p2.stacks == 0 and sim.p2.last_family == "e2","exact deadline expires, keeps family")
 fill(sim)
 enemy = target(sim,Vector3(1,0,0))
 probe_packet(sim,enemy,old_boat,"e2",10.0,"old-epoch")
 check(sim.ink_p2_claims.is_empty() and sim.p2.stacks == 3,"old epoch boat cannot consume later ready")
 sim.free(); done_group(REQUIRED_GROUPS[1])

func same_pool_values_and_lifetime() -> void:
 active_group = REQUIRED_GROUPS[2]
 for rank: int in range(1,5):
  var sim = fresh(rank); var original_base: Dictionary = sim.hero.base_stats.duplicate(true)
  fill(sim)
  near(sim.hero.stats.ap,100.0*(1.0+3.0*T.fraction("P2-4",rank)),"rank AP source "+str(rank))
  near(sim.hero.stats.move_speed,10.0*(1.0+3.0*T.fraction("P2-5",rank)),"rank speed source "+str(rank))
  for repeat: int in range(3): sim.common.refresh_stats()
  near(sim.hero.projected_base_stats.ap,100.0,"no projected AP compounding")
  check(sim.hero.base_stats == original_base and sim.common._last_stats == sim.hero.stats,"base intact and last stats complete")
  var deadline: float = sim.p2.expires_at; var epoch: int = sim.p2.ready_epoch
  sim.hero_time = 1.0; e1(sim)
  check(sim.p2.stacks == 3 and sim.p2.ready_epoch == epoch,"capped alternating entry preserves epoch")
  near(sim.p2.expires_at,6.0,"capped use refreshes shared five seconds")
  sim.hero.ranks.passive = 4; sim.common.refresh_stats()
  near(sim.hero.stats.ap,127.0,"live upgrade reads rank-four factors")
  near(sim.p2.expires_at,6.0,"upgrade does not refresh duration")
  sim.hero.slow_left = 1.0; sim.hero.slow_amount = 0.25
  near(sim.hero.speed(),11.5*0.75*(1.0+T.fraction("E1-3",1)),"original slow/E1 speed layers")
  sim.hero_time = 6.0; sim.common.refresh_stats()
  near(sim.hero.stats.ap,100.0,"exact expiry drops AP increment")
  check(sim.p2.last_family == "e1" and sim.p2.ready_epoch == 0,"expiry history retained")
  sim.free()
 var sim = fresh(); fill(sim)
 # Isolated common projection fixture, not an ordinary Hex admission.
 sim.common.runtime.configure(["common_g19","common_g09"])
 sim.common.runtime.boss_until = 100.0; sim.common.runtime.final_until = 100.0
 var ap_extra: float = sim.common.runtime.parameter("g19",2)/100.0
 var ms_extra: float = sim.common.runtime.parameter("g09",3)/100.0
 for repeat: int in range(4): sim.common.refresh_stats()
 near(sim.hero.stats.ap,100.0*(1.0+ap_extra+0.09),"actual common and P2 AP add to same base")
 near(sim.hero.stats.move_speed,10.0*(1.0+ms_extra+0.06),"actual common and P2 speed add to same base")
 sim.set_projected_stats({"AP":150.0,"move_speed":12.0})
 near(sim.hero.stats.ap,150.0*(1.0+ap_extra+0.09),"equipment projection replacement")
 near(sim.hero.projected_base_stats.ap,150.0,"equipment base contains no P2")
 sim.hero.loadout.passive = "p1"; sim.common.refresh_stats()
 near(sim.hero.stats.ap,150.0*(1.0+ap_extra),"passive switch removes only P2")
 check(sim.p2.owner == null and sim.p2.last_family.is_empty(),"passive switch retires full history")
 sim.free(); done_group(REQUIRED_GROUPS[2])

func committed_damage_splash_and_pause() -> void:
 active_group = REQUIRED_GROUPS[3]
 var sim = fresh(); fill(sim)
 var result: Dictionary = q1(sim,Vector3(0,0,-5),Vector3(1,0,-5)); var id: int = int(result.cast_id)
 var enemy: Dictionary = target(sim,Vector3(8,0,0))
 sim.emit_event("damage",{"target":enemy.actor_id,"position":enemy.position,"amount":20.0,"source":"q1","cast_id":id})
 check(sim.ink_p2_claims.is_empty(),"orphan forged damage notification cannot claim")
 probe_packet(sim,enemy,id,"q1",0.0,"zero")
 check(sim.ink_p2_claims.is_empty() and sim.p2.stacks == 3,"zero actual HP packet cannot claim")
 probe_packet(sim,enemy,id,"q1",20.0,"generated",{"hex_generated":true})
 probe_packet(sim,enemy,id,"q1",20.0,"replay",{"replay":true})
 check(sim.ink_p2_claims.is_empty(),"generated and replay packets excluded")
 var nearby: Dictionary = target(sim,Vector3(9,0,0))
 var probe: Dictionary = {"seen":false,"claim_before_callback":false,"stacks_before_callback":-1,"spawned":{}}
 sim.hero.hp = 100.0
 sim.combat_event.connect(func(event: Dictionary):
  if event.kind == "damage" and event.get("source","") == "q1" and not probe.seen:
   probe.seen = true; probe.claim_before_callback = sim.ink_p2_claims.size() == 1; probe.stacks_before_callback = sim.p2.stacks
   nearby.position = Vector3(20,0,0)
   probe.spawned = target(sim,Vector3(8,0,1))
   sim.paused = true)
 probe_packet(sim,enemy,id,"q1",10.0,"positive-pause")
 check(probe.claim_before_callback and probe.stacks_before_callback == 0,"atomic positive claim clears buff before observers")
 check(sim._p2_pending.size() == 1 and sim.ink_p2_splashes.is_empty(),"callback pause retains one queued splash")
 near(sim.ink_p2_claims[0].ap_before_clear,109.0,"claim snapshots pre-clear AP")
 near(sim.ink_p2_claims[0].nominal_damage,52.25,"rank-one nominal splash source value")
 var time: float = sim.hero_time; var steps: int = sim.ink_core_steps
 sim.step(1.0); near(sim.hero_time,time,"paused queue freezes source clock")
 sim.paused = false; sim.step(0.02)
 var splash: Array = packets(sim,"yanguizhou_p2")
 check(splash.size() == 2 and sim.ink_p2_splashes.size() == 1 and sim._p2_pending.is_empty(),"resume emits saved two-target splash exactly once")
 near(nearby.hp,10000.0-52.25,"saved target identity remains selected after callback movement")
 near(probe.spawned.hp,10000.0,"callback-spawned target absent from snapshot")
 check(sim.ink_core_steps == steps+1,"resume advances inherited world exactly once")
 check(splash.all(func(packet): return packet.get("p2_generated",false) and packet.damage_type == "ordinary"),"splash has independent ordinary generated source")
 check(sim.hero.hp > 100.0,"splash uses normal lifesteal path")
 check(sim.ink_p1_receipts.is_empty() and sim.p2.use_serial == 5,"splash never enters P1 or creates new successful use")
 sim.step(0.02); check(packets(sim,"yanguizhou_p2").size() == 2,"subsequent step cannot resend splash")
 sim.free()
 sim = fresh(); fill(sim); result = e3(sim)
 # Empty completed E3 remains a valid completed-use root for exact HP probes.
 id = int(result.cast_id); enemy = target(sim,Vector3(8,0,0),5.0); nearby = target(sim,Vector3(9,0,0))
 var order: Array = []
 sim.combat_event.connect(func(event: Dictionary):
  if event.kind == "kill" and event.get("target","") == enemy.actor_id: order.append("kill")
  if event.kind == "damage" and event.get("source","") == "yanguizhou_p2": order.append("splash"))
 probe_packet(sim,enemy,id,"e3",20.0,"lethal")
 check(enemy.dead and order == ["kill","splash"],"lethal original kill finishes before nearby splash")
 check(sim.ink_p2_claims.size() == 1 and sim.ink_p2_claims[0].target_ids == [nearby.actor_id],"zero-HP lethal original absent from snapshot")
 sim.free()
 sim = fresh(); fill(sim); result = q2(sim,4.0); id = int(result.cast_id)
 enemy = target(sim,Vector3(8,0,0)); target(sim,Vector3(9,0,0))
 var mid: Dictionary = {"paused":false}
 sim.combat_event.connect(func(event: Dictionary):
  if event.kind == "damage" and event.get("source","") == "yanguizhou_p2" and not mid.paused: mid.paused = true; sim.paused = true)
 probe_packet(sim,enemy,id,"q2",10.0,"pause-inside-splash")
 check(packets(sim,"yanguizhou_p2").size() == 1 and sim._p2_pending.size() == 1,"pause inside splash preserves next cursor")
 sim.paused = false; sim.step(0.02)
 check(packets(sim,"yanguizhou_p2").size() == 2 and sim.ink_p2_splashes.size() == 1,"mid-splash resume continues without duplicate first target")
 sim.free(); done_group(REQUIRED_GROUPS[3])

func scope_retirement_and_reentrancy() -> void:
 active_group = REQUIRED_GROUPS[4]
 for retirement: String in ["rest","room","death","owner","passive"]:
  var sim = fresh(); fill(sim); var result: Dictionary = q2(sim,4.0); var id: int = int(result.cast_id)
  var enemy: Dictionary = target(sim,Vector3(8,0,0)); var fired: Dictionary = {"done":false}
  sim.combat_event.connect(func(event: Dictionary):
   if event.kind != "damage" or event.get("source","") != "q2" or fired.done: return
   fired.done = true
   match retirement:
    "rest": Rest.new(RefCounted.new())._clear_live_state(sim)
    "room": sim.end_encounter("cleared"); sim.begin_encounter("replacement-room",[])
    "death": sim.hero.dead = true; sim.end_encounter("defeat")
    "owner":
     var replacement = Actor.new(); replacement.initialize_stats(T.hero_stats()); replacement.loadout.passive = "p2"; replacement.ranks.passive = 1
     sim.hero = replacement; sim.common.refresh_stats(false)
    "passive": sim.hero.loadout.passive = "p1"; sim.common.refresh_stats()
  )
  probe_packet(sim,enemy,id,"q2",10.0,"retire-"+retirement)
  check(fired.done and sim._p2_pending.is_empty() and packets(sim,"yanguizhou_p2").is_empty(),"callback "+retirement+" retires pending splash")
  check(sim.p2.stacks == 0 and sim.p2.last_family.is_empty() and sim.p2.ready_epoch == 0,"callback "+retirement+" clears full P2 state")
  sim.free()
 var sim = fresh(); fill(sim); var result: Dictionary = q2(sim,4.0); var id: int = int(result.cast_id)
 var enemy: Dictionary = target(sim,Vector3(8,0,0)); var other: Dictionary = target(sim,Vector3(9,0,0))
 var nested: Dictionary = {"done":false,"claims":-1}
 sim.combat_event.connect(func(event: Dictionary):
  if event.kind == "damage" and event.get("source","") == "q2" and not nested.done:
   nested.done = true; nested.claims = sim.ink_p2_claims.size()
   probe_packet(sim,other,id,"q2",10.0,"nested")
   sim.emit_event("ink_q2_contact",{"cast_id":id,"source_time":sim.hero_time}))
 probe_packet(sim,enemy,id,"q2",10.0,"outer")
 check(nested.claims == 1 and sim.ink_p2_claims.size() == 1 and sim.ink_p2_splashes.size() == 1,"reentrant original packet and forged contact cannot double claim")
 check(sim._p2_frames.is_empty() and sim._p2_pending.is_empty(),"nested stacks fully unwind")
 sim.free()
 sim = fresh(); fill(sim); result = q2(sim,4.0); id = int(result.cast_id); enemy = target(sim,Vector3(8,0,0))
 var expiry: float = sim.p2.expires_at
 sim.hero_time = expiry
 probe_packet(sim,enemy,id,"q2",10.0,"old-source-late-submit",{"q2_receipt":{"source_time":expiry-0.001}})
 check(sim.ink_p2_claims.is_empty() and sim.p2.stacks == 0,"earlier physical source cannot claim after current-time expiry")
 near(sim.hero_time,expiry,"P2 never rewinds hero clock")
 sim.free(); done_group(REQUIRED_GROUPS[4])

func p1_and_current_chain_floor() -> void:
 active_group = REQUIRED_GROUPS[5]
 var sim = fresh(1,"p1"); sim.hero.hp = 100.0
 var enemy: Dictionary = target(sim,Vector3(-3,0,0)); e3(sim)
 check(sim.ink_p1_receipts.size() == 1 and sim.ink_p1_receipts[0].qualified,"current E3 original P1 single-target settlement preserved")
 observations.p1_regression = {"projected_lifesteal":sim.hero.projected_base_stats.lifesteal,"effective_lifesteal":sim.hero.lifesteal(),"p1":sim.ink_p1_receipts.duplicate(true),"p1_lifesteal":sim.ink_p1_lifesteal_receipts.duplicate(true)}
 check(sim.ink_p1_lifesteal_receipts.size() == 1 and sim.ink_p1_lifesteal_receipts[0].actual_heal > 0.0,"current P1 correction lifesteal preserved")
 check(sim.p2.use_serial == 0 and sim.ink_p2_claims.is_empty(),"P1 selected never stacks P2")
 check(sim.common.get_script().get_base_script().resource_path.ends_with("exchange_common_bridge.gd"),"P2 bridge preserves ExchangeCommon")
 sim.free()
 sim = fresh(); fill(sim); var result: Dictionary = e1(sim)
 enemy = target(sim,Vector3(0,0,0)); var other: Dictionary = target(sim,Vector3(0,0,0.5))
 sim._e1_mark_contact(sim.ink_rain,enemy,Vector3.ZERO,Vector3.ZERO,0.0,sim.hero_time,"fixture_contact")
 check(sim.request_action("ink_e_up").accepted,"real E1 two-channel reform")
 check(packets(sim,"e1").size() == 3 and sim.ink_p2_claims.size() == 1,"E1 two channels and multi-target consume once")
 check(sim.ink_p2_splashes.size() == 1 and sim.ink_p1_receipts.is_empty(),"E1 generated splash cannot pay P1")
 sim.free()
 sim = fresh(); fill(sim); result = e2(sim); enemy = target(sim,Vector3(0.5,0,0))
 var boat: Dictionary = sim.ink_boat
 var first_touch: float = (float(enemy.position.x)-float(enemy.radius))/float(boat.speed)
 check(first_touch > 0.02 and first_touch < 0.10,"E2 fixture first contact lies after old .02 and before .10 source seconds")
 sim.step(0.10)
 observations.boat_regression = {"expected_first_touch":first_touch,"hero_time":sim.hero_time,"position":boat.position,"speed":boat.speed,"receipts":sim.ink_e2_receipts.duplicate(true),"p2_claims":sim.ink_p2_claims.duplicate(true)}
 check(sim.ink_p2_claims.size() == 1 and sim.ink_p2_claims[0].family == "e2","actual boat contact claims")
 check(sim.request_action("e").accepted and sim.ink_p2_claims.size() == 1,"same-root boarding cannot claim twice")
 sim.free()
 sim = fresh(); fill(sim)
 # Both bodies now lie inside the actual swept front interval. The old .30
 # centers with .02 radii required .28 travel, beyond the .26 endpoint.
 enemy = target(sim,Vector3(0.20,0,-0.1)); other = target(sim,Vector3(0.20,0,0.1))
 enemy.radius = 0.02; other.radius = 0.02
 check(is_finite(Geometry.moving_front_contact(Vector3.ZERO,Vector3(0.26,0,0),Vector3.RIGHT,T.parameter("Q1-5",1),enemy.position,enemy.position,float(enemy.radius))),"Q1 fixture body actually intersects the real complete front sweep")
 var hold: Dictionary = {"done":false}
 sim.combat_event.connect(func(event: Dictionary):
  if event.kind == "damage" and event.get("source","") == "q1" and not hold.done: hold.done = true; sim.paused = true)
 q1(sim); sim.step(0.02)
 observations.q1_before_resume = {"paused":sim.paused,"damage":packets(sim,"q1").duplicate(true),"remainder":sim._q2_motion_resume.duplicate(true),"claims":sim.ink_p2_claims.duplicate(true),"hero_time":sim.hero_time,"steps":sim.ink_core_steps}
 check(sim.paused and packets(sim,"q1").size() == 1 and not sim._q2_motion_resume.is_empty(),"P2 Q1 retains original paused multi-contact remainder")
 var at: float = sim.hero_time; var steps: int = sim.ink_core_steps
 sim.paused = false; sim.step(0.02)
 observations.q1_after_resume = {"paused":sim.paused,"damage":packets(sim,"q1").duplicate(true),"remainder":sim._q2_motion_resume.duplicate(true),"claims":sim.ink_p2_claims.duplicate(true),"hero_time":sim.hero_time,"steps":sim.ink_core_steps}
 check(packets(sim,"q1").size() == 2 and sim.ink_p2_claims.size() == 1,"Q1 remainder resumes second original contact without second claim")
 check(sim.ink_core_steps == steps+1,"Q1 resumes old queue then one shared core step")
 sim.free()
 sim = fresh(); var director: int = sim.enemy_director.get_instance_id(); var clock_id: int = sim.clock.get_instance_id()
 enemy = target(sim,Vector3(1,0,0)); check(sim.request_action("r",Vector3.ZERO).accepted,"R1 actual request still accepted")
 check(sim.r1_enemy_rates(enemy).in_domain and sim.enemy_director.get_instance_id() == director and sim.clock.get_instance_id() == clock_id,"R1/Nav/shared clock remain exact original owners")
 var hp: float = sim.hero.hp; var gold: int = sim.hero.gold
 Rest.new(RefCounted.new())._clear_live_state(sim)
 check(sim.p2.stacks == 0 and sim.p2.last_family.is_empty() and sim.ink_snow.is_empty(),"existing rest transient service clears P2 and R1")
 near(sim.hero.hp,hp,"transient cleanup adds no health grant itself")
 check(sim.hero.gold == gold,"P2 cleanup adds no gold")
 sim.free()
 check("P2" not in Catalog.FIRST_SLICE_ALLOWED_CANDIDATES and Catalog.FIRST_SLICE_HEX_HOOKS.size() == 10,"mechanism does not open ordinary P2 or closed Hex hooks")
 observations.fixture_scope = "Six-family real requests plus explicitly labelled private HP, common projection and contact probes; no ordinary P2 selection or native input"
 done_group(REQUIRED_GROUPS[5])

func run() -> void:
 six_real_use_milestones()
 ready_order_and_old_effects()
 same_pool_values_and_lifetime()
 committed_damage_splash_and_pause()
 scope_retirement_and_reentrancy()
 p1_and_current_chain_floor()
 active_group = "final"
 for group: String in REQUIRED_GROUPS: check(groups.count(group) == 1,"required group reached exactly once: "+group)
 var report: Dictionary = {"schema":"ink-p2-mechanism-finite-fix01","passed":failures.is_empty() and groups == REQUIRED_GROUPS,"checks":checks,"failures":failures,"completed":groups,"group_checks":group_checks,"source_binding_sha256":FileAccess.get_sha256(BINDING_PATH),"observations":observations,"ordinary_admission":false,"native_input":false,"old_full_matrices_rerun":false,"production_entry_changed":false,"new_hex_admission":false}
 if not output_path.is_empty():
  var file := FileAccess.open(output_path,FileAccess.WRITE)
  if file == null: push_error("P2 report write failed"); quit(2); return
  file.store_string(JSON.stringify(report," ")+"\n")
 print("INK_P2_MECHANISM_REPORT ",JSON.stringify(report))
 quit(0 if report.passed else 1)
