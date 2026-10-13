#!/usr/bin/env python3
"""Stdlib source/byte audit only. Never invokes Godot, Blender, CUA or imports assets."""
from pathlib import Path
import argparse, hashlib, json, re, subprocess, sys
H = Path(__file__).resolve().parent
R = H.parents[2]
UP = R/'tests/ink_q3_foundation_20261004/fix02/source_binding.json'
CONTRACT = R/'tests/ink_q2_source_contract_20261004/source_contract.json'
OVERLAY = R/'docs/source_decisions/20261005-ink-six-resolutions.json'
EXPECTED_UP = '9a5f18b7249cd40efe8ef4047d5cfa8584b99e0668b0c1d437304d670b952727'
FAILED = H.parent/'source_binding.json'
EXPECTED_FAILED = '5e402668816c85244071dd5077ba85dcf7a5c84d0d5c020ff7579057677176bb'
EXCLUDED = {'source_binding.json','runtime_binding.json','source_result.json','capabilities.json','manifest.sha256'}
RUNTIME_FILES = ['river_geometry.gd','ink_q2_sim.gd','ink_q2_catalog.gd','ink_q2_bridge.gd','live_binding.gd']
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
load = lambda p: json.loads(p.read_text())
dump = lambda x: json.dumps(x, ensure_ascii=False, indent=2)+'\n'
checks = []
def check(condition, label):
    assert condition, label
    checks.append(label)
def lexical_balance(text, label):
    # Lexical check only, explicitly not a GDScript parser/type checker.
    text = re.sub(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|#[^\n]*', '', text)
    stack = []
    for c in text:
        if c in '([{': stack.append(c)
        elif c in ')]}':
            check(bool(stack) and stack.pop() == {')':'(',']':'[','}':'{'}[c], label+' balanced delimiters')
    check(not stack, label+' complete delimiters')
def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--freeze', action='store_true')
    parser.add_argument('--audit', action='store_true')
    args = parser.parse_args()
    check(sha(UP) == EXPECTED_UP, 'exact preserved Q3 fix02 binding')
    check(sha(FAILED) == EXPECTED_FAILED, 'preserved failed source binding')
    for rel,item in load(FAILED)['authored_files'].items(): check(sha(R/rel) == item['sha256'], 'unchanged failed source '+rel)
    upstream = load(UP)
    for rel, digest in upstream['files'].items(): check(sha(R/rel) == digest, 'unchanged prior '+rel)
    contract = load(CONTRACT)
    for rel, item in contract['frozen_inputs'].items(): check(sha(R/rel) == item['sha256'], 'unchanged contract '+rel)
    result = subprocess.run([sys.executable, str(CONTRACT.parent/'verify_source.py')], capture_output=True, text=True, check=True)
    original = json.loads(result.stdout)
    check(original['parameter_tokens'] == 17 and original['numeric_cells'] == 67, 'original 17 parameters / 67 independently read cells')
    overlay = load(OVERLAY)['rules']
    check(overlay['ink_q2_e3']['cooldown_on_first_marker'] is False, 'no first-marker cooldown')
    check(overlay['ink_q2_river']['hits_per_enemy_per_river'] == 1, 'per-river target limit')
    check(overlay['ink_q2_river']['enhancements_per_projectile_across_all_rivers'] == 1, 'global projectile once')
    sim = (H/'ink_q2_sim.gd').read_text()
    check(sha(OVERLAY) in sim, 'new source overlay exact digest')
    check(sim.count('super._fixed_step(real_dt)') == 1, 'single inherited global fixed step')
    check('state.q2_enhanced_once = true' in sim and 'q2_original_total_range' in sim, 'entity-level global buff bit and named source-range basis')
    check('state.hits[id] = true' in sim and 'claim_hit(int(state.cast_id), id, segment)' in sim, 'root-river target ledger and shared hit claim')
    check('state.next_sunset_tick += 1' in sim and 'T.hex_parameter("H04-4")' in sim, 'source H04 interval with reserved tick index')
    check('no_reactions' not in sim, 'no blanket common reaction bypass')
    for path in H.glob('*.gd'):
        lexical_balance(path.read_text(), path.name)
        names = re.findall(r'^func\s+(\w+)\(', path.read_text(), re.M)
        check(len(names) == len(set(names)), 'no duplicate functions '+path.name)
    gate = (H/'q2_gate.gd').read_text()
    cases = ['source_ranks','partial_cd','input_h03','activation_sweep','h04','projectiles','lifecycle','callbacks','pause_and_order','retained']
    for case in cases: check('completed.append("'+case+'")' in gate, 'finite engine case authored '+case)
    authored = {}
    for p in sorted(H.iterdir()):
        if not p.is_file() or p.name in EXCLUDED or p.name.endswith('_result.json'): continue
        authored[p.relative_to(R).as_posix()] = {'sha256':sha(p),'bytes':p.stat().st_size}
    mapping = dict(upstream['runtime_map'])
    extra = [UP, CONTRACT, OVERLAY, OVERLAY.with_suffix('.md')]
    extra += [H/name for name in RUNTIME_FILES]
    extra.append(R/'tests/ink_q2_independent_20261005/independent_gate.gd')
    # Runtime map excludes generated self/manifest to avoid digest cycles.
    for p in extra:
        rel = p.relative_to(R).as_posix(); mapping[rel] = {'source':rel,'sha256':sha(p)}
    runtime = {'schema':1,'version':'ink-q2-source-candidate-20261005','upstream_binding_sha256':EXPECTED_UP,'runtime_map':dict(sorted(mapping.items())),'ordinary_entry_ready':False,'engine':'NOT_RUN'}
    runtime_hash = hashlib.sha256(dump(runtime).encode()).hexdigest()
    catalog = (H/'ink_q2_catalog.gd').read_text()
    hooks = re.findall(r'"(hex\.final_design\.[^"]+)"', re.search(r'const FIRST_SLICE_HEX_HOOKS = (.*)', catalog).group(1))
    check(len(hooks) == 12, 'candidate twelve hooks, old eight-hook ceiling untouched')
    capabilities = {'schema':1,'hero_id':'yanguizhou','version':'ink-q2-source-only-v1','runtime_binding_sha256':runtime_hash,'runtime_candidates':['Q1','Q2','Q3'],'source_implemented_hooks':hooks,'runtime_verified_hooks':[],'ordinary_entry_ready':False,'all_projectile_families_supported':False,'supported_projectile_families':['ink_basic','ink_dash_basic'],'required_engine_result':'q2_result.json'}
    all_mapping = dict(mapping)
    for rel, item in authored.items():
        if Path(rel).name != '.gdignore': all_mapping[rel] = {'source':rel,'sha256':item['sha256']}
    for name, data in [('runtime_binding.json',runtime),('capabilities.json',capabilities)]:
        rel = (H/name).relative_to(R).as_posix()
        all_mapping[rel] = {'source':rel,'sha256':hashlib.sha256(dump(data).encode()).hexdigest()}
    outputs = {str((H/x).relative_to(R)) for x in ['source_binding.json','q2_result.json']}
    for path in H.glob('*.gd'):
        for ref in re.findall(r'res://([^"\n]+)', path.read_text()):
            if ref in outputs: continue
            check(ref in all_mapping, 'bound literal reference '+ref)
    binding = {'schema':1,'version':'ink-q2-isolated-candidate-20261005','upstream_binding_sha256':EXPECTED_UP,'preserved_failed_binding_sha256':EXPECTED_FAILED,'original_source_contract_sha256':sha(CONTRACT),'decision_overlay_sha256':sha(OVERLAY),'runtime_binding_sha256':runtime_hash,'authored_files':authored,'runtime_map':dict(sorted(all_mapping.items())),'protected_source_contract_files':len(contract['frozen_inputs']),'engine_invocations_by_author':0,'engine_status':'NOT_RUN','normal_input':'NOT_RUN','ordinary_entry_ready':False}
    source_result = {'passed':True,'mode':'source_static_not_gdscript_parse_or_engine','parameter_tokens':17,'numeric_cells':67,'protected_contract_inputs':len(contract['frozen_inputs']),'upstream_files':len(upstream['files']),'authored_files':len(authored),'runtime_files':len(all_mapping),'runtime_binding_sha256':runtime_hash,'source_binding_sha256':hashlib.sha256(dump(binding).encode()).hexdigest(),'finite_case_groups_authored':len(cases),'known_source_defects':'fix01_source_changes_await_independent_and_engine_validation','engine':'NOT_RUN','all_projectile_families':'NOT_IMPLEMENTED','normal_input':'NOT_RUN','ordinary_entry_ready':False}
    artifacts = {'runtime_binding.json':runtime,'capabilities.json':capabilities,'source_binding.json':binding,'source_result.json':source_result}
    if args.freeze:
        check(not any((H/name).exists() for name in artifacts), 'never overwrite frozen candidate')
        for name, data in artifacts.items(): (H/name).write_text(dump(data))
        (H/'manifest.sha256').write_text(''.join(f'{item["sha256"]}  {rel}\n' for rel,item in sorted(authored.items())))
    elif not args.audit:
        for name,data in artifacts.items(): check(load(H/name) == data, 'reproducible '+name)
    print(dump({**source_result,'source_checks':len(checks),'frozen':args.freeze or not args.audit}), end='')
if __name__ == '__main__': main()
