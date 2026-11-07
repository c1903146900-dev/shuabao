"""Read-only acceptance analysis of recorded source UI/normal-route observations.
Does not launch Godot or treat UI signals as native clicks. Prints aggregate JSON.
"""
import json, sys, math
from pathlib import Path
rows=[json.loads(line) for line in Path(sys.argv[1]).read_text().splitlines()]
by=lambda name:[r for r in rows if r['record']==name]
checks={}
def require(name,value): checks[name]=bool(value)
def near(a,b): return math.isclose(float(a),float(b),abs_tol=1e-7)
undrunk=by('undrunk_inventory_no_effect'); pending=by('source_ui_drink'); starts=by('next_actual_combat'); ends=by('next_battle_end_cleared'); samples=by('elixir_combat_sample'); final=by('final')
require('full_floor_completed',final and final[-1].get('full_floor') and final[-1].get('reason')=='normal_full_floor_complete')
require('real_source_ui_chain',len(undrunk)==len(pending)==len(starts)==len(ends)==1)
if undrunk and pending and starts and ends:
 u,p,b,e=undrunk[0],pending[0],starts[0],ends[0]
 require('inventory_does_not_activate',not u['shop_visit']['active_elixir'] and not u['elixir_static_stats'])
 require('safe_drink_pending_only',p['stats']==u['stats'] and not p['elixir_static_stats'] and p['elixir_consumer']['active']['item']=='elixir:05')
 require('attack_speed_plus_15_percent',near(b['stats']['attack_speed'],p['stats']['attack_speed']*1.15))
 require('cdr_plus_8_points',near(b['stats']['cdr'],p['stats']['cdr']+0.08))
 require('combat_base_movement',near(b['actual_move_speed'],b['stats']['move_speed']*1.15))
 require('next_battle_cleanup',not e['shop_visit']['active_elixir'] and not e['elixir_static_stats'] and near(e['actual_move_speed'],e['stats']['move_speed']))
 active=[s for s in samples if s['elixir_consumer']['stride_seconds']>0]
 require('shift_bonus_observed',bool(active))
 require('movement_additive_not_compounded',samples and all(near(s['actual_move_speed'],s['stats']['move_speed']*(1.30 if s['elixir_consumer']['stride_seconds']>0 else 1.15)) for s in samples))
 require('remaining_duration_bounded',all(0<=s['elixir_consumer']['stride_seconds']<=1.5000001 for s in samples))
 expired=False
 for s in active:
  until=s['actor_combat_time']+s['elixir_consumer']['stride_seconds']
  for later in samples:
   if later['dash_serial']==s['dash_serial'] and later['actor_combat_time']>=until and later['elixir_consumer']['stride_seconds']==0 and near(later['actual_move_speed'],later['stats']['move_speed']*1.15): expired=True
 require('natural_1p5_second_expiry',expired)
print(json.dumps({'checks':checks,'passed':bool(checks) and all(checks.values()),'combat_samples':len(samples),'native_click_acceptance':False,'partial_tick_movement_not_in_sample_resolution':True},indent=2))
