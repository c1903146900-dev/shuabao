from pathlib import Path
import difflib
import hashlib
import json
import re

HERE=Path(__file__).resolve().parent
PARENT=HERE.parent/'terminal_ui_probe02'
SOURCE=HERE.parent/'terminal_ui_source01/source/game'
REL='payload/yan_terminal_full_floor_20261018c/runner.gd'
old=(PARENT/REL).read_text()
new=(HERE/REL).read_text()
checks=[]

def check(label, passed):
    checks.append({'check':label,'accepted':bool(passed)})
    assert passed, label

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def funcs(text):
    matches=list(re.finditer(r'^func (\w+)\(',text,re.M))
    return {m[1]:text[m.start():matches[i+1].start() if i+1<len(matches) else len(text)].strip() for i,m in enumerate(matches)}

before,after=funcs(old),funcs(new)
check('parent_runner_exact',sha(PARENT/REL)=='1a51e05addc53bf0149ec0f90cd70b672003f9877bfcb10609c6bfdbe704379c')
for name,body in before.items():
    if name not in ['_wall_watchdog','_run']:
        check('preserved_probe02_function_'+name,after[name]==body)
check('only_five_observer_functions_added',set(after)-set(before)=={'_startup_diagnostic','_startup_child_entered','_startup_ready_signal','_startup_abort','_startup_poll'})
for rel in ['payload/yan_terminal_full_floor_20261018c/binding.json','payload/yan_terminal_full_floor_20261018c/driver.gd','payload/yan_terminal_ui_probe_20261018/probe.gd']:
    check('unchanged_'+rel,sha(HERE/rel)==sha(PARENT/rel))
check('signal_watchdog_observes_startup_without_await','_startup_poll()' in after['_wall_watchdog'] and 'await ' not in after['_wall_watchdog'])
check('explicit_HOLD_precedes_observation_timeout',after['_startup_poll'].index('status=="HOLD"')<after['_startup_poll'].index('why="startup_observation_30s_deadline"'))
check('entry_error_and_timeout_are_observed','original_entry_rejected:' in after['_startup_poll'] and 'entry_observation_30s_deadline' in after['_startup_poll'])
check('failure_locks_success_before_evidence',after['_startup_abort'].index('watchdog_fired=true')<after['_startup_abort'].index('_json(') and 'completed=false' in after['_startup_abort'])
check('startup_abort_does_not_free_or_command_source','frontdoor_close_run' not in after['_startup_abort'] and '.free(' not in after['_startup_abort'] and '.command(' not in after['_startup_abort'])
check('early_failure_does_not_copy_bone_proof','hero_view_proof' not in after['_startup_diagnostic'] and '.proof' not in after['_startup_diagnostic'] and '65536' in after['_startup_diagnostic'])
check('no_new_readiness_assignment',re.search(r'host\.(?:_mainprep_required|_mainprep_pending|initial_started)|sim\.(?:hero_time|paused|phase)\s*=(?!=)', '\n'.join(after[n] for n in set(after)-set(before))) is None)
gate=(SOURCE/'tests/ink_style_specimen_20261004/revision26_safe_clock/parsefix01/host.gd').read_text()
check('actual_preparation_failure_sets_HOLD','"status": "HOLD", "failures": [reason]' in gate)
check('original_10_second_gate_unchanged','const STARTUP_READY_WALL_LIMIT_USEC := 10000000' in gate)
hostbase=(SOURCE/'tests/ink_style_specimen_20261004/revision03/fix01/host.gd').read_text()
check('original_ink_evidence_flag_exists','--ink-evidence=' in hostbase)
check('original_host_has_draw_count_and_start_ticks','var draw_count' in hostbase and 'var start_ticks' in hostbase)
sourcepins=json.loads((HERE.parent/'terminal_ui_source01/SOURCE_PINS.json').read_text())
actual={str(p.relative_to(SOURCE)):sha(p) for p in SOURCE.rglob('*') if p.is_file()}
check('3047_production_source_still_exact',actual==sourcepins and len(actual)==3047)
(HERE/'DIAGNOSTIC_DELTA_FROM_PROBE02.diff').write_text(''.join(difflib.unified_diff(old.splitlines(True),new.splitlines(True),fromfile='probe02/runner.gd',tofile='probe03/runner.gd')))
(HERE/'STATIC_CHECKS.json').write_text(json.dumps({'accepted':True,'checks':checks,'scope':'STATIC_SOURCE_AND_BYTE_CHECKS_ONLY','parse':'NOT_RUN','native':'NOT_RUN'},indent=2)+'\n')
print(json.dumps({'accepted':True,'checks':len(checks)}))
