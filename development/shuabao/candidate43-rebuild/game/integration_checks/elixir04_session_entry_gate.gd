extends "res://integration_checks/elixir04_source_gate.gd"
## Actual Session rejections. Economic setup is the declared original60000 fixture.
func _initialize() -> void:
 output_path="user://hunter_session_entry.json"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--elixir-result="):output_path=arg.trim_prefix("--elixir-result=")
 run.call_deferred()
func denied_unchanged(f: Dictionary,args: Dictionary,reason: String,label: String) -> void:
 serial+=1
 var before: Dictionary=f.session.ledger.model.state.duplicate(true)
 var result: Dictionary=f.session.submit("hunter-entry-negative-"+str(serial),"consume",args)
 check(not result.accepted and result.reason==reason and f.session.ledger.model.state==before,label)
func entry_cases() -> void:
 var f: Dictionary=funded_shop("session_entry")
 if f.is_empty():return
 var model=f.session.ledger.model
 if not buy(f,HUNTER) or not buy(f,"base:B01"):dispose(f);return
 var token: Dictionary=model.commerce_token();token.uid=hunter_uid(f)
 for key: String in ["epoch","revision","uid","room_id"]:
  var missing: Dictionary=token.duplicate(true);missing.erase(key)
  denied_unchanged(f,missing,"invalid_elixir_argument_type:"+key,"missing required field rejected "+key)
 for key: String in ["epoch","revision","uid"]:
  for wrong: Variant in [true,1.0,"1",null]:
   var invalid: Dictionary=token.duplicate(true);invalid[key]=wrong
   denied_unchanged(f,invalid,"invalid_elixir_argument_type:"+key,"uncoerced token type rejected "+key+" "+str(typeof(wrong)))
 var invalid_room: Dictionary=token.duplicate(true);invalid_room.room_id=1
 denied_unchanged(f,invalid_room,"invalid_elixir_argument_type:room_id","nonstring room refused")
 var extra: Dictionary=token.duplicate(true);extra.trusted=true
 denied_unchanged(f,extra,"unsupported_elixir_argument","caller cannot add trusted field")
 var other: Dictionary=token.duplicate(true);other.uid=int(held_item(f,"base:B01").uid)
 denied_unchanged(f,other,"hunter_elixir_uid_required","real equipment UID cannot enter consume")
 var absent: Dictionary=token.duplicate(true);absent.uid=-1
 denied_unchanged(f,absent,"hunter_elixir_uid_required","absent UID cannot enter consume")
 var stale: Dictionary=token.duplicate(true);stale.revision-=1
 denied_unchanged(f,stale,"stale_revision","original model rejects stale typed token")
 var before: Dictionary=model.state.duplicate(true)
 check(f.session.close_panel().accepted,"original shop closes")
 var closed_state: Dictionary=model.state.duplicate(true)
 var closed: Dictionary=f.session.submit("hunter-closed","consume",token)
 check(not closed.accepted and closed.reason=="shop_panel_not_open" and model.state==closed_state,"closed panel refuses real held bottle")
 check(f.session.open_panel().accepted,"original shop reopens")
 token=model.commerce_token();token.uid=hunter_uid(f)
 var used: Dictionary=f.session.submit("hunter-entry-success","consume",token)
 check(used.accepted,"strict Session valid bottle commits original authority")
 before=model.state.duplicate(true)
 var replay: Dictionary=f.session.submit("hunter-entry-success","consume",token)
 check(replay.accepted and replay.get("replayed",false) and model.state==before,"consumed UID absence cannot reject exact replay")
 var conflict: Dictionary=token.duplicate(true);conflict.uid+=100
 var conflict_result: Dictionary=f.session.submit("hunter-entry-success","consume",conflict)
 check(not conflict_result.accepted and conflict_result.reason=="command_id_conflict" and model.state==before,"existing ID changed UID conflicts in original receipt")
 # A valid stored bottle in combat remains refused by original Session location.
 if not buy(f,HUNTER) or not check(f.session.close_panel().accepted,"close before battle") or not enter(f,1):dispose(f);return
 var combat_args: Dictionary=model.commerce_token();combat_args.uid=hunter_uid(f)
 before=model.state.duplicate(true)
 var combat: Dictionary=f.session.submit("hunter-combat-real-bottle","consume",combat_args)
 check(not combat.accepted and model.state==before and hunter_uid(f)>0,"combat refuses actual stored hunter UID without consuming")
 hunter_records.append({"combat_reason":combat.reason,"exact_success":used,"replay":replay,"conflict":conflict_result})
 dispose(f);hunter_done.append("session_entry")
func run() -> void:
 g03_reset_evidence();entry_cases();await process_frame
 check(hunter_done==["session_entry"],"session entry finite group complete")
 var report: Dictionary={"passed":failures.is_empty(),"checks":checks,"check_records":check_records,"failures":failures,"records":hunter_records,"wallet_fixture":true,"natural_play":false,"source_binding_sha256":FileAccess.get_sha256("res://visual_rework_20261009/binding/source_binding.json")}
 var file: FileAccess=FileAccess.open(output_path,FileAccess.WRITE)
 if file==null:quit(2);return
 file.store_string(JSON.stringify(report,"  "));var error: Error=file.get_error();file.close();quit(0 if report.passed and error==OK else 2)
