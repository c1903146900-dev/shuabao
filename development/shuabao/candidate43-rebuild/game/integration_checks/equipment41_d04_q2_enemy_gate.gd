extends "res://integration_checks/equipment41_source_gate.gd"
## Real Q2 router input plus the unchanged original AI hit queue. No fabricated
## hit queue, damage callback, metadata token, enemy state or actor position.
const D04_Q2_GROUP := "actual_q2_delayed_enemy_incoming"
var d04_q2_proofs: Array = []

func _initialize() -> void:
 output_path="user://equipment41_d04_q2_enemy_gate.json"
 d04_required=[D04_Q2_GROUP]
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--equipment-result="):output_path=arg.trim_prefix("--equipment-result=")
 run.call_deferred()

func prepare_initial_choices(f: Dictionary) -> bool:
 # Only choose Q2 instead of Q1, using the same original paid skill command.
 # All original factory, zero-resource, owner and initial Hex checks remain.
 check(not f.session.open_panel().get("accepted",false),"initial mandatory Hex still blocks original shop")
 check(not f.session.select_node(12,"r12boss").get("accepted",false),"actual Session still refuses Boss shortcut")
 if not choose_required_hexes(f):return false
 var learned: Dictionary=command(f,"learn",{"slot":"Q","candidate":"Q2","expected_rank":0})
 return check(learned.get("accepted",false) and f.session.ledger.model.state.points==0 and f.sim.hero.loadout.q=="q2" and f.sim.hero.ranks.q==1,"actual original1SP buys rank1 Q2 and same owner projects it")

func on_event(event: Dictionary, f: Dictionary) -> void:
 super.on_event(event,f)
 if event.get("kind")!="shield" or event.get("source")!=D04_SHIELD:return
 var metadata: Dictionary=f.d04_original_metadata
 # Read-only gate introspection of the ACTUAL production call stack. Current
 # Q2/fix01 has no delivery-token field; do not import a historical seam.
 var callers: Array=get_stack()
 var actual_delivery: bool=false
 for caller: Dictionary in callers:
  if caller.get("function")=="_q2_deliver_enemy_hit" and str(caller.get("source","")).ends_with("tests/ink_q2_foundation_20261005/fix01/ink_q2_sim.gd"):actual_delivery=true
 var contact_key: String=str(metadata.get("r1_presentation_contact",""))
 var contact: Dictionary=f.sim._presentation_contacts.get(contact_key,{})
 var original_contact: bool=not contact.is_empty() and not f.sim._presentation_contact_stack.is_empty() and is_same(contact,f.sim._presentation_contact_stack.back())
 var valid: bool=actual_delivery and original_contact and f.sim._q2_tick_active and f.sim._q2_enemy_context.is_empty()
 var proof: Dictionary={"original_delayed_call_frame":actual_delivery,"original_presentation_contact_identity":original_contact,"original_delayed_delivery_verified":valid,"callers":callers,"source_commit":f.d04_original_commit.duplicate(true),"river_count":f.sim.ink_rivers.size(),"source_time":f.sim.hero_time,"original_AI_enabled":f.sim.ai_enabled,"fixture_metadata":bool(metadata.get("fixture",false)),"mandatory":bool(metadata.get("mandatory",false))}
 d04_q2_proofs.append(proof)
 check(valid and proof.source_commit.source=="enemy" and not proof.fixture_metadata and not proof.mandatory,"D04 grants on exact original Q2 delayed call frame with original AI contact identity")

func d04_q2_place(f: Dictionary, point: Vector3, label: String) -> Dictionary:
 var down:=InputEventKey.new();down.physical_keycode=KEY_Q;down.pressed=true
 var up:=InputEventKey.new();up.physical_keycode=KEY_Q;up.pressed=false
 var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
 var release:=InputEventMouseButton.new();release.button_index=MOUSE_BUTTON_LEFT;release.pressed=false
 var armed: Dictionary=f.router.handle_event(down,point)
 var key_up: Dictionary=f.router.handle_event(up,point)
 if not check(armed.get("accepted",false),label+": actual Q2 input arms"):return {}
 var placed: Dictionary=f.router.handle_event(click,point)
 var mouse_up: Dictionary=f.router.handle_event(release,point)
 evidence.inputs.append({"label":label,"point":point,"q_down":armed,"q_up":key_up,"left_down":placed,"left_up":mouse_up})
 if not check(placed.get("accepted",false) and key_up.get("consumed",false) and mouse_up.get("consumed",false),label+": actual source endpoint commits and release edges drain"):return {}
 return placed

func d04_actual_q2_enemy() -> void:
 current_group=D04_Q2_GROUP
 var f: Dictionary=d04_start(current_group)
 if f.is_empty():return
 if not spawn_ready(f):dispose(f);return
 var attacker: Dictionary={}
 for _tick: int in range(420):
  if f.sim.phase!="combat" or f.sim.hero.dead or d04_view(f).used_in_room:break
  for enemy: Dictionary in f.sim.living():
   if enemy.state=="warning" and float(enemy.timer)<=0.40 and Vector3(enemy.position).distance_to(f.sim.hero.position)<4.0:
    attacker=enemy;break
  if not attacker.is_empty():break
  step(f)
 if not check(not attacker.is_empty() and str(attacker.actor_id) in f.session.expected_enemies,"unchanged original admitted AI naturally reaches a near attack warning"):dispose(f);return
 if not check(not d04_view(f).used_in_room and f.sim.hero.hp>float(f.sim.hero.stats.max_hp)*0.30,"AI approach has not preconsumed the room threshold"):dispose(f);return
 var threshold: float=float(f.sim.hero.stats.max_hp)*0.30
 if d04_damage_to(f,threshold,"nonlethal true source setup to exact30percent before original AI hit").is_empty():dispose(f);return
 if not check(f.d04_shields.is_empty() and not d04_view(f).used_in_room,"exact setup leaves quota unconsumed for real AI injury"):dispose(f);return
 var away: Vector3=Vector3(f.sim.hero.position-attacker.position).normalized()
 away.y=0.0
 if away.length_squared()<0.5:away=Vector3.BACK
 var side: Vector3=Vector3(-away.z,0.0,away.x)
 var first: Vector3=f.sim.hero.position+away*4.0+side*3.0
 var second: Vector3=first-side*8.0
 if not check(f.sim.q2_preview(first).get("accepted",false),"real opposite-side Q2 first point lies in source range"):dispose(f);return
 if d04_q2_place(f,first,"D04 Q2 A").is_empty() or d04_q2_place(f,second,"D04 Q2 B").is_empty():dispose(f);return
 if not check(f.sim.ink_rivers.size()==1 and f.sim.ink_q2_pending.is_empty() and not attacker.dead,"actual Q2 exists while original attacker remains alive"):dispose(f);return
 var original_attacker: Dictionary={"actor_id":attacker.actor_id,"state":attacker.state,"timer":attacker.timer,"hp":attacker.hp,"position":attacker.position,"original_roster":str(attacker.actor_id) in f.session.expected_enemies}
 for _tick: int in range(220):
  if not f.d04_shields.is_empty() or f.sim.hero.dead or f.sim.phase!="combat":break
  step(f)
 check(f.d04_shields.size()==1 and d04_q2_proofs.size()==1 and d04_view(f).used_in_room,"real queued AI HP loss produces exactly one D04 shield")
 check(not f.sim.hero.dead and f.sim.ai_enabled and f.sim.auto_finish,"original AI and terminal policies remain intact after queued hit")
 evidence["d04_q2_enemy"]={"attacker_before":original_attacker,"original_Q2_points":[first,second],"proofs":d04_q2_proofs,"shield_records":f.d04_shields.duplicate(true),"direct_HP_queue_metadata_or_AI_writes":false,"actual_Q2_router_input":true,"actual_queued_AI_hit":not d04_q2_proofs.is_empty() and d04_q2_proofs[0].original_delayed_delivery_verified}
 b04_integrity(f,current_group);dispose(f);d04_completed.append(current_group)

func run() -> void:
 evidence={"wallet_fixtures":[],"inputs":[],"cooldown_fixtures":[],"completions":[],"aborts":[],"victory":[],"postcompletion":[],"lifecycle":[],"isolated_common":[],"movement":[],"g02_deaths":[],"pre_damage":[],"inputs_g02":[],"p1_g02":{},"route_g02":{},"extra_actor_g02":{}}
 d04_actual_q2_enemy()
 d04_report("equipment41_D04_actual_Q2_and_original_AI_delay")
