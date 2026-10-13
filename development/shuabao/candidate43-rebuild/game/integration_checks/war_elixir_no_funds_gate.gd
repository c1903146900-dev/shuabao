extends "res://integration_checks/war_elixir_source_gate.gd"
## Original zero-gold startup. No wallet injection in this finite rejection gate.
func _initialize() -> void:
 output_path="user://war_elixir_no_funds.json"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--elixir-result="):output_path=arg.trim_prefix("--elixir-result=")
 run.call_deferred()
func run() -> void:
 g03_reset_evidence();current_group="zero_gold"
 var f: Dictionary=fresh()
 if not f.is_empty() and prepare_initial_choices(f) and check(f.session.open_panel().accepted,"original safe shop opens at zero gold"):
  var model=f.session.ledger.model
  var before: Dictionary=model.state.duplicate(true)
  check(before.gold==0 and before.inventory.is_empty(),"original fresh zero resources retained")
  var quote: Dictionary=model.commerce_quote(WAR)
  check(not quote.accepted and quote.reason=="insufficient_gold","original quote rejects650 item at zero gold")
  var purchase: Dictionary=shop_command(f,"buy",{"item":WAR})
  check(not purchase.accepted and purchase.reason=="insufficient_gold" and model.state==before,"original purchase refusal changes no currency/item/effect")
  check(model.state.shop_visit.active_elixir.is_empty(),"insufficient resources never grant pending elixir")
  war_done.append(current_group)
 dispose(f);await process_frame
 check(war_done==["zero_gold"],"zero-gold group complete")
 var report: Dictionary={"passed":failures.is_empty(),"checks":checks,"check_records":check_records,"failures":failures,"wallet_fixture":false,"natural_full_play":false,"source_binding_sha256":FileAccess.get_sha256("res://visual_rework_20261009/binding/source_binding.json")}
 var file: FileAccess=FileAccess.open(output_path,FileAccess.WRITE)
 if file==null:quit(2);return
 file.store_string(JSON.stringify(report,"  "));var error: Error=file.get_error();file.close();quit(0 if report.passed and error==OK else 2)
