extends "res://integration_checks/equipment42_source_gate.gd"
## Original authored rooms and shop lifecycle. No roster additions.
var route_completed: bool=false
var route_evidence: Dictionary={}

func _initialize() -> void:
 output_path="user://equipment42_g03_route_gate.json"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--equipment-result="):output_path=arg.trim_prefix("--equipment-result=")
 run.call_deferred()

func route_case() -> void:
 current_group="original_route_denominators"
 var f: Dictionary=funded_shop(current_group)
 if f.is_empty():return
 if not buy(f,G03_ITEM) or not buy(f,G03_ITEM) or not buy(f,"final:G06") or not check(f.session.close_panel().get("accepted",false),"original route shop closes"):dispose(f);return
 var samples: Array=[]
 var rank_counts: Dictionary={"ordinary":0,"elite":0,"boss":0}
 var death_count: int=0
 var frozen: float=0.0
 var independent_ratio: float=0.0
 var independent_g06: float=0.0
 for row: int in range(1,13):
  if not enter(f,row):dispose(f);return
  if f.session.status=="service":
   var before_service: Dictionary=g03_protected(f)
   if not check(f.session.complete_service().get("accepted",false),"original service completes without resetting G03"):dispose(f);return
   check(g03_protected(f)==before_service,"original rest/service retains ratio and completed task state")
   if row==3:
    if not g02_open(f) or not buy(f,G03_ITEM):dispose(f);return
    g03_near(float(g03_state(f).progress),frozen,"repurchase resumes exact previously frozen ratio")
    if not check(f.session.close_panel().get("accepted",false),"original repurchase shop closes"):dispose(f);return
   continue
  if not spawn_ready(f):dispose(f);return
  g03_heal_full(f,"row%d controlled original low-health setup"%row)
  if not g03_damage_to(f,float(f.sim.hero.stats.max_hp)*0.25,"row%d low holder"%row):dispose(f);return
  var first: int=f.g03_damage.size()
  if row in [1,4]:
   var sample: Dictionary=g03_packet(f,g02_nearest(f),17.0,"row%d_denominator"%row)
   if sample.is_empty():dispose(f);return
   samples.append(sample)
  for enemy: Dictionary in f.sim.enemies.duplicate():
   rank_counts[str(enemy.rank_category)]+=1;death_count+=1
   lethal_enemy_fixture(f,enemy,"G03 original row%d roster"%row)
  for record: Dictionary in f.g03_damage.slice(first):
   if record.synthetic or record.witness.is_empty():continue
   if record.held and float(record.owner_hp_first_observer)/float(record.owner_max_hp_first_observer)<0.35:
    independent_ratio+=float(record.event.amount)/float(record.owner_max_hp_first_observer)
   if record.rank in ["elite","boss"]:independent_g06+=float(record.event.amount)
  g03_near(float(g03_state(f).progress),independent_ratio,"running sum retains every packet's own maxHP denominator")
  g06_near(float(g06_task(f).progress),minf(100000.0,independent_g06),"same original route preserves G06 elite/Boss-only actual damage")
  if row==2:g03_near(float(g03_state(f).progress),frozen,"entire genuinely unequipped room accumulates no G03")
  if not settle_original_row(f,row):dispose(f);return
  if row==1:
   if not g02_open(f):dispose(f);return
   var before: Dictionary=g03_protected(f)
   sell(f,G03_ITEM)
   check(owned_count(f,G03_ITEM)==1 and g03_protected(f)==before,"sell one keeps same player/equipment-name task")
   undo(f)
   check(owned_count(f,G03_ITEM)==2 and g03_protected(f)==before,"undo changes inventory without rolling back ratio")
   sell(f,G03_ITEM);sell(f,G03_ITEM)
   check(owned_count(f,G03_ITEM)==0 and g03_protected(f)==before,"last sale freezes exact ratio")
   if not buy(f,"base:B06"):dispose(f);return
   frozen=float(g03_state(f).progress)
   if not check(f.session.close_panel().get("accepted",false),"original sold-empty shop closes"):dispose(f);return
 if not check(samples.size()==2,"two real original rooms supply equal-damage denominator samples"):dispose(f);return
 check(samples[0].owner_max_hp_first_observer!=samples[1].owner_max_hp_first_observer,"original legal commerce creates two genuinely different maxHP values")
 g03_near(float(samples[0].event.amount),17.0,"first room sample actual damage17")
 g03_near(float(samples[1].event.amount),17.0,"later room sample actual damage17")
 g03_near(float(samples[0].expected_increment)+float(samples[1].expected_increment),17.0/float(samples[0].owner_max_hp_first_observer)+17.0/float(samples[1].owner_max_hp_first_observer),"two equal hits are normalized individually before summing")
 check(death_count==40 and rank_counts=={"ordinary":38,"elite":1,"boss":1},"full unmodified route supplies original ordinary/elite/Boss actors")
 check(f.session.status=="completed" and not g03_state(f).completed and f.session.ledger.model.state.bonus_sp==0,"actual first-floor source route stays below500 without taskSP")
 route_evidence={"samples":samples,"ranks":rank_counts,"deaths":death_count,"independent_ratio":independent_ratio,"independent_G06_damage":independent_g06,"final":g03_protected(f),"G06":g06_task(f),"Session_status":f.session.status,"original_route":B01_ROUTE,"extra_actors":false,"natural_first_floor_500":false}
 b04_integrity(f,current_group);dispose(f);route_completed=true

func run() -> void:
 g03_reset_evidence();route_case()
 g03_required=["original_route_denominators"]
 if route_completed:g03_completed=g03_required.duplicate()
 evidence["g03_route"]=route_evidence
 g03_report("equipment42_G03_original_roster_denominators_and_commerce")
