extends "res://integration_checks/elixir04_source_gate.gd"
## Real Q1 input and P1 original atomic supplement on the entered row5 elite.
## Preparation uses actual earned SP and original route, with disclosed lethal
## source damage to finish earlier rosters. Not natural play or native GUI.
func _initialize() -> void:
 output_path="user://elixir04_p1.json"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--elixir-result="):output_path=arg.trim_prefix("--elixir-result=")
 run.call_deferred()
func hunter_actual_p1() -> void:
 current_group="actual_p1"
 var f: Dictionary=funded_shop(current_group)
 if f.is_empty():return
 var model=f.session.ledger.model
 if not check(f.session.close_panel().accepted,"original initial shop closes") or not g06_enter_original(f,1,"r01a") or not settle_fixture_combat(f):dispose(f);return
 var earned: Dictionary=model.snapshot()
 if not check(earned.level==2 and earned.points==1,"original first-row rewards earned Lv2/1SP"):dispose(f);return
 if not check(command(f,"learn",{"slot":"P","candidate":"P1","expected_rank":0}).accepted,"original earned point learns P1"):dispose(f);return
 for row in range(2,5):
  if not g06_enter_original(f,row,"r%02da"%row):dispose(f);return
  if f.session.status=="service":
   if not check(f.session.complete_service().accepted,"complete original service"):dispose(f);return
  elif not settle_fixture_combat(f):dispose(f);return
 if not choose_required_hexes(f) or not check(f.session.open_panel().accepted,"original before-elite safe shop") or not buy(f,HUNTER) or not check(shop_command(f,"consume",{"uid":hunter_uid(f)}).accepted,"drink only for upcoming elite battle") or not check(f.session.close_panel().accepted,"original shop closes") or not g06_enter_original(f,5,"r05a") or not spawn_ready(f):dispose(f);return
 var enemy: Dictionary={}
 for actor: Dictionary in f.sim.enemies:
  if actor.kind=="elite":enemy=actor;break
 if not check(not enemy.is_empty() and model.hunter_elixir_status().active,"original entered elite and next-battle elixir active"):dispose(f);return
 for tick in range(400):
  if f.sim.hero.position.distance_to(enemy.position)<=8.5 or f.sim.phase!="combat" or f.sim.hero.dead:break
  step(f)
 if not check(not enemy.dead and not f.sim.hero.dead and f.sim.hero.position.distance_to(enemy.position)<9.0,"original AI reaches genuine Q1 range without teleport"):dispose(f);return
 var start: Vector3=enemy.position
 var endpoint: Vector3=start+Vector3(0.26,0,0)
 for actor: Dictionary in f.sim.living():
  if actor.actor_id!=enemy.actor_id:check(actor.position.distance_to(start)>3.0+float(actor.radius),"short real Q1 excludes sibling "+str(actor.actor_id))
 var hp: float=enemy.hp
 var nominal: float=G06Design.parameter("yanguizhou","Q1-1",1)+float(f.sim.hero.stats.ap)*G06Design.fraction("yanguizhou","Q1-2",1)
 var expected: float=nominal*1.10*100.0/(100.0+maxf(0.0,float(enemy.defence)-float(f.sim.hero.stats.penetration)))
 if not check(f.sim.request_ink_input("q_down").accepted,"genuine Q1 arm") or not check(f.sim.request_ink_input("left_down",start).accepted,"genuine Q1 anchor") or not check(f.sim.request_ink_input("motion",endpoint).accepted,"genuine Q1 path"):dispose(f);return
 var release: Dictionary=f.sim.request_ink_input("left_up",endpoint)
 if not check(release.accepted,"genuine Q1 release"):dispose(f);return
 var releases: Array=events_of(f,"ink_q1_released")
 if not check(releases.size()==1,"one actual Q1 root"):dispose(f);return
 var cast_id: int=int(releases[0].cast_id)
 for tick in range(100):
  if not g06_p1_receipts(f,cast_id).is_empty() or f.sim.phase!="combat":break
  step(f)
 var receipts: Array=g06_p1_receipts(f,cast_id)
 var ordinary: Array=g06_p1_events(f,cast_id,"q1")
 var supplements: Array=g06_p1_events(f,cast_id,"yanguizhou_p1")
 if not check(receipts.size()==1 and ordinary.size()==1 and supplements.size()==1,"actual Q1 plus one original atomic P1 supplement"):dispose(f);return
 var receipt: Dictionary=receipts[0]
 check(receipt.qualified and receipt.distinct_targets==1 and receipt.ordinary_packet_count==1 and not receipt.supplement_killed,"original single-target qualification remains")
 near_number(float(ordinary[0].event.amount),expected,"real Q1 applies hunter10% and current20penetration exactlyonce")
 near_number(float(receipt.final_basis),expected,"P1 basis already contains original final factor")
 near_number(float(receipt.actual_supplement),expected*0.12,"P1 twelvepercent supplement does not multiply hunter again")
 near_number(hp-float(enemy.hp),expected*1.12,"real HP loss equals Q1 plus original P1")
 step(f,10)
 check(g06_p1_receipts(f,cast_id).size()==1,"later ticks cannot regrant P1 supplement")
 hunter_records.append({"earned":earned,"release":release,"ordinary":ordinary,"supplement":supplements,"receipt":receipt,"expected_ordinary":expected,"actual_skill_input":true,"native_input":false,"extra_spawn":false})
 dispose(f);hunter_done.append(current_group)
func run() -> void:
 g03_reset_evidence();hunter_actual_p1();await process_frame
 check(hunter_done==["actual_p1"],"actual P1 elixir group complete")
 var report: Dictionary={"passed":failures.is_empty(),"checks":checks,"check_records":check_records,"failures":failures,"records":hunter_records,"original_roster_source_damage_preparation_fixture":true,"actual_Q1_P1_source_input":true,"natural_play":false,"source_binding_sha256":FileAccess.get_sha256("res://visual_rework_20261009/binding/source_binding.json")}
 var file: FileAccess=FileAccess.open(output_path,FileAccess.WRITE)
 if file==null:quit(2);return
 file.store_string(JSON.stringify(report,"  "));var error: Error=file.get_error();file.close();quit(0 if report.passed and error==OK else 2)
