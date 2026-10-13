extends "res://integration_checks/d03_source_gate.gd"
## Isolated negative authority fixture. The test temporarily removes only the
## Model's weak health binding, makes read-only queries, then restores it.
var binding_records: Array=[]
func _initialize() -> void:
 output_path="user://d03_binding_refusal.json"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--equipment-result="):output_path=arg.trim_prefix("--equipment-result=")
 run.call_deferred()
func run() -> void:
 g03_reset_evidence()
 var f: Dictionary=funded_shop("D03 explicit binding-negative fixture")
 if f.is_empty():finish_binding();return
 var m=f.session.ledger.model
 if not buy(f,D03):dispose(f);finish_binding();return
 for include_b03: bool in [false,true]:
  if include_b03 and not buy(f,"final:B03"):dispose(f);finish_binding();return
  var state_before: Dictionary=m.state.duplicate(true)
  var hp_before: float=f.sim.hero.hp
  var weak_before: WeakRef=m._health_sim
  m._health_sim=null
  var status: Dictionary=m.equipment_runtime_status(D03)
  var effects: Dictionary=m.equipment_effects()
  var distance: float=m.distance_equipment_multiplier(Vector3.ZERO,{"position":Vector3(3,0,0)})
  var regen: Dictionary=m.e03_regen_effect(f.sim,false)
  check(not status.supported and status.reason=="d03_original_consumers_unbound","D03 no admission without actual bound owner")
  near_number(float(effects.stats.get("lifesteal",0.0)),0.05 if include_b03 else 0.0,"D03 adds no base or passive lifesteal while unbound; original B03 constant remains")
  near_number(distance,1.12 if include_b03 else 1.0,"D03 distance disabled while original B03 behavior retained")
  check(not regen.active and float(regen.factor)==1.0,"unbound original regen inspect grants no factor")
  binding_records.append({"include_B03":include_b03,"status":status,"effects":effects,"distance":distance,"regen":regen,"fixture":"temporarily_null_Model_health_weakref"})
  m._health_sim=weak_before
  check(m._health_sim==weak_before and m.equipment_runtime_status(D03).runtime_complete,"same original binding restored")
  check(m.state==state_before and f.sim.hero.hp==hp_before,"queries and binding fixture never alter gameplay state or HP")
  near_number(float(m.equipment_effects().stats.lifesteal),0.11,"bound D03 plus optional B03 retains one named5 percent")
 dispose(f);finish_binding()
func finish_binding() -> void:
 var report: Dictionary={"passed":failures.is_empty(),"checks":checks,"check_records":check_records,"failures":failures,"records":binding_records,"binding_negative_fixture":true,"wallet_fixture":true,"natural_play":false,"source_binding_sha256":FileAccess.get_sha256("res://visual_rework_20261009/binding/source_binding.json")}
 var file: FileAccess=FileAccess.open(output_path,FileAccess.WRITE)
 if file==null:quit(2);return
 file.store_string(JSON.stringify(report,"  "));var error: Error=file.get_error();file.close();quit(0 if report.passed and error==OK else 2)
