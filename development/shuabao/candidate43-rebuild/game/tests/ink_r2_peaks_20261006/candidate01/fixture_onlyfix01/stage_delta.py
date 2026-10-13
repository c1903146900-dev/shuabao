#!/usr/bin/env python3
"""Stage candidate source only after the frozen inherited runtime inputs match."""
from pathlib import Path
import argparse, json, shutil
from verify_source import D, R, sha, relative, verify

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--dest', required=True)
p.add_argument('--apply', action='store_true')
p.add_argument('--receipt')
a = p.parse_args()
report = verify()
binding = json.loads((D/'source_binding.json').read_text())
stage = Path(a.dest).resolve()
assert stage != R and R not in stage.parents and (stage/'project.godot').is_file()
for name, digest in binding['frozen_inputs_sha256'].items():
    path = stage/relative(name)
    assert path.is_file() and sha(path) == digest, 'stage dependency differs: '+name
mapped = dict(binding['files_sha256'])
mapped['res://'+str((D/'source_binding.json').relative_to(R))] = sha(D/'source_binding.json')
for name, digest in mapped.items():
    path = stage/relative(name)
    assert stage in path.resolve().parents
    assert not path.exists() or sha(path) == digest, 'unrecognized existing candidate: '+name
copied = []
if a.apply:
    for name, digest in mapped.items():
        path = stage/relative(name)
        if path.is_file() and sha(path) == digest:
            continue
        path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(R/relative(name), path)
        assert sha(path) == digest
        copied.append(name)
report.update({'status':'R2_PEAKS_STAGE_APPLIED' if a.apply else 'R2_PEAKS_STAGE_PREFLIGHT_PASS',
               'stage':str(stage), 'copied':copied})
if a.receipt:
    Path(a.receipt).write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n')
print(json.dumps(report, ensure_ascii=False, indent=2))
