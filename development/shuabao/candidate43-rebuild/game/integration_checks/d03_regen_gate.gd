extends "res://integration_checks/d03_source_gate.gd"
var d03_regen_case: String = "alone"
func _initialize() -> void:
 output_path="user://d03_regen_gate.json"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--equipment-result="):output_path=arg.trim_prefix("--equipment-result=")
  if arg.begins_with("--d03-regen-case="):d03_regen_case=arg.trim_prefix("--d03-regen-case=")
 if d03_regen_case not in ["alone","mixed"]:quit(2);return
 run.call_deferred()
func e03_projection(f: Dictionary, label: String) -> void:
 var base: float = e03_base_regen(f)
 var elapsed: float = maxf(0.0,e03_now(f)-float(f.e03_combat_start)) if float(f.e03_combat_start)>=0.0 else 0.0
 var active: bool = (owned_count(f,E03_ITEM)>0 or owned_count(f,D03)>0) and f.sim.phase=="combat" and not f.sim.hero.dead and elapsed>=6.0
 var view: Dictionary = e03_view(f)
 check(bool(view.active)==active,label+": exact current condition without EPS advance")
 e03_near(float(view.factor),2.0 if active else 1.0,label+": instantaneous factor is distinct from interval average")
 e03_near(float(f.sim.hero.projected_base_stats.regen),base,label+": original projected regen is never amplified in place")
 e03_near(float(f.sim.hero.stats.regen),base*(2.0 if active else 1.0),label+": exactly one held passive affects current natural regen")
 check(f.sim.common.runtime.get_instance_id()==f.e03_clock_id and f.sim.common.get_instance_id()==f.e03_common_id,label+": original runtime clock and bridge remain the same objects")

func e03_tick(f: Dictionary, label: String) -> bool:
 if not check(f.sim.phase=="combat" and not f.sim.paused and not f.sim.hero.dead,label+": same living unpaused original encounter"):return false
 var before_clock: float = e03_now(f)
 var before_hp: float = float(f.sim.hero.hp)
 var before_events: int = f.events.size()
 var before_revision: int = int(f.sim.equipment_health_revision)
 var base: float = e03_base_regen(f)
 var max_hp: float = float(f.sim.hero.stats.max_hp)
 var eligible: bool = (owned_count(f,E03_ITEM)>0 or owned_count(f,D03)>0)
 step(f)
 var after_clock: float = e03_now(f)
 var dt: float = after_clock-before_clock
 var boundary: float = float(f.e03_combat_start)+6.0
 var boosted_dt: float = maxf(0.0,after_clock-maxf(before_clock,boundary)) if eligible else 0.0
 var requested_regen: float = base*(dt+boosted_dt)
 var actual_regen: float = minf(maxf(0.0,max_hp-before_hp),requested_regen)
 var incoming: float = 0.0
 var incoming_commits: int = 0
 for event: Dictionary in f.events.slice(before_events):
  if event.get("kind")=="damage" and event.get("target")==f.sim.hero.actor_id:
   incoming+=float(event.amount)
   if float(event.amount)>0.0:incoming_commits+=1
 # This group fires no attacks, skills or potion. Its only positive health
 # source is the one original regeneration call before AI's incoming damage.
 var inferred: float = float(f.sim.hero.hp)-before_hp+incoming
 e03_near(inferred,actual_regen,label+": independent original HP loss-adjusted natural regen")
 check(int(f.sim.equipment_health_revision)-before_revision==incoming_commits+(1 if actual_regen>0.0 else 0),label+": one original effective regen commit, not a second bonus heal")
 e03_projection(f,label)
 if before_clock<boundary and after_clock>=boundary or absf(after_clock-boundary)<0.05:
  e03_records.append({"kind":"threshold_tick","label":label,"before_clock":before_clock,"after_clock":after_clock,"combat_start":f.e03_combat_start,"boundary":boundary,"base_regen":base,"boosted_dt":boosted_dt,"requested":requested_regen,"actual":inferred,"incoming":incoming,"before_hp":before_hp,"after_hp":f.sim.hero.hp,"view":e03_view(f)})
 return check(not f.sim.hero.dead and f.session.fault.is_empty(),label+": fixture remains alive and original Session accepts source")

func e03_start(label: String, copies: int=1) -> Dictionary:
 var f: Dictionary=funded_shop(label)
 if f.is_empty():return {}
 f["e03_clock_id"]=f.sim.common.runtime.get_instance_id()
 f["e03_common_id"]=f.sim.common.get_instance_id()
 f["e03_combat_start"]=-1.0
 if d03_regen_case=="mixed" and not buy(f,E03_ITEM):dispose(f);return {}
 for _copy: int in range(copies):
  if not buy(f,D03):dispose(f);return {}
 if not buy(f,"base:B12") or not check(f.session.close_panel().get("accepted",false),"E03 original shop closes") or not e03_enter(f,1) or not spawn_ready(f):dispose(f);return {}
 var target: Dictionary=b04_keep_original(f)
 if target.is_empty() or not e03_damage_deficit(f,150.0,"natural regen missing HP fixture"):dispose(f);return {}
 f["e03_original_target"]=target
 return f

func run() -> void:
 g03_reset_evidence()
 e03_natural()
 check(e03_completed==[E03_GROUPS[1]],"entire inherited natural6second scenario completed")
 await process_frame
 var report: Dictionary={"passed":failures.is_empty(),"checks":checks,"check_records":check_records,"failures":failures,"case":d03_regen_case,"e03_records":e03_records,"fixtures":e03_source_fixtures,"wallet_fixture":true,"original_source_damage_or_heal_fixture":true,"natural_play":false,"GUI_verified":false,"source_binding_sha256":FileAccess.get_sha256("res://visual_rework_20261009/binding/source_binding.json")}
 var file: FileAccess=FileAccess.open(output_path,FileAccess.WRITE)
 if file==null:quit(2);return
 file.store_string(JSON.stringify(report,"  "));var error: Error=file.get_error();file.close();quit(0 if report.passed and error==OK else 2)
