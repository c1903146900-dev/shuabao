#!/usr/bin/env python3
"""Freeze test-only fix01; all c997 mechanism and historical failed-gate bytes stay unchanged."""
from pathlib import Path
import hashlib,json,re,difflib
H=Path(__file__).resolve().parent;B=H.parent;R=H.parents[2]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
expected='c997eab5df81084d7ca970c76464389e4cf47954ae8271c1b18ae3a8b27cec7a'
assert sha(B/'source_binding.json')==expected
old=json.loads((B/'source_binding.json').read_text())
for rel,h in old['files'].items():assert sha(R/rel)==h,rel
failed=Path('/workspace/scratch/73ebae91a474/recovery_2309/ink_initial_hex_stage_1756/tests/ink_initial_hex_runtime_20261004/sink_result.json')
raw=Path('/workspace/scratch/73ebae91a474/recovery_2309/ink28_hex_retry_1804/hex_sinks/raw.log')
result=json.loads(failed.read_text());assert result['passed'] is False and len(result['failures'])==137
text=(H/'sink_gate.gd').read_text()
checks={
 'c997_all_runtime_source_pins_unchanged':True,
 'failed137_preserved':sha(failed)=='c56b40293f1bb29891c81c5ebc7cbeb8e8455b9b6d261082bfeda94a66180987',
 'old_spacing_actual_refusal_assertion':'rejection.reason=="cooldown"' in text,
 'wait_actual_source_cooldown':'maxf(remaining,1.0/f.sim.hero.attack_speed())+f.sim.FIXED_TICK' in text,
 'no_cooldown_reset':'cooldowns.attack=' not in text,
 'no_fake_target_death':'e.dead=' not in text,
 'no_direct_wallet_or_points_write':'state.gold=' not in text.replace('state.gold==','') and 'state.points=' not in text.replace('state.points==',''),
 'no_empty_kill_array_back':'var event: Dictionary=matching[0]' in text and 'matching.size()!=1' in text,
 'actual_basic_cast_owned_kill':'event.source=="attack" and int(event.cast_id)>0' in text,
 'required_completion_marker':'case completed through final assertion:' in text and all('finish_case("'+x+'",failed_before)' in text for x in ['old_spacing_refusal','personal','G01','G05','G06','G15','G24','G30']),
 'hook_claims_gated_on_case_success':'"hooks_tested":verified_hooks' in text,
 'actual_observations_not_nominal_G05':'"grown_cdr":actual_cdr' in text,
 'actual_observations_not_nominal_G24':'"initial_basic":initial_damage' in text,
 'actual_observations_not_nominal_G30':'"earned":earned' in text,
}
assert all(checks.values()),checks
(H/'gate_only.patch').write_text(''.join(difflib.unified_diff((B/'sink_gate.gd').read_text().splitlines(True),text.splitlines(True),fromfile='c997/sink_gate.gd',tofile='fix01/sink_gate.gd')))
diag={'classification':'test_helper_cadence_bug_predicted_from_source_requires_actual_refusal_probe','source_attack_speed':.85,'source_cooldown_seconds':1/.85,'old_observed_wait_seconds':1.1,'old_basic_poststep_seconds':.02,'predicted_remaining_cooldown':1/.85-1.12,'failed_result_path':str(failed),'failed_result_sha256':sha(failed),'failed_raw_path':str(raw),'failed_raw_sha256':sha(raw),'failed_checks':result['checks'],'failed_assertions':len(result['failures']),'old_observations_warning':'G05/G30 summaries were expected constants, not observed successful outcomes; passed=false and failing assertions are authoritative','new_probe':'first real kill, exact previous1.1 spacing, require actual cooldown refusal/no new event, naturally step remaining cooldown, same target real kill','scope':'test script only; no mechanism, actor value, progression, selector, capability, live_binding, old stage, or old failure mutation'}
(H/'diagnosis.json').write_text(json.dumps(diag,ensure_ascii=False,indent=2)+'\n')
mapping=old['runtime_map'].copy()
for name in ['source_binding.json','capabilities.json','live_binding.gd']:
 rel=(B/name).relative_to(R).as_posix();mapping[rel]={'source':rel,'sha256':sha(B/name)}
for f in H.iterdir():
 if f.is_file() and f.name not in ['source_binding.json','source_result.json','sink_result.json']:
  rel=f.relative_to(R).as_posix();mapping[rel]={'source':rel,'sha256':sha(f)}
files={e['source']:e['sha256'] for e in mapping.values()}
binding={'schema':1,'scope':'test-only source-cadence and fail-closed evidence fix; actual runtime unchanged','runtime_source_binding_id':expected,'files':dict(sorted(files.items())),'runtime_map':dict(sorted(mapping.items())),'author_engine_invocations':0}
(H/'source_binding.json').write_text(json.dumps(binding,ensure_ascii=False,indent=2)+'\n')
out={'passed':True,'checks':checks,'source_binding_sha256':sha(H/'source_binding.json'),'runtime_source_binding_id':expected,'engine':'NOT_RUN_BY_WORKER','ordinary_entry_ready':False}
(H/'source_result.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n');print(json.dumps(out))
