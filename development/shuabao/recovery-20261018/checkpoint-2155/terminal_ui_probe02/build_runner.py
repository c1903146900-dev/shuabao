from pathlib import Path
import hashlib

root = Path(__file__).resolve().parent.parent
upstream = root / 'terminal_ui_upstream/full_floor07/runner.gd'
target = Path(__file__).resolve().parent / 'payload/yan_terminal_full_floor_20261018c/runner.gd'
assert hashlib.sha256(upstream.read_bytes()).hexdigest() == 'efa0a30b681051fdad434a953f68d8ec18edc89b185573402fdfa5f0bcd1f881'
s = upstream.read_text()

def once(old, new):
    global s
    assert s.count(old) == 1, (old[:90], s.count(old))
    s = s.replace(old, new, 1)

s = s.replace('res://yan_full_floor_20261018b/', 'res://yan_terminal_full_floor_20261018c/')
once('# REIMPLEMENTATION. Synthetic visible-button input; no gameplay state writes.', '# New probe02 built from the exact, independently exercised full_floor07 fixture.\n# This is not an exact recovery of the lost terminal runner. No gameplay state writes.')
once('const BINDING_SHA = "41c68dc417e3bef39fe024623e46267e7c5bdfd9188bb9f52fb1e5cea2282d68"', 'const BINDING_SHA = "9dfec798588e18474538570a0e53ed044ba52c0090972461b740602f0a7af053"')
once('var driver\n', 'const TerminalProbe = preload("res://yan_terminal_ui_probe_20261018/probe.gd")\nvar requested_outcome: String = "victory"\nvar driver\n')
once('"dedicated_settlement_panel":"NOT_IMPLEMENTED"', '"dedicated_settlement_panel":"NOT_REACHED","last_hex_summary_yield":"NOT_REACHED","summary_close_reopen":"NOT_REACHED","summary_shop_yield":"NOT_REACHED","summary_chooser_yield":"NOT_REACHED","natural_defeat_summary":"NOT_REQUESTED"')
once('  if argument.begins_with("--full-floor-evidence="): evidence = argument.trim_prefix("--full-floor-evidence=")', '  if argument.begins_with("--full-floor-evidence="): evidence = argument.trim_prefix("--full-floor-evidence=")\n  if argument.begins_with("--terminal-outcome="): requested_outcome = argument.trim_prefix("--terminal-outcome=")')
once(' var before: Dictionary = model.snapshot()\n var milestone: int', ''' if session.status == "completed":
  await _frame()
  if not _identity() or not _budget(): return false
  var yielded: Dictionary = TerminalProbe.check_pending_hex_yields(host,entry)
  observations.append({"terminal_pending_hex_yield":yielded})
  if not yielded.get("accepted",false): reason="summary_covers_mandatory_final_hex"; return false
  coverage.last_hex_summary_yield="PASS"
 var before: Dictionary = model.snapshot()
 var milestone: int''')
once(' if FileAccess.get_sha256(BINDING)!=BINDING_SHA:', ' if requested_outcome not in ["victory","defeat"]: await _stop("terminal_outcome_must_be_victory_or_defeat"); return\n if FileAccess.get_sha256(BINDING)!=BINDING_SHA:')
once(' root.add_child(entry)\n await _frame()', ' root.add_child(entry)\n if entry.get_script().resource_path != "res://yan_visual_attach_20261018/entry.gd": await _stop("actual_thin_entry_required"); return\n await _frame()')
once(' if not await _full_route(): await _stop(reason if not reason.is_empty() else "full_route_failed"); return\n completed=true', ''' var reached: bool = false
 if requested_outcome == "defeat":
  reached = await _natural_defeat()
 else:
  reached = await _full_route()
 if watchdog_fired or finishing: return
 if not reached: await _stop(reason if not reason.is_empty() else "requested_terminal_route_failed"); return
 if not _budget(): await _stop("deadline_before_terminal_coverage"); return
 completed=true''')
once('"scope":"original_Q1_build_full_first_floor_and_cancelled_hero_confirmation","coverage"', '"scope":"original_Q1_full_floor_terminal_summary" if requested_outcome=="victory" else "original_no_combat_input_natural_defeat_terminal_summary","requested_outcome":requested_outcome,"additional_run_created":false,"art_acceptance":"NOT_REVIEWED","coverage"')
once(' return ui.pending.is_empty() and not ui.hex_visible and ui.header_visible and "12/12" in ui.header_text and "completed" in ui.header_text and ui.next_disabled and ui.session_status=="completed" and ui.rows==12', ' return ui.pending.is_empty() and not ui.hex_visible and ui.header_visible and "首层已完成" in ui.header_text and ui.next_disabled and ui.session_status=="completed" and ui.rows==12 and _summary_check(label,"victory")')
once(' if not _available(entry.chooser.hero_buttons.xuanlei): return false', ''' await _frame()
 if not _identity() or not _budget(): return false
 var yielded: Dictionary=TerminalProbe.check_yields_to_original(host,entry,"chooser")
 observations.append({"summary_chooser_yield":yielded})
 if not yielded.get("accepted",false): reason="summary_visible_over_original_chooser"; return false
 coverage.summary_chooser_yield="PASS"
 if not _available(entry.chooser.hero_buttons.xuanlei): return false''')
once(' coverage.completed_floor_ui="PASS"\n if not await _hero_cancel(): return false', ''' coverage.completed_floor_ui="PASS"
 coverage.dedicated_settlement_panel="PASS"
 if coverage.last_hex_summary_yield!="PASS": reason="final_mandatory_hex_yield_not_observed"; return false
 if not await _summary_roundtrip("victory",true): return false
 if not await _hero_cancel(): return false''')
s += '''

# The following checks only observe the new display. The only new display input
# is its own close/reopen signals, guarded against any source-state change.
func _summary_check(label: String, outcome: String) -> bool:
 if not _identity() or not _budget(): return false
 var actual: Dictionary=TerminalProbe.check_terminal(host,entry,outcome)
 observations.append({"terminal_summary":label,"result":actual})
 if not actual.get("accepted",false):
  reason="terminal_summary_assertion:"+JSON.stringify(actual.get("failures",[]))
  return false
 return true

func _summary_roundtrip(outcome: String, check_shop: bool) -> bool:
 if not _summary_check("before_display_roundtrip",outcome): return false
 var result: Dictionary=await TerminalProbe.exercise_close_reopen(host,entry)
 if not _identity() or not _budget(): return false
 observations.append({"summary_close_reopen":result})
 if not result.get("accepted",false): reason="summary_close_reopen_changed_source_or_failed"; return false
 coverage.summary_close_reopen="PASS"
 if not _summary_check("after_display_roundtrip",outcome): return false
 if not check_shop: return true
 var account: Dictionary=_account()
 var settlement: Dictionary=session.settlement.duplicate(true)
 # Use the already supported P shortcut, rather than clicking through the card.
 var event:=InputEventKey.new()
 event.keycode=KEY_P; event.physical_keycode=KEY_P; event.pressed=true
 host._input(event)
 var release:=InputEventKey.new()
 release.keycode=KEY_P; release.physical_keycode=KEY_P; release.pressed=false
 host._input(release)
 await _frame()
 if not _identity() or not _budget(): return false
 var yielded: Dictionary=TerminalProbe.check_yields_to_original(host,entry,"shop")
 observations.append({"summary_shop_yield":yielded})
 if not yielded.get("accepted",false): reason="summary_did_not_yield_to_original_shop"; return false
 if not driver._close_original_shop(): reason="original_shop_close_failed"; return false
 await _frame()
 if not _identity() or not _budget() or _account()!=account or session.settlement!=settlement: return false
 if not _summary_check("after_original_shop_close",outcome): return false
 coverage.summary_shop_yield="PASS"
 return true

# An independent requested run may observe defeat. It supplies no attacks or
# movement after normal entry, and never sets HP, enemy data, time or progress.
func _natural_defeat() -> bool:
 phase="original_no_combat_input_defeat"
 coverage.natural_defeat_summary="NOT_REACHED"
 driver=Driver.new();driver.bind_existing(host,deadline-10000);driver.resolve_hex=Callable(self,"_resolve_hexes")
 if host.initial_hud.growth_panel.is_visible_in_tree():
  if not _available(host.growth_toggle): return false
  host.growth_toggle.pressed.emit()
  await _frame()
  if not _identity() or not _budget() or host.initial_hud.growth_panel.is_visible_in_tree(): return false
 var entered: Dictionary=await _next_node(1,ROUTE[0])
 if not _budget() or not entered.get("accepted",false) or not _adopt_entry(ROUTE[0],true): return false
 observations.append({"natural_defeat_entry":entered,"combat_input_policy":"NO_COMBAT_INPUT_AFTER_ORIGINAL_ENTRY"})
 driver.release_between_nodes()
 while _budget() and _identity() and not (session.status=="defeated" and sim.phase=="true_dead" and hero.dead):
  if not session.fault.is_empty(): reason="natural_defeat_source_fault"; return false
  await _frame()
  if not _identity() or not _budget(): return false
  _record_health()
 if not _identity() or not _budget(): reason="natural_defeat_not_reached_before_budget"; return false
 await _frame()
 if not _summary_check("natural_defeat_postdraw","defeat"): return false
 if not _picture("natural_defeat_summary"): return false
 if not await _summary_roundtrip("defeat",false): return false
 await _frame()
 if not _summary_check("natural_defeat_reopened_postdraw","defeat") or not _picture("natural_defeat_summary_reopened"): return false
 coverage.natural_defeat_summary="PASS"
 coverage.dedicated_settlement_panel="PASS"
 return true
'''
assert not target.exists()
target.write_text(s)
print(target, len(s.encode()), hashlib.sha256(s.encode()).hexdigest())
