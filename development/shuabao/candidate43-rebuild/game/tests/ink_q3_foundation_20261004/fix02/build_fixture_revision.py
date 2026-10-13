#!/usr/bin/env python3
"""Author fixture-only corrections; never changes Sim/Bridge or invokes engine."""
from pathlib import Path
import difflib,json
F=Path(__file__).resolve().parent;B=F.parent/'fix01'
prefix='res://tests/ink_q3_foundation_20261004/fix01/';newprefix=prefix.replace('fix01/','fix02/')
patch=[];specs=json.loads((B/'gate_expectations.json').read_text())
for gate,spec in specs.items():
 old=(B/gate).read_text();text=old
 for name in ['source_binding.json',spec['result']]:text=text.replace(prefix+name,newprefix+name)
 text=text.replace(prefix+'ink_q3_sim.gd',newprefix+'ink_q3_sim.gd').replace(prefix+'ink_q3_bridge.gd',newprefix+'ink_q3_bridge.gd')
 if gate=='q3_gate.gd':
  text=text.replace('const Geo=preload(', 'const InputAdapter=preload("res://tests/ink_q1_foundation_20261004/revision02/scripts/ink_input_adapter.gd")\nconst Geo=preload(',1)
  anchor=' sim.paused=false;sim.move_during_hitstop(.1,Vector3.RIGHT);near(sim.hero_time,0,"hitstop movement does not age terrain")\n'
  text=text.replace(anchor,anchor+''' var adapter=InputAdapter.new();adapter.bind(sim)
 var keyup=InputEventKey.new();keyup.physical_keycode=KEY_D;keyup.pressed=false
 check(adapter.handle_event(keyup).accepted and sim.hero.move_intent==Vector3.ZERO,"actual D key-up stops fixture movement without cancelling terrain")
''',1)
  text=text.replace(' sim.common_reset_cooldowns(["q"]);var second:Dictionary=raise_at(sim)',' sim.common_reset_cooldowns(["q"]);near(sim.hero.cooldowns.q,0,"real inherited CD reset reached zero before rebuild");var second:Dictionary=raise_at(sim)',1)
  old_callback='''  var fired:Array=[false]
  sim.combat_event.connect(func(event):
   if not fired[0] and event.kind==trigger:
    fired[0]=true;sim.end_encounter("cancelled");sim.begin_encounter("callback-new-room",[]))
  raise_at(sim)
  if trigger=="ink_q3_collapse_started":sim.request_action("q",Vector3(12,0,0))
  check(fired[0] and sim.room_id=="callback-new-room","callback rebuild actually reached "+trigger)
'''
  new_callback='''  var fired:Array=[false]
  var callback_results:Array=[]
  sim.combat_event.connect(func(event):
   if not fired[0] and event.kind==trigger:
    fired[0]=true;sim.end_encounter("cancelled")
    var attempt:Dictionary=sim.begin_encounter("callback-new-room",[])
    callback_results.append({"event_kind":event.kind,"transaction_active":sim.transaction_active,"begin_result":attempt}))
  raise_at(sim)
  if trigger=="ink_q3_collapse_started":sim.request_action("q",Vector3(12,0,0))
  check(fired[0] and callback_results.size()==1,"source callback actually fired exactly once "+trigger)
  if callback_results.size()==1:
   var actual:Dictionary=callback_results[0]
   check(actual.event_kind==trigger and actual.transaction_active and not actual.begin_result.accepted and actual.begin_result.reason=="invalid_phase","in-transaction begin correctly rejected "+trigger)
  check(not sim.transaction_active and sim.phase=="cancelled","action unwinds transaction after callback cancellation "+trigger)
  var rebuilt:Dictionary=sim.begin_encounter("callback-new-room",[])
  check(rebuilt.accepted,"legal post-transaction room rebuild accepted "+trigger)
  observations["callback_"+trigger]={"inside_action":callback_results,"after_action":rebuilt}
  check(fired[0] and sim.room_id=="callback-new-room","callback rebuild actually reached "+trigger)
'''
  assert old_callback in text;text=text.replace(old_callback,new_callback,1)
 (F/gate).write_text(text);patch.extend(difflib.unified_diff(old.splitlines(True),text.splitlines(True),fromfile=str(B.relative_to(F.parents[2])/gate),tofile=str(F.relative_to(F.parents[2])/gate)))
specs['g22_batch_gate.gd']={'result':'g22_batch_result.json','marker':'INK_Q3_G22_BATCH_REPORT','completed':['raise_none_to_duel','collapse_none_to_duel','raise_horde_to_none','collapse_horde_to_none']}
specs['fixture_diagnostic_gate.gd']={'result':'fixture_diagnostic_result.json','marker':'INK_Q3_FIXTURE_DIAGNOSTIC_REPORT','completed':['persistent_walk_range','callback_transaction_guard']}
(F/'gate_expectations.json').write_text(json.dumps(specs,indent=2)+'\n');(F/'fixture_only.patch').write_text(''.join(patch));(F/'.gdignore').write_text('')
