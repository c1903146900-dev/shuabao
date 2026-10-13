#!/usr/bin/env python3
"""Check coordinator-owned parse/finite raw output and exit/reap receipts."""
import argparse, hashlib, json, re
from pathlib import Path

HERE = Path(__file__).resolve().parent
ERRORS = re.compile(r'SCRIPT ERROR|PARSE ERROR|Parse Error|ERROR:|FATAL|CRASH|Segmentation fault', re.I)

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def require(ok, message):
    if not ok:
        raise ValueError(message)

def process(raw_path, receipt_path, marker):
    raw = raw_path.read_text()
    receipt = json.loads(receipt_path.read_text())
    require(receipt.get('exit') == 0 and receipt.get('reaped') is True, 'not exit-zero and reaped: '+str(receipt_path))
    require(not receipt.get('errors') and not receipt.get('reason'), 'process receipt reports error')
    require(not ERRORS.search(raw), 'raw contains engine/script error')
    lines = [line[len(marker):] for line in raw.splitlines() if line.startswith(marker)]
    require(len(lines) == 1, 'completion marker missing or duplicated: '+marker)
    value = json.loads(lines[0])
    require(value.get('passed') is True and value.get('failures') == [], 'completion reports failure')
    return raw, value

def validate(a):
    binding = json.loads(a.binding.read_text())
    binding_sha = digest(a.binding)
    require(binding_sha == digest(HERE/'source_binding.json'), 'source/stage binding differs')
    _, parsed = process(a.parse_raw, a.parse_exit, 'INK_E1_REFORM_PARSE ')
    raw, finite = process(a.finite_raw, a.finite_exit, 'INK_E1_REFORM_REPORT ')
    scripts = json.loads(re.search(r'const FILES := (\[[^\n]+\])', (HERE/'parse_gate.gd').read_text()).group(1))
    require(parsed.get('source_binding_sha256') == binding_sha and parsed.get('runtime_pass') is False, 'parse binding/scope differs')
    require(parsed.get('scripts') == scripts, 'parse omitted source script')
    require(finite.get('source_binding_sha256') == binding_sha, 'finite binding differs')
    groups = binding['required_groups']
    require(groups == ['original_e1_reform_remainder'], 'not exactly the affected group')
    require(finite.get('completed') == groups, 'finite groups incomplete')
    require([line.split(' ', 1)[1] for line in raw.splitlines() if line.startswith('INK_E1_REFORM_GROUP ')] == groups, 'raw group marker missing or duplicated')
    require(finite.get('checks', 0) >= 150, 'finite check count incomplete')
    require(json.loads(a.finite_report.read_text()) == finite, 'written report differs from raw')
    require(finite.get('mode') == 'SYNCHRONOUS_CALLBACK_FIXTURE', 'fixture scope missing')
    for field in ('native_input', 'ordinary_admission', 'production_entry_changed', 'old_full_matrices_rerun'):
        require(finite.get(field) is False, 'scope widened or missing: '+field)
    return {'schema':'ink-e1-reform-raw-gate-1', 'passed':True,
            'source_binding_sha256':binding_sha, 'finite_checks':finite['checks'],
            'required_groups':groups, 'parse_and_finite_exit_zero_reaped':True,
            'raw_error_gate':'PASS', 'native_input':False, 'ordinary_admission':False,
            'evidence':{name:{'path':str(getattr(a,name)), 'sha256':digest(getattr(a,name))}
                        for name in ('parse_raw','parse_exit','finite_raw','finite_exit','finite_report')}}

def main():
    p = argparse.ArgumentParser(description=__doc__)
    for name in ('binding','parse_raw','parse_exit','finite_raw','finite_exit','finite_report','output'):
        p.add_argument('--'+name.replace('_','-'), type=Path, required=True)
    a = p.parse_args()
    try:
        result = validate(a)
    except (ValueError, KeyError, TypeError, OSError, AttributeError, AssertionError) as error:
        result = {'schema':'ink-e1-reform-raw-gate-1', 'passed':False, 'failure':str(error)}
    a.output.write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n')
    print(json.dumps(result, ensure_ascii=False, indent=2))
    raise SystemExit(0 if result['passed'] else 1)

if __name__ == '__main__':
    main()
