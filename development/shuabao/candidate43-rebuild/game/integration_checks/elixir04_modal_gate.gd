extends "res://integration_checks/elixir04_source_gate.gd"
## Original Session modal API, not direct modal/clock mutation.
func _initialize() -> void:
 output_path="user://hunter_modal.json"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--elixir-result="):output_path=arg.trim_prefix("--elixir-result=")
 run.call_deferred()
func modal_case() -> void:
 var f: Dictionary=funded_shop("modal")
 if f.is_empty():return
 var model=f.session.ledger.model
 if not buy(f,HUNTER):dispose(f);return
 var args: Dictionary=model.commerce_token();args.uid=hunter_uid(f)
 var modal: Dictionary=f.session.set_modal_blocked(true)
 if not check(modal.accepted and f.session.initial_modal_open and f.sim.paused,"original modal API suspends input and opens blocking state"):dispose(f);return
 var before: Dictionary=model.state.duplicate(true)
 var result: Dictionary=f.session.submit("hunter-modal-refusal","consume",args)
 check(not result.accepted and result.reason=="mandatory_hex_pending" and model.state==before,"actual open modal refuses drink without currency/uid/effect change")
 var closed: Dictionary=f.session.set_modal_blocked(false)
 check(closed.accepted and not f.session.initial_modal_open,"original modal closes normally")
 var used: Dictionary=f.session.submit("hunter-after-modal","consume",args)
 check(used.accepted and model.hunter_elixir_status().pending,"same legitimate held bottle usable after original modal closes")
 hunter_records.append({"open":modal,"refused":result,"close":closed,"used":used})
 dispose(f);hunter_done.append("modal")
func run() -> void:
 g03_reset_evidence();modal_case();await process_frame
 check(hunter_done==["modal"],"modal gate complete")
 var report: Dictionary={"passed":failures.is_empty(),"checks":checks,"check_records":check_records,"failures":failures,"records":hunter_records,"wallet_fixture":true,"modal":"original Session API; not native GUI","source_binding_sha256":FileAccess.get_sha256("res://visual_rework_20261009/binding/source_binding.json")}
 var file: FileAccess=FileAccess.open(output_path,FileAccess.WRITE)
 if file==null:quit(2);return
 file.store_string(JSON.stringify(report,"  "));var error: Error=file.get_error();file.close();quit(0 if report.passed and error==OK else 2)
